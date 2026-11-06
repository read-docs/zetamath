# Zetamath mobile: Flutter plan

A native Android version of the web app in [`../web`](../web), built for personal use on a Samsung Galaxy A54. The core loop, modes, stats, themes and history format stay the same. Keyboard-only features (Tab to restart, Esc for the command palette) get touch equivalents.

## Goals

- Same problems for the same seed and settings as the web app, bit for bit.
- History export from the web app imports on mobile, and the reverse.
- Starting a test should feel at least as fast as on the web: open the app and start typing.
- Local only, no backend, same as web v1.
- No Play Store or App Store release. The app is installed straight onto the phone.

## Target device: Samsung Galaxy A54

| Property | Value | What it means for layout |
|---|---|---|
| Screen | 6.4", 1080 × 2340 px, 19.5:9, ~403 ppi | Tall and narrow |
| Logical size | ~411 × 891 dp at density 2.625 (default display zoom) | Design canvas. Test at this size first. |
| Usable height | ~891 dp minus status bar (~24–32 dp) and gesture bar (~16–24 dp); one-handed reach covers the bottom ~55% | Put the keypad in the bottom half, the problem in the upper middle, and secondary controls at the top |
| Refresh rate | 120 Hz adaptive | `Ticker` runs at up to 120 fps, so the timer stays cheap. Don't rebuild the whole screen every frame. |
| OS | Android 13 at launch, updatable to Android 15/16 (One UI) | Edge-to-edge is enforced from Android 15, so wrap content in `SafeArea`. The app still supports older Android (see Platform below). |
| Navigation | Gesture bar by default | Keep keypad keys clear of the bottom inset so swipe-home doesn't eat taps |
| Display zoom / font size | Users can change both in One UI | Layout must survive text scale up to ~1.3 and a zoomed width of ~360 dp without overflow |

Layout rules that follow from this:
- Keypad: 4 rows × 3 columns, filling the full width with ~16 dp side margins, which gives ~120 × 72 dp keys. That is well above the 48 dp minimum, so fast thumbs don't miss.
- Problem text scales with the `size` setting, but is capped so `a op b = answer` fits on one line at 411 dp. Shrink the font for long problems (e.g. 6-digit ranges) instead of wrapping.
- Portrait only.
- Check the layout in widget tests at: 411 × 891 (A54), 360 × 780 (A54 with zoomed display), 411 × 891 with text scale 1.3, and 360 × 640 (a small older phone). The A54 is the design target; the others only need to work without overflow.

## Decisions

| Area | Choice | Why |
|---|---|---|
| Framework | Flutter 3.47.7 (Dart 3.13.5), pinned with fvm | Already installed through fvm. Pinning keeps local builds and CI on the same SDK. |
| Platform | Android only, `minSdk` = Flutter's default (`flutter.minSdkVersion`, currently 24 = Android 7.0). iOS is out of scope for now. | The A54 is the main target, but a low minSdk lets the APK install on most Android phones from the last ~9 years. Check each plugin's minimum Android version when adding it. Flutter keeps the iOS option open later. |
| Distribution | Release APK installed over USB with `adb`. No store listing. | Personal use, no store review |
| Answer input | Custom in-app numeric keypad. No system keyboard. | The system keyboard covers half the screen, adds open/close lag and differs between devices. A fixed keypad gives the same muscle memory on every phone and lets us time each tap precisely. |
| State | `flutter_riverpod` | Close to the Zustand stores, and easy to test without widgets |
| Settings storage | `shared_preferences` (one JSON blob, versioned like `zetamath-settings` v2) | Same role as localStorage |
| History storage | One JSON file in the app documents dir via `path_provider`, written atomically (write temp file, then rename) | Mirrors the single IndexedDB key. Switch to SQLite (`drift`) only if history gets slow to load. |
| Charts | `fl_chart` | Pace graph and profile progress chart |
| Fonts | Bundle the six fonts as assets (not `google_fonts` runtime fetch) | Works offline on first launch |
| Export / import | `share_plus` for export, `file_picker` for import | Native share sheet and file picker |
| Haptics | `HapticFeedback.lightImpact` on correct answer, toggle in settings | Replaces the visual-only feedback |
| Navigation | Bottom navigation: practice, profile, settings. Results replace the test inline, as on web. | Matches the web page set |

## Code sharing with web

TypeScript can't be imported from Dart, so the engine is ported by hand and kept honest with shared test fixtures.

```
zetamath/
  web/
  mobile/
  shared/
    fixtures/
      problems.json     # seed + ranges -> first 200 problems
      scoring.json      # solve logs -> median, ppm, consistency, breakdown, paceSeries
      profile.json      # results -> streaks, level, summary
      history-v1.json   # a real export file, must parse on both sides
```

- Add `web/scripts/export-fixtures.ts` that runs the web engine and writes `shared/fixtures/*.json`. Commit the output.
- Both test suites load the same fixtures: Vitest on web, `flutter test` on mobile. If either engine drifts, its tests fail.
- RNG porting note: `createRng` relies on 32-bit `Math.imul`, `|0` and `>>>`. Dart ints are 64-bit, so every step must mask with `.toSigned(32)` / `& 0xFFFFFFFF`. `seed.charCodeAt(i)` is a UTF-16 code unit, so use `seed.codeUnits` in Dart, not runes. This is the most likely place for a mismatch, so it gets the fixture test first.
- Problem ids keep the `×` and `÷` characters so ids and PB keys match across platforms.
- `configKey` / `rangesKey` / `resultKey` must produce the same strings as web. Dart's `jsonEncode` matches `JSON.stringify` for these inputs (strings, bools, ints), but check with fixtures that include large ints.

