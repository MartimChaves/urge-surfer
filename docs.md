# Urge Surfer — Technical Notes

Living technical doc. Each commit that changes infrastructure, dependencies, or structural decisions should update this file in the same commit.

The product/design source of truth is `~/.claude/plans/the-goal-of-this-snappy-dolphin.md` (referenced via the restated plan at `~/.claude/plans/restate-the-plan-and-mellow-firefly.md`). This doc covers the **how**, not the **what**.

---

## Project layout

Standard Flutter app, scaffolded with `flutter create --platforms ios,android`. iOS + Android only — no web, desktop, or macOS.

- `lib/` — Dart source.
- `android/`, `ios/` — platform-specific scaffolds.
- `assets/phrases/` — JSON phrase library (`general.json`, `betting.json`, `scrolling.json` seeded; `alcohol.json`, `smoking.json` to come).
- `test/` — unit + widget tests. `integration_test/` to be added.
- `pubspec.yaml` — dependency manifest.

## Identifiers

- Dart package name: `urge_surfer` (snake_case; pub requirement).
- Bundle org: `com.urgesurfer`. Resulting iOS bundle ID and Android package: `com.urgesurfer.urge_surfer`.

## Flutter / Dart versions

- Flutter `3.41.9` stable (Linux snap install).
- Dart SDK constraint: `^3.11.5` (per generated pubspec).

## Runtime dependencies

| Package | Why |
|---|---|
| `flutter_riverpod` | State management. Type-safe, testable, fits the nested ritual flow. |
| `drift` | Type-safe SQLite ORM. |
| `sqlite3` | SQLite bindings; v3.x bundles native libraries automatically via Dart build hooks. The `hooks.user_defines.sqlite3.source: sqlite3mc` block in `pubspec.yaml` switches the bundled binary to SQLite3MultipleCiphers, the maintained encryption-capable successor to SQLCipher. |
| `flutter_secure_storage` | Stores the DB encryption key in Android Keystore / iOS Keychain. |
| `go_router` | Declarative routing. |
| `path_provider` | Locates a writable directory for the DB file. |
| `path` | Cross-platform path joining (`p.join(...)`) when constructing the DB file path. |

## Dev dependencies

- `drift_dev` — Drift schema codegen.
- `build_runner` — runs Drift codegen.
- `flutter_lints` — lint defaults (from `flutter create`).
- `flutter_test` — unit + widget testing harness.

## Asset registration

`pubspec.yaml`'s `flutter.assets` registers `assets/phrases/` so phrase JSONs ship in the bundle. Glyph templates (`assets/glyphs/`) are not registered yet — add when that asset arrives.

## Network lockdown

The "no-network" claim is the trust core of the project. Three independent layers enforce it; an auditor can verify each in order.

### Layer 1 — Android: no `INTERNET` permission in release

- `android/app/src/main/AndroidManifest.xml` does **not** declare `android.permission.INTERNET`. Release builds use only this manifest, so the release APK has no networking permission and the OS will reject every outbound request from app code.
- `android/app/src/debug/AndroidManifest.xml` and `.../profile/AndroidManifest.xml` **do** declare `INTERNET`. This is intentional and required: Flutter's hot reload, the Dart VM Service, and DevTools all communicate with the running app over a local socket. Removing `INTERNET` from those variants would break `flutter run`. Android's manifest merger applies them only for debug and profile builds — never release.
- Verify: `grep -R "uses-permission" android/app/src/main/AndroidManifest.xml` returns nothing.

### Layer 2 — iOS: App Transport Security denies all loads

- `ios/Runner/Info.plist` sets `NSAppTransportSecurity` with every flag false: `NSAllowsArbitraryLoads`, `NSAllowsArbitraryLoadsInWebContent`, `NSAllowsArbitraryLoadsForMedia`, `NSAllowsLocalNetworking`. iOS's URL Loading System (NSURLSession and friends) will refuse all requests at the OS layer.
- ATS does **not** govern raw BSD sockets. Layer 3 (the static check) is what closes that gap by forbidding `dart:io` socket APIs in `lib/`.

### Layer 3 — Static check: no network imports or `dart:io` socket symbols in `lib/`

- `tool/check_no_network.sh` greps `lib/` for forbidden imports (`package:http`, `package:dio`, `package:web_socket_channel`, `package:grpc`, `package:graphql`) and forbidden `dart:io` symbols (`HttpClient`, `Socket`, `RawSocket`, `ServerSocket`, `RawDatagramSocket`, `WebSocket`). It also checks `pubspec.yaml` for any of those packages as direct dependencies.
- Generated files (`*.g.dart`, `*.drift.dart`, `*.freezed.dart`) are excluded from the scan.
- `test/` and `integration_test/` are intentionally **not** scanned, so future runtime tests can attempt a request and assert failure.
- Run locally: `bash tool/check_no_network.sh`. Runs in CI on every push to `main` and every pull request via `.github/workflows/ci.yml`.

