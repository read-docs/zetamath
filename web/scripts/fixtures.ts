/**
 * Builds the shared engine fixtures in ../shared/fixtures. The Flutter app ports the engine by hand,
 * and both test suites check themselves against these files, so any drift between them fails a test.
 * Dates are noon UTC so day-based stats come out the same in any time zone within ±11h.
 */
import { createRng } from '../src/engine/rng';
import { defaultRanges, generateProblem, operations, type Operation, type Problem, type RangeConfig } from '../src/engine/generator';
import { breakdown, configKey, consistency, median, paceSeries, ppm, slowest, type Solve } from '../src/engine/scoring';
import { difficultyRanges, currentDifficulty } from '../src/store/difficulty';
import { isCountRun, pace, personalBests, rangesKey, resultKey, type Result } from '../src/store/history';
import { activityByDay, bestsFor, formatDuration, level, paceSeries as profilePace, streaks, summary, variation } from '../src/store/profile';

const clone = <T>(x: T): T => structuredClone(x);
const withRange = (ranges: RangeConfig, op: Operation, patch: Partial<RangeConfig[Operation]>) => ({ ...clone(ranges), [op]: { ...ranges[op], ...patch } });
const only = (op: Operation, patch: Partial<RangeConfig[Operation]> = {}): RangeConfig =>
  Object.fromEntries(operations.map(o => [o, { ...defaultRanges[o], enabled: o === op, ...(o === op ? patch : {}) }])) as RangeConfig;

const rangeCases: Record<string, RangeConfig> = {
  default: defaultRanges,
  easy: difficultyRanges('easy', defaultRanges),
  hard: difficultyRanges('hard', defaultRanges),
  huge: Object.fromEntries(operations.map(op => [op, { enabled: true, weight: 1, minA: 1, maxA: 1000000, minB: 1, maxB: 1000000 }])) as RangeConfig,
  fractionalWeights: { '+': { ...defaultRanges['+'], weight: 0.1 }, '-': { ...defaultRanges['-'], weight: 2.7 }, '×': { ...defaultRanges['×'], weight: 0.3 }, '÷': { ...defaultRanges['÷'], weight: 999.9 } },
  zeroWeightAndDisabled: { ...withRange(defaultRanges, '+', { weight: 0 }), '-': { ...defaultRanges['-'], enabled: false } },
  divisionOnly: only('÷', { minA: 2, maxA: 99, minB: 2, maxB: 99 }),
  tinyDomain: only('+', { minA: 2, maxA: 3, minB: 4, maxB: 4 }),
};

const seeds = ['', 'shared', 'a', '0', 'Zetamath 2026', 'ząb żółć', '÷×−', '🦀 crab', 'x'.repeat(300), '1f0c7c43-6a1b-4b3c-9d3e-0f7d5bb0a5e1'];

function problemsFixture() {
  const rng = seeds.map(seed => { const r = createRng(seed); return { seed, values: Array.from({ length: 50 }, r) }; });
  const runs: { name: string; seed: string; ranges: RangeConfig; problems: Problem[] }[] = [];
  for (const [name, ranges] of Object.entries(rangeCases)) for (const seed of seeds.slice(0, name === 'default' ? seeds.length : 3)) {
    const r = createRng(seed); let previous: Problem | undefined; const problems: Problem[] = [];
    for (let i = 0; i < 200; i++) problems.push(previous = generateProblem(ranges, r, previous));
    runs.push({ name, seed, ranges, problems });
  }
  // The deterministic fallback for a domain with two problems, and the error for a domain with one.
  const single = only('+', { minA: 2, maxA: 2, minB: 3, maxB: 3 });
  const fallback = { ranges: only('+', { minA: 2, maxA: 2, minB: 3, maxB: 4 }), previous: '2+3', expected: generateProblem(only('+', { minA: 2, maxA: 2, minB: 3, maxB: 4 }), () => 0.0, '2+3') };
  return { rng, runs, fallback, singleProblem: { ranges: single, previous: '2+3', error: 'These ranges contain only one problem. Widen a range to avoid consecutive repeats.' } };
}