## Project structure

```
mobile/
  lib/
    engine/       rng.dart, generator.dart, scoring.dart     # pure Dart, no Flutter imports
    store/        settings.dart, history.dart, profile.dart, difficulty.dart
    themes/       themes.dart (same 15 presets as web)
    features/
      practice/   practice_screen.dart, keypad.dart, mode_bar.dart, live_stats.dart
      results/    results_view.dart, pace_chart.dart
      profile/    profile_screen.dart
      settings/   settings_screen.dart, quick_settings_sheet.dart
    app.dart, main.dart
  test/
    engine/       fixture tests against ../shared/fixtures
    store/        history parse/merge, PBs, streaks
    widgets/      practice loop: tap digits -> auto-advance -> results
```

## Screen mapping

| Web | Mobile |
|---|---|
| Test stage with focused `<input>` | Problem in the upper half, custom keypad in the lower half (digits, backspace, minus if ever needed). Auto-advance on correct answer, no submit key. |
| `Tab` restart | Restart button on the test screen and results. Optional: swipe down on the problem to restart. |
| `Esc` / command palette | Quick settings bottom sheet (mode, length, difficulty, theme) from a button in the mode bar |
| Mode bar | Horizontal chip row: time / count / zen / custom, then the values |
| Results (inline) | Same stats grid, pace chart, per-op breakdown, slowest 10 with "drill these" |
| `/profile` | Profile tab: level, streaks, PB cards, pace history chart, past tests list |
| `/settings` | Settings tab: ranges and weights per op, theme picker with live preview, font, size, live stat toggles, answer style, export/import/clear history |
| `?seed=` URL param | "Seed" field in custom settings; deep link `zetamath://test?seed=...` later |

## Core loop details

- Timing uses `Stopwatch` (monotonic), not `DateTime.now()`. Record the timestamp in the keypad's `onTapDown`, not `onTap`, so solve times don't include finger lift.
- Display timer runs on a `Ticker`. The end check uses elapsed time, same as web (`finish(start + duration)` so the recorded time is exact).
- First digit tap starts the timer, as on web.
- Pause on app background (`AppLifecycleState.paused`): end the current test and save it as incomplete. It won't count for PBs because the web PB rules already exclude unfinished runs.
- Keep the screen awake during a test (`wakelock_plus`).
- Lock portrait for v1.

## Tooling (fvm)

Always run Flutter and Dart through fvm. Never use a global `flutter`.

```sh
cd mobile
fvm use 3.47.7                 # writes .fvmrc (commit it); the .fvm/ symlink dir is gitignored
fvm flutter pub get
fvm flutter test
fvm flutter run                # debug on the A54 over USB, with hot reload
fvm flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

- Enable Developer options and USB debugging on the A54 once. Wireless debugging (`adb pair`) works too.
- Sign the release APK with a local keystore kept outside the repo (`android/key.properties` is gitignored). The debug key also works for personal use, but a fixed release key lets `adb install -r` update the app without wiping history.
- Point the IDE's Flutter SDK at `mobile/.fvm/flutter_sdk`.
- CI reads the version from `.fvmrc` (e.g. `subosito/flutter-action` with `flutter-version-file: mobile/.fvmrc`).

## Milestones

1. **Scaffold:** in `mobile/`, run `fvm use 3.47.7`, then `fvm flutter create --org com.readdocs --project-name zetamath --platforms android .`. Keep the default `minSdk = flutter.minSdkVersion` (24), add `flutter_lints`, lock portrait, add the CI job, and install the empty app on the A54 to prove the toolchain works.
2. **Engine port:** fixture exporter on web, Dart `rng`, `generator`, `scoring` passing all fixture tests.
3. **Practice loop:** keypad, problem view, time/count/zen modes, auto-advance, restart, basic results.
4. **Stats and results:** pace chart, per-op breakdown, slowest list, drill mode, variation.
5. **Persistence:** settings and history storage, PB detection, profile screen (level, streaks, charts), JSON export/import compatible with web.
6. **Customization:** 15 themes, bundled fonts, size, toggles, answer style, quick settings sheet, haptics.
7. **Polish:** app icon and splash, accessibility (TalkBack labels on keypad, large text), checks at the three A54 layout sizes, a signed release APK installed on the phone.

## Monorepo housekeeping

- Root `README.md` points to both apps. Each app keeps its own tooling. No JS workspace tool is needed at the root.
- GitHub Actions with path filters: `web/**` runs `npm ci && npm test && npm run build`; `mobile/**` and `shared/**` run `flutter analyze && flutter test` on the `.fvmrc` version. Any change to `shared/fixtures/**` runs both. CI can also build the release APK as a downloadable artifact.
- Cloudflare Pages: set the build root directory to `web`.

## Open questions

- Should the keypad layout be phone-style (1-2-3 on top) or calculator-style (7-8-9 on top)? Could be a setting; default to phone-style, since the A54 dialer uses it.
- Application id: `com.readdocs.zetamath` unless you prefer another.
