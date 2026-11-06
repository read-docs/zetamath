# Mental math trainer: v1 plan

Monkeytype for arithmetic: quick to start, keyboard-driven, highly customizable, with detailed stats. Same core loop as Zetamac.

## Decisions

| Area | Choice |
|---|---|
| Input | Auto-advance: the next problem appears the instant the typed answer is correct. No Enter key and no wrong-answer state. |
| Modes | Time (15/30/60/120s), Count (10/25/50/100), Zen (endless), Custom (any time/count + ranges) |
| Problems | + − × ÷ with configurable ranges per operation |
| Customization | Theme presets, font family + size, live stats toggles |
| Results | Score + pace graph, per-operation breakdown, slowest problems, history + PB page |
| Storage | Local only (localStorage / IndexedDB), no backend |
| Stack | Vite + React + TypeScript, Tailwind, Zustand, Recharts (or uPlot), deployed to Cloudflare Pages |
| Platform | Desktop-first; mobile uses `inputmode="numeric"` and a responsive layout |

## Problem generation (Zetamac defaults)

- **Addition:** `(2–100) + (2–100)`
- **Subtraction:** reversed addition, so the answer is never negative
- **Multiplication:** `(2–12) × (2–100)`
- **Division:** reversed multiplication, so the answer is always an integer
- Users can edit every range. Each operation can be toggled on or off and given a weight (default 1 each).
- Never repeat the immediately previous problem.
- Use a seeded RNG (e.g. mulberry32) so tests can be replayed and shared, e.g. `?seed=...`.

## Core loop

1. The page loads straight into a ready test. Typing a digit starts the timer, as in Monkeytype.
2. The input is always focused, holds digits (and `-` if ever needed), and has no Enter handling.
3. On every keystroke, if `parseInt(input) === answer`, record `{problem, op, timeMs}`, clear the input, and show the next problem.
4. `Tab` restarts with the same settings and `Esc` opens settings or the command palette.
5. When the test ends (time runs out, count is reached, or Zen is stopped), show the results screen.

Timing uses `performance.now()`. Timer display runs on `requestAnimationFrame`, and the end check uses wall-clock deltas, not interval ticks.

## Stats

- **Score:** correct answers (Time mode) or total time (Count mode)
- **Pace:** problems per minute (ppm), the equivalent of WPM
- **Pace graph:** rolling ppm per second, with markers on slow problems
- **Per-op breakdown:** count and average/median time for + − × ÷
- **Slowest 10 problems**, with a "drill these" button that starts a custom test from them (cheap to add, high value)
- **Consistency:** coefficient of variation of solve times (as in Monkeytype)
- **PB detection:** a "new personal best" banner, keyed by `mode + duration + range config hash`

## Persistence (local)

- `settings`: theme, font, size, toggles, last mode, ranges. Stored in localStorage.
- `results[]`: full per-problem log for each test. Stored in IndexedDB via `idb-keyval` or Dexie, since logs get large.
- PBs are computed from history and cached.
- Export/import as JSON. This also makes migrating to accounts easy later.

## Customization

- **Themes:** about 15 presets defined as CSS variables (`--bg`, `--main`, `--sub`, `--text`, `--error`), with live preview on hover in the picker.
- **Fonts:** JetBrains Mono, Roboto Mono, Fira Code, IBM Plex Mono, Space Mono, and Lexend Deca, loaded from Google Fonts or self-hosted.
- **Size:** slider for the problem text, from about 2rem to 8rem.
- **Toggles:** live timer, live score, and live pace. Also an option for focus mode, which hides all UI during a test.

## Pages / layout

- `/`: test screen. A mode bar at the top (time | count | zen | custom, plus the values), then the problem and input centered, live stats above.
- Results replace the test inline (no route change), as in Monkeytype.
- `/settings`: all options. `/history`: PB cards, progress chart, and a table of past tests.
- Command palette (`Esc` or `Ctrl+Shift+P`) for quick changes to theme, font, and mode.

## Project structure

```
src/
  engine/      generator.ts, rng.ts, scoring.ts   # pure, unit-tested
  store/       settings.ts, test.ts, history.ts   # zustand
  components/  ModeBar, ProblemView, LiveStats, Results/, PaceChart, ThemePicker, CommandPalette
  pages/       Test, Settings, History
  themes/      *.ts (CSS variable maps)
```

`engine/` has no React dependency, so it can be reused on a future server for result validation.

## Milestones

1. **Core:** Vite scaffold, generator + RNG with tests (Vitest), a working 120s auto-advance test, basic results
2. **Modes:** time/count/zen/custom, the mode bar, Tab-to-restart
3. **Stats:** per-problem log, pace graph, per-op breakdown, slowest list, consistency
4. **Persistence:** IndexedDB history, PBs, history page, JSON export/import
5. **Customization:** themes, fonts, size, toggles, command palette
6. **Polish and deploy:** responsive/mobile input, a11y, Cloudflare Pages deploy, domain

## Later (not v1)

Accounts + cloud sync + leaderboards (server-side replay via seed + keystroke log for anti-cheat), more problem types (squares, %, fractions, decimals), sounds, daily challenge seed, and a shareable result card.

## Resolved

- **Name/domain:** none for now. This is a local project, so "deploy" in milestone 6 is optional.
- **Default theme:** an Iceberg-style dark palette (bg `#161821`, text `#c6c8d1`, main `#84a0c6`, sub `#6b7089`). A `monochrome` preset (grays only) ships alongside it.
- **Op weighting:** yes. Custom mode gets a weight per operation (e.g. + 1, − 1, × 2, ÷ 1), and the generator picks operations by weight.
