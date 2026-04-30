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

## Open infrastructure concerns

- **EOL packages.** Pub resolved `sqlite3_flutter_libs 0.6.0+eol` and `sqlcipher_flutter_libs 0.7.0+eol`. The `+eol` build tag is the authors' end-of-life marker. They install and analyze cleanly today. Investigate whether `drift_flutter` (which bundles native libs differently) or another supported package replaces them, before the DB layer (step 4 of the restated plan) is built on top.
- **No-network invariant not yet enforced.** `INTERNET` is still in `AndroidManifest.xml` from the Flutter scaffold; iOS ATS is not configured restrictively yet; no CI grep blocks network imports. All addressed in step 3 of the restated plan.
- **gradlew not committed.** The project `.gitignore` excludes `**/android/gradlew` and `**/android/gradle/wrapper/gradle-wrapper.jar`. Flutter regenerates gradle wrapper artifacts from `flutter create`, so this is workable, but contributors will need to run `flutter create .` (or equivalent) once on checkout. Reconsider if it causes friction.

## Verification status

- `flutter pub get`: ✓
- `flutter analyze`: ✓ (no issues)
- `flutter run` on a device: not yet verified — no emulator available in the dev environment used to scaffold. To verify locally: `flutter run` on any connected iOS simulator or Android emulator should boot the default Flutter counter app at this stage.
