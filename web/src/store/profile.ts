import type {RangeConfig} from '../engine/generator';
import {isCountRun,pace,personalBests,rangesKey,resultKey,scoredResult,type TestConfig,type Result} from './history';

export const dayKey = (d: Date) => `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
const addDays = (d: Date, n: number) => new Date(d.getFullYear(), d.getMonth(), d.getDate()+n);
const mean = (xs: number[]) => xs.length ? xs.reduce((a,b)=>a+b,0)/xs.length : 0;

/** Coefficient of variation of solve times, in percent. Lower is steadier. */
export function variation(r: Result): number {
  const times = r.logs.map(l=>l.timeMs), m = mean(times);
  return m ? Math.sqrt(mean(times.map(t=>(t-m)**2)))/m*100 : 0;
}

export function activityByDay(results: Result[]): Map<string, number> {
  const days = new Map<string, number>();
  for (const r of results) { const k = dayKey(new Date(r.date)); days.set(k, (days.get(k)||0)+1); }
  return days;
}

/** Current streak counts back from today, or from yesterday if nothing has been done today yet. */
export function streaks(results: Result[], today = new Date()): {current: number, longest: number} {
  const days = activityByDay(results);
  let current = 0;
  for (let d = days.has(dayKey(today)) ? today : addDays(today,-1); days.has(dayKey(d)); d = addDays(d,-1)) current++;
  let longest = 0, run = 0, previous: Date | null = null;
  for (const k of [...days.keys()].sort()) {
    const [y,m,dd] = k.split('-').map(Number), d = new Date(y, m-1, dd);
    run = previous && dayKey(addDays(previous,1)) === k ? run+1 : 1;
    longest = Math.max(longest, run); previous = d;
  }
  return {current, longest};
}

export function summary(results: Result[], config?: TestConfig) {
  const completed = results.filter(scoredResult);
  const scored = completed.filter(r => !config || resultKey(r) === resultKey(config))
    .sort((a,b) => Date.parse(b.date) - Date.parse(a.date));
  const paces = scored.map(pace);
  return {
    tests: completed.length,
    solved: results.reduce((n,r)=>n+r.logs.length, 0),
    timeMs: results.reduce((n,r)=>n+r.elapsedMs, 0),
    joined: results.length ? results.reduce((a,r)=>r.date<a ? r.date : a, results[0].date) : null,
    highestPace: paces.length ? paces.reduce((best, p) => Math.max(best, p), 0) : 0,
    averagePace: mean(paces),
    last10Pace: mean(paces.slice(0,10)),
    averageVariation: mean(scored.map(variation)),
  };
}

/** Best result per standard length, for runs played with exactly these ranges. */
export function bestsFor(results: Result[], mode: 'time' | 'count', targets: number[], ranges: RangeConfig): Map<number, Result> {
  const key = rangesKey(ranges), bests = new Map<number, Result>();
  for (const r of personalBests(results)) {
    if (r.mode !== mode || rangesKey(r.ranges) !== key) continue;
    const target = isCountRun(r) ? r.count : r.duration;
    if (targets.includes(target)) bests.set(target, r);
  }
  return bests;
}

/** Oldest-first pace series with trailing averages over the last 10 and 100 tests. */
export function paceSeries(results: Result[], config?: TestConfig) {
  const ordered = results.filter(r => scoredResult(r) && (!config || resultKey(r) === resultKey(config)))
    .sort((a,b)=>Date.parse(a.date)-Date.parse(b.date));
  const paces = ordered.map(pace), trailing = (i: number, n: number) => Math.round(mean(paces.slice(Math.max(0,i-n+1), i+1)));
  return ordered.map((r,i)=>({test: i+1, ppm: Math.round(paces[i]), average10: trailing(i,10), average100: trailing(i,100), date: r.date}));
}

/** 10 xp per solved problem. Each level costs 50 xp more than the one before, starting at 100. */
export function level(results: Result[]): {level: number, xp: number, into: number, needed: number} {
  const xp = results.reduce((n,r)=>n+r.logs.length*10, 0);
  let lvl = 1, floor = 0, step = 100;
  while (xp >= floor + step) { floor += step; lvl++; step += 50; }
  return {level: lvl, xp, into: xp - floor, needed: step};
}

export function formatDuration(ms: number): string {
  const s = Math.floor(ms/1000), h = Math.floor(s/3600), m = Math.floor(s%3600/60);
  return h ? `${h}h ${m}m` : m ? `${m}m ${s%60}s` : `${s}s`;
}
