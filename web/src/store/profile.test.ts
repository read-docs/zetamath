import {describe,expect,it} from 'vitest';
import {defaultRanges} from '../engine/generator';
import {difficultyRanges} from './difficulty';
import type {Result} from './history';
import {bestsFor,formatDuration,level,paceSeries,streaks,summary} from './profile';

const result = (id: string, date: string, solved = 10, extra: Partial<Result> = {}): Result => ({
  id, date, mode: 'time', duration: 15, count: 25, customKind: 'time', ranges: structuredClone(defaultRanges),
  seed: 's', elapsedMs: 15000,
  logs: Array.from({length: solved}, () => ({problem: {a: 2, b: 3, op: '+' as const, answer: 5, id: '2+3'}, timeMs: 1500})),
  ...extra,
});
const at = (y: number, m: number, d: number) => new Date(y, m-1, d, 12).toISOString();

describe('profile', () => {
  it('counts the current streak from today or yesterday', () => {
    const runs = [result('a', at(2026,11,4)), result('b', at(2026,11,5)), result('c', at(2026,11,1))];
    expect(streaks(runs, new Date(2026,10,6))).toEqual({current: 2, longest: 2});
    expect(streaks(runs, new Date(2026,10,8))).toEqual({current: 0, longest: 2});
  });
  it('summarises totals and leaves drills out of pace', () => {
    const s = summary([result('a', at(2026,11,5), 10), result('b', at(2026,11,6), 20, {drill: true})]);
    expect(s).toMatchObject({tests: 2, solved: 30, timeMs: 30000, highestPace: 40, averagePace: 40, joined: at(2026,11,5)});
  });
  it('keeps the best run per length for the given ranges only', () => {
    const easy = difficultyRanges('easy', defaultRanges);
    const bests = bestsFor([
      result('slow', at(2026,11,5), 10), result('fast', at(2026,11,5), 12),
      result('easy', at(2026,11,5), 30, {ranges: easy}), result('60', at(2026,11,5), 5, {duration: 60, elapsedMs: 60000}),
    ], 'time', [15,30,60,120], defaultRanges);
    expect(bests.get(15)?.id).toBe('fast');
    expect(bests.get(60)?.id).toBe('60');
    expect(bests.has(30)).toBe(false);
  });
  it('builds an oldest-first pace series with trailing averages', () => {
    const series = paceSeries([result('b', at(2026,11,6), 20), result('a', at(2026,11,5), 10)]);
    expect(series.map(p => [p.ppm, p.average10, p.average100])).toEqual([[40, 40, 40], [80, 60, 60]]);
  });
  it('levels up on a growing xp curve', () => {
    expect(level([])).toEqual({level: 1, xp: 0, into: 0, needed: 100});
    expect(level([result('a', at(2026,11,5), 10)])).toEqual({level: 2, xp: 100, into: 0, needed: 150});
    expect(level([result('a', at(2026,11,5), 30)])).toEqual({level: 3, xp: 300, into: 50, needed: 200});
  });
  it('formats durations', () => {
    expect(formatDuration(42000)).toBe('42s');
    expect(formatDuration(125000)).toBe('2m 5s');
    expect(formatDuration(3_780_000)).toBe('1h 3m');
  });
});