const validationCases = (): { ranges: RangeConfig; error: string | null }[] => [
  defaultRanges,
  Object.fromEntries(operations.map(op => [op, { ...defaultRanges[op], enabled: false }])) as RangeConfig,
  Object.fromEntries(operations.map(op => [op, { ...defaultRanges[op], weight: 0 }])) as RangeConfig,
  withRange(defaultRanges, '+', { weight: 1001 }),
  withRange(defaultRanges, '+', { weight: -1 }),
  withRange(defaultRanges, '-', { minA: 0 }),
  withRange(defaultRanges, '-', { maxB: 1000001 }),
  withRange(defaultRanges, '×', { minA: 1.5 }),
  withRange(defaultRanges, '÷', { minB: 50, maxB: 10 }),
  withRange(defaultRanges, '÷', { minA: 13, maxA: 12 }),
].map(ranges => ({ ranges, error: (() => { try { generateProblem(ranges, () => 0.5); return null; } catch (e) { return (e as Error).message; } })() }));

function timesFrom(seed: string, n: number): number[] {
  const r = createRng(seed);
  return Array.from({ length: n }, () => Math.round((300 + r() * 4000) * 1000) / 1000);
}

function scoringFixture() {
  const cases = [
    { name: 'empty', count: 0 }, { name: 'one', count: 1 }, { name: 'two', count: 2 }, { name: 'short', count: 7 },
    { name: 'minute', count: 40 }, { name: 'long', count: 150 },
  ].map(({ name, count }) => {
    const rng = createRng(name); let previous: Problem | undefined;
    const times = timesFrom(name + ' times', count);
    const solves: Solve[] = times.map(timeMs => { const problem = previous = generateProblem(defaultRanges, rng, previous); return { problem, op: problem.op, timeMs }; });
    const elapsedMs = times.reduce((a, b) => a + b, 0) + (count % 3) * 431.25;
    return {
      name, solves, elapsedMs,
      median: median(times), ppm: ppm(solves.length, elapsedMs), consistency: consistency(solves),
      breakdown: breakdown(solves), slowest: slowest(solves).map(s => solves.indexOf(s)),
      paceSeries: paceSeries(solves, elapsedMs), paceSeries5: paceSeries(solves, elapsedMs, 5),
    };
  });
  // Ties keep their original order, as Array.prototype.sort is stable.
  const tied: Solve[] = [1000, 2000, 2000, 1000, 2000].map((timeMs, i) => ({ problem: { a: i + 2, b: 3, op: '+' as const, answer: i + 5, id: `${i + 2}+3` }, op: '+' as const, timeMs }));
  const medians = [[], [5], [3, 1, 2, 4], [0.1, 0.2, 0.3], [10, -1, 7.5, 7.5, 2]].map(values => ({ values, median: median(values) }));
  const configs: unknown[] = [
    { a: 1, b: { c: 2, d: 3 } }, { b: { d: 3, c: 2 }, a: 1 }, defaultRanges, rangeCases.huge, rangeCases.fractionalWeights,
    { mode: 'time', duration: 120, ranges: defaultRanges, list: [3, { z: 1, y: [true, null] }], name: 'ząb "quoted" \\ ÷' },
    { maxA: 1, minA: 2, MaxA: 3, weight: 0.1 + 0.2, big: 1e12, neg: -0, small: 1e-7 },
  ];
  return {
    cases, slowestTies: { solves: tied, slowest: slowest(tied, 3).map(s => tied.indexOf(s)) }, medians,
    configKeys: configs.map(config => ({ config, key: configKey(config) })),
  };
}

const noon = (y: number, m: number, d: number, minute = 0) => new Date(Date.UTC(y, m - 1, d, 12, minute)).toISOString();

