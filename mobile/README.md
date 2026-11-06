# Zetamath for Android

The Flutter version of the web trainer in [`../web`](../web), built for a Samsung Galaxy A54. It generates the same problems for the same seed and settings, and reads and writes the same history export. [`PLAN.md`](PLAN.md) has the design decisions.

## Run

Flutter is pinned to 3.47.7 in `.fvmrc`. Always go through fvm:

```sh
fvm flutter pub get
fvm flutter test
fvm flutter run                  # debug build on a phone connected over USB
fvm flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

`adb` lives in `~/Library/Android/sdk/platform-tools` if it is not on your `PATH`.

Release builds use `android/key.properties` when it exists (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`; gitignored) and the debug key otherwise. Keep using the same key, or `adb install -r` will refuse the update and you'd have to uninstall, which deletes history.

## Layout

- `lib/engine`: the hand port of `web/src/engine` (seeded RNG, problem generator, scoring). Pure Dart.
- `lib/store`: settings, history, personal bests, profile stats and difficulty presets, ported from `web/src/store`.
- `lib/features`: the practice screen with its keypad, results, profile and settings.
- `test/engine` and `test/store` check the ports against `../shared/fixtures`, which the web engine writes. `test/widgets` runs the practice loop and checks every screen at the A54 sizes for overflow.

## Keeping the engines in step

A change to the web engine or stores needs new fixtures: run `npm run fixtures` in `web/` and commit `shared/fixtures`. The web tests fail if the committed fixtures are stale, and the Flutter tests fail if the Dart port no longer matches them.

## Differences from web

- A keypad replaces the keyboard. Digits register on touch down, so solve times don't include lifting the finger.
- Restart is a button in the mode bar and under results. The tune button opens quick settings in place of Esc.
- Leaving the app or switching tabs ends a running test. It is saved, but unfinished tests never count as personal bests.
- Extra settings: haptics, keypad layout (phone or calculator) and a fixed seed.