### Layer 4 — deferred: runtime test that an outbound request fails

The original plan calls for a deliberate `HttpClient` request to `example.com` that fails at runtime on both platforms. We have **not** implemented this yet, for two reasons:

1. The static check forbids `dart:io` socket usage in `lib/`, so the test must live in `integration_test/` — which is not yet scaffolded.
2. By default, `flutter test` for integration runs in **debug** mode on Android, where the manifest *does* grant `INTERNET`. The test would pass on iOS (ATS blocks) but pass-when-it-shouldn't on Android. Honest verification needs a profile-build run on Android, paired with the iOS test.

When integration_test infrastructure lands, this layer should be added.

### Forbidden, full list

- Direct deps in `pubspec.yaml`: `http`, `dio`, `web_socket_channel`, `grpc`, `graphql`.
- Imports anywhere in `lib/`: any of the above plus `package:graphql_*` variants.
- `dart:io` symbols anywhere in `lib/`: `HttpClient`, `Socket`, `RawSocket`, `ServerSocket`, `RawDatagramSocket`, `WebSocket`. (Other `dart:io` APIs — `File`, `Directory`, `Platform` — are fine.)

If a future feature genuinely requires one of these (e.g., serving an in-app local web view), the right move is to discuss the threat model in a PR description, not to silently relax `tool/check_no_network.sh`.

## Database & encryption

The persistence layer lives under `lib/data/db/` and `lib/data/secure/`.

### Schema (v1)

Four tables, single schema version. All defined in `lib/data/db/tables.dart`.

