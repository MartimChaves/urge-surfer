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
| `sqlite3_flutter_libs` | Bundled SQLite binaries for the platforms. |
| `sqlcipher_flutter_libs` | SQLCipher binaries for at-rest encryption of the local DB. |
| `flutter_secure_storage` | Stores the SQLCipher key in Android Keystore / iOS Keychain. |
| `go_router` | Declarative routing. |
| `path_provider` | Locates a writable directory for the DB file. |

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

## Open infrastructure concerns

- **EOL packages.** Pub resolved `sqlite3_flutter_libs 0.6.0+eol` and `sqlcipher_flutter_libs 0.7.0+eol`. The `+eol` build tag is the authors' end-of-life marker. They install and analyze cleanly today. Investigate whether `drift_flutter` (which bundles native libs differently) or another supported package replaces them, before the DB layer (step 4 of the restated plan) is built on top.
- **gradlew not committed.** The project `.gitignore` excludes `**/android/gradlew` and `**/android/gradle/wrapper/gradle-wrapper.jar`. Flutter regenerates gradle wrapper artifacts from `flutter create`, so this is workable, but contributors will need to run `flutter create .` (or equivalent) once on checkout. Reconsider if it causes friction.

## Verification status

- `flutter pub get`: ✓
- `flutter analyze`: ✓ (no issues)
- `flutter run` on a device: not yet verified — no emulator available in the dev environment used to scaffold. To verify locally: `flutter run` on any connected iOS simulator or Android emulator should boot the default Flutter counter app at this stage.