/** A plausible history: a few weeks of practice across every mode, with drills, unfinished runs and custom ranges. */
function historyResults(): Result[] {
  const r = createRng('history fixture'), results: Result[] = [];
  const easy = difficultyRanges('easy', defaultRanges), custom = withRange(defaultRanges, '×', { maxA: 15, weight: 2.5 });
  const plans: [Result['mode'], Result['customKind'], number, number, RangeConfig, boolean?, boolean?][] = [
    ['time', 'time', 15, 25, defaultRanges], ['time', 'time', 30, 25, defaultRanges], ['time', 'time', 15, 25, defaultRanges],
    ['count', 'time', 120, 10, defaultRanges], ['count', 'time', 120, 25, defaultRanges], ['count', 'time', 120, 10, defaultRanges],
    ['zen', 'time', 120, 25, defaultRanges], ['custom', 'count', 120, 12, custom], ['custom', 'time', 45, 25, custom],
    ['time', 'time', 15, 25, easy], ['count', 'time', 120, 10, easy], ['time', 'time', 60, 25, defaultRanges, false, true],
    ['count', 'time', 120, 50, defaultRanges, false, true], ['count', 'time', 120, 10, defaultRanges, true], ['time', 'time', 120, 25, defaultRanges],
    ['time', 'time', 15, 25, defaultRanges], ['count', 'time', 120, 10, defaultRanges], ['zen', 'time', 120, 25, easy],
  ];
  const days = [[2026, 9, 28], [2026, 9, 28], [2026, 9, 29], [2026, 9, 30], [2026, 10, 2], [2026, 10, 3], [2026, 10, 4], [2026, 10, 4],
    [2026, 10, 5], [2026, 10, 12], [2026, 10, 13], [2026, 10, 20], [2026, 10, 30], [2026, 10, 31], [2026, 11, 1], [2026, 11, 2], [2026, 11, 3], [2026, 11, 5]];
  plans.forEach(([mode, customKind, duration, count, ranges, drill, unfinished], i) => {
    const seed = `seed-${i}`, problems = createRng(seed); let previous: Problem | undefined;
    const timed = !(mode === 'count' || (mode === 'custom' && customKind === 'count')) && mode !== 'zen';
    const logs: Result['logs'] = []; let elapsed = 0;
    const limit = timed ? (unfinished ? duration * 600 : duration * 1000) : mode === 'zen' ? 40000 + i * 1000 : Infinity;
    const target = timed || mode === 'zen' ? Infinity : unfinished ? Math.floor(count / 2) : count;
    while (logs.length < target) {
      const timeMs = Math.round(Math.max(250, 400 + r() * 3200 - i * 40) * 10) / 10;
      if (elapsed + timeMs > limit) break;
      const problem = previous = generateProblem(ranges, problems, previous);
      logs.push({ problem, timeMs }); elapsed += timeMs;
    }
    const [y, m, d] = days[i];
    results.push({
      id: `fixture-${String(i).padStart(2, '0')}`, date: noon(y, m, d, i), mode, duration, count, customKind, ranges: clone(ranges), seed,
      elapsedMs: timed ? Math.min(limit, duration * 1000) + (unfinished ? 0.5 : 0) : Math.round(elapsed * 1000) / 1000, logs,
      ...(drill ? { drill: true } : {}),
    });
  });
  return results.reverse();
}

function profileFixture(results: Result[]) {
  const sortedDays = [...activityByDay(results).entries()].sort(([a], [b]) => a.localeCompare(b));
  const localDay = (iso: string) => { const [y, m, d] = iso.split('-').map(Number); return new Date(y, m - 1, d); };
  const todays = ['2026-11-05', '2026-11-06', '2026-11-07', '2026-10-04', '2026-09-27'];
  return {
    resultKeys: results.map(r => ({ id: r.id, rangesKey: rangesKey(r.ranges), resultKey: resultKey(r), countRun: isCountRun(r), pace: pace(r), variation: variation(r), difficulty: currentDifficulty(r.ranges) })),
    personalBests: personalBests(results).map(r => r.id),
    activityByDay: sortedDays,
    streaks: todays.map(today => ({ today, ...streaks(results, localDay(today)) })),
    summary: summary(results),
    emptySummary: summary([]),
    bests: (['time', 'count'] as const).flatMap(mode => [defaultRanges, difficultyRanges('easy', defaultRanges)].map(ranges => ({
      mode, ranges, targets: mode === 'time' ? [15, 30, 60, 120] : [10, 25, 50, 100],
      bests: [...bestsFor(results, mode, mode === 'time' ? [15, 30, 60, 120] : [10, 25, 50, 100], ranges).entries()].map(([target, r]) => [target, r.id]),
    }))),
    paceSeries: profilePace(results),
    levels: [0, 1, 9, 10, 15, 25, 30, 100, 1234].map(solved => ({ solved, ...level(solved ? [{ ...results[0], logs: Array.from({ length: solved }, () => results[0].logs[0]) }] : []) })),
    durations: [0, 999, 42000, 59999, 60000, 125000, 3_599_999, 3_600_000, 3_780_000, 90_061_000].map(ms => ({ ms, text: formatDuration(ms) })),
    difficulties: (['easy', 'normal', 'hard'] as const).map(name => ({ name, ranges: difficultyRanges(name, withRange(defaultRanges, '+', { enabled: false, weight: 3 })) })),
  };
}

export function buildFixtures() {
  const history = historyResults();
  return {
    'problems.json': { ...problemsFixture(), validation: validationCases() },
    'scoring.json': scoringFixture(),
    'profile.json': { ...profileFixture(history), history },
    'history-v1.json': { version: 1, results: history },
  } as Record<string, unknown>;
}

export const fixtureText = (name: string, data: unknown) => name.startsWith('history') ? JSON.stringify(data, null, 2) + '\n' : JSON.stringify(data) + '\n';