- **`Modules`** — one row per urge the user wants to surf. Columns: `id`, `name`, `moneyTracked` (bool), `defaultAmount` (nullable int), `phraseSet`, `goalCount` (nullable int), `goalAmount` (nullable int), `createdAt`, `archivedAt` (nullable). Goals are modeled as two nullable columns rather than a separate `Goal` table — single goal per module v1, mutually exclusive at the UX layer. If goal history or multi-goal lands, migrate to a separate table at that point.
- **`Waves`** — one row per surfed wave. Columns: `id`, `moduleId` (FK), `urgeText`, `urgeBefore` (int 0–10), `urgeAfter` (int 0–10), `amount` (nullable int — minor units), `createdAt`. Waves never delete and never reset.
- **`Intentions`** — the user-written if-then plan per module. Columns: `id`, `moduleId` (FK), `body`, `createdAt`. (`body` rather than `text` because `text` collides with Drift's `Table.text` method.)
- **`WeeklyCheckins`** — DARN-style prompt + free-text response. Columns: `id`, `promptKey`, `responseText`, `createdAt`.

### Money

Amounts are integers in **minor units** (e.g., cents). Floats are never used for money. V1 assumes a single user-locale currency; no currency code is stored. If the app is ever localized for currencies that don't decimalize the same way, this assumption needs revisiting.

### DAOs

Currently only the methods needed by tests exist:

- `ModuleDao`: `insertModule`, `getAllActive`.
- `WaveDao`: `insertWave`, `getAllByModule` (newest-first), `totalCount`, `totalCountByModule`, `sumAmountByModule` (null-safe).

DAOs grow with UI demand, not speculatively.

### Encryption (SQLite3MultipleCiphers)

`package:sqlite3 ^3.x` bundles SQLite3MultipleCiphers via the `hooks.user_defines.sqlite3.source: sqlite3mc` block in `pubspec.yaml`. The DB is opened with `NativeDatabase.createInBackground` (Drift recommended; runs DB on a background isolate), and a `PRAGMA key = '<base64>';` is issued in the connection setup callback. An `assert(_debugCheckHasCipher(...))` confirms in debug builds that the bundled binary actually supports encryption.

### Key lifecycle

`lib/data/secure/db_key.dart` (`DbKeyStore.getOrCreate`):

- First open: 32 bytes from `Random.secure()`, base64-encoded, stored under `urge_surfer_db_key` in `flutter_secure_storage`. Base64 keeps the value SQL-metacharacter-free, so it can be interpolated into the `PRAGMA key = '...'` string without escaping.
- Subsequent opens: read from `flutter_secure_storage`, return as-is.
- iOS Keychain accessibility class: the `flutter_secure_storage` default (`kSecAttrAccessibleWhenUnlocked`) — key only readable while the device is unlocked.
- No "regenerate key" / "wipe data" UX in v1. Clearing app data on Android also clears the Keystore-bound entry (fresh-install behavior). On iOS, the Keychain entry survives uninstall, but the encrypted DB file is gone with the app, making the lingering entry meaningless.

### Code generation

Drift uses `build_runner` for codegen. Generated files (`*.g.dart`) are gitignored, so contributors and CI must run:

```
dart run build_runner build --delete-conflicting-outputs
```

after `flutter pub get` and before `flutter analyze`. CI does this in `.github/workflows/ci.yml`.

### Tests

`test/data/db/wave_dao_test.dart` exercises the WaveDao contract against an in-memory `NativeDatabase.memory()`. In-memory SQLite is the same engine as on-disk — these are real-DB tests, not mocks. Cases: insert + read; totalCount across modules; per-module count isolation; sum ignores nulls; sum returns 0 on empty; cross-module query isolation; ordering newest-first.

### What this layer does NOT yet test

- **Encryption round-trip on a real file.** Writing with key A, closing, reopening without a key (expect failure) and with key A (expect success). Requires the bundled sqlite3mc native libs to be available to `flutter test` on the host — works in principle on Linux/macOS, fragile in practice. Deferred to integration_test on real devices.
- **`DbKeyStore` behavior.** `flutter_secure_storage` requires a Flutter platform channel; the WaveDao tests bypass it by passing an explicit in-memory database to `AppDatabase`. Behavior verification waits for integration_test.
- **Migration logic.** Schema is version 1 and only version 1; no `MigrationStrategy` until the schema changes.

## Drawing controller (`WeightedTracingController`)

The simulation behind the drawing-as-meditation mechanic. Pure Dart (only `dart:math` and `dart:ui` for `Offset`), no Flutter widgets or platform channels — fully unit-testable. Lives at `lib/domain/drawing/weighted_tracing_controller.dart`.

### Model

The pen position is a low-pass-filtered version of the finger position. Given a time constant `τ` (seconds) and a frame delta `Δt`:

```
α = 1 − exp(−Δt / τ)
penPosition ← lerp(penPosition, fingerTarget, α)
```

This is the analytical discretization of a first-order linear filter, so 60Hz and 120Hz devices reach the same pen position after the same elapsed wall-clock time. A naive per-call `lerp(pen, finger, k)` would be frame-rate dependent — fast phones would feel less laggy. We don't want that.

The controller also tracks how far along the template path the pen has reached (`templateIndex`). Each `tick`, after updating the pen position, it advances the index past every subsequent template point that is within `advanceThreshold` pixels of the current pen position. The index is monotonically non-decreasing — re-tracing or going off-path never reduces progress.

### API

- Constructor: `WeightedTracingController({required templatePoints, timeConstant = 0.4, advanceThreshold = 8.0})`. Asserts `templatePoints.length >= 2`.
- `setFingerTarget(Offset)` — call from gesture handlers (pan/drag updates).
- `tick(Duration dt)` — call once per animation frame from a `Ticker`. `Duration.zero` and negative durations are no-ops.
- Read-only getters: `penPosition`, `templateIndex`, `letterComplete`, `progress` (0.0–1.0).

The split between `setFingerTarget` (gesture-pushed) and `tick` (ticker-pulled) matches Flutter's idiomatic animation pattern and makes the controller trivially testable — a test loop can call `tick(Duration(milliseconds: 16))` without needing a real `AnimationController`.

### Tuning parameters

- `timeConstant = 0.4 s`. Pen reaches ~63% of the way to the finger after 0.4s, ~95% after 1.2s. The "feel" parameter — slow enough to feel meditative, not so slow that it frustrates. Real tuning happens via playtesting against actual glyph templates and is per-instance, not global.
- `advanceThreshold = 8.0 px`. How close the pen must come to the next template point for the index to advance. Densely sampled templates (e.g., one point every 2–4 px) make this easy to hit; sparse templates can leave the pen "stuck." Step 8 (glyph data) needs to keep this in mind.

### What the tests lock in

`test/domain/drawing/weighted_tracing_controller_test.dart` covers ten cases:

- Initial state (pen at first point, index 0, not complete, progress 0.0).
- Assertion fires for fewer than 2 points.
- Single short tick with a far finger leaves the pen mostly behind (slowness mechanic).
- Sufficient ticks with finger at end drive the pen to the end and complete the letter.
- 60Hz and 120Hz controllers reach the same pen position after the same total elapsed time (frame-rate independence).
- Finger held off the path doesn't advance the index.
- `templateIndex` is monotonically non-decreasing across noisy input.
- After completion, moving the finger backwards does not decrease `templateIndex`.
- `tick(Duration.zero)` and `tick(<negative>)` are no-ops.

## Open infrastructure concerns

- **gradlew not committed.** The project `.gitignore` excludes `**/android/gradlew` and `**/android/gradle/wrapper/gradle-wrapper.jar`. Flutter regenerates gradle wrapper artifacts from `flutter create`, so this is workable, but contributors will need to run `flutter create .` (or equivalent) once on checkout. Reconsider if it causes friction.

## Verification status

- `flutter pub get`: ✓
- `flutter analyze`: ✓ (no issues)
- `flutter run` on a device: not yet verified — no emulator available in the dev environment used to scaffold. To verify locally: `flutter run` on any connected iOS simulator or Android emulator should boot the default Flutter counter app at this stage.
