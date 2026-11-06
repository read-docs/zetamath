import { create } from 'zustand';
import { get, set as put } from 'idb-keyval';
import type { RangeConfig, Problem } from '../engine/generator';
import type { Settings } from './settings';

export interface Result {
  id: string;
  date: string;
  mode: Settings['mode'];
  duration: number;
  count: number;
  customKind: Settings['customKind'];
  ranges: RangeConfig;
  seed: string;
  elapsedMs: number;
  logs: { problem: Problem; timeMs: number }[];
  drill?: boolean;
}
const operations = ['+', '-', '×', '÷'] as const;
export function resultKey(r: Result): string {
  const target = r.mode === 'count' || (r.mode === 'custom' && r.customKind === 'count') ? r.count : r.duration;
  return JSON.stringify([r.mode, r.mode === 'custom' ? r.customKind : '', target,
    operations.map(op => [op, r.ranges[op].enabled, r.ranges[op].weight, r.ranges[op].minA, r.ranges[op].maxA, r.ranges[op].minB, r.ranges[op].maxB])]);
}
export const pace = (r: Result) => r.elapsedMs > 0 ? r.logs.length * 60000 / r.elapsedMs : 0;
function better(a: Result, b: Result): boolean {
  return a.mode === 'count' || (a.mode === 'custom' && a.customKind === 'count')
    ? a.elapsedMs < b.elapsedMs : a.logs.length > b.logs.length;
}
export function personalBests(results: Result[]): Result[] {
  const best = new Map<string, Result>();
  for (const r of results) {
    if (r.drill || r.mode === 'zen' || !r.logs.length) continue;
    const countMode = r.mode === 'count' || (r.mode === 'custom' && r.customKind === 'count');
    if (countMode ? r.logs.length < r.count : r.elapsedMs < r.duration * 1000) continue;
    const key = resultKey(r), previous = best.get(key);
    if (!previous || better(r, previous)) best.set(key, r);
  }
  return [...best.values()];
}
function validResult(value: unknown): value is Result {
  if (!value || typeof value !== 'object') return false;
  const r = value as Result;
  if (typeof r.id !== 'string' || !r.id || typeof r.seed !== 'string' || typeof r.date !== 'string' || !Number.isFinite(Date.parse(r.date)) ||
    !['time','count','zen','custom'].includes(r.mode) || !['time','count'].includes(r.customKind) ||
    !Number.isFinite(r.elapsedMs) || r.elapsedMs < 0 || !Number.isSafeInteger(r.duration) || r.duration <= 0 ||
    !Number.isSafeInteger(r.count) || r.count <= 0 || !Array.isArray(r.logs) || !r.ranges ||
    (r.drill !== undefined && typeof r.drill !== 'boolean')) return false;
  if (!operations.every(op => {
    const c = r.ranges[op];
    return c && typeof c.enabled === 'boolean' && Number.isFinite(c.weight) && c.weight >= 0 &&
      [c.minA,c.maxA,c.minB,c.maxB].every(n => Number.isSafeInteger(n) && n >= 0 && n <= 1000000) && c.minA <= c.maxA && c.minB <= c.maxB;
  })) return false;
  return r.logs.every(l => {
    const p = l?.problem;
    if (!p || !operations.includes(p.op) || typeof p.id !== 'string' ||
      ![p.a,p.b,p.answer].every(Number.isSafeInteger) || !Number.isFinite(l.timeMs) || l.timeMs < 0) return false;
    return p.answer === (p.op === '+' ? p.a + p.b : p.op === '-' ? p.a - p.b : p.op === '×' ? p.a * p.b : p.a / p.b);
  });
}
export function parseHistory(json: string): Result[] {
  const data: unknown = JSON.parse(json);
  const records = Array.isArray(data) ? data : (data as {version?: number; results?: unknown})?.version === 1 ? (data as {results: unknown}).results : null;
  if (!Array.isArray(records) || !records.every(validResult)) throw new Error('Invalid history file. Choose a Zetamath JSON export.');
  return records;
}
const key = 'zetamath-results-v1';
let loading: Promise<void> | undefined;
let writes = Promise.resolve();
function persist(results: Result[]): Promise<void> {
  writes = writes.catch(() => {}).then(() => put(key, results));
  return writes;
}
interface HistoryStore {
  results: Result[]; loaded: boolean; error: string | null;
  load: () => Promise<void>;
  add: (result: Result) => Promise<boolean>;
  importJSON: (json: string) => Promise<number>;
  exportJSON: () => string;
  clear: () => Promise<void>;
}
export const useHistory = create<HistoryStore>((set, state) => ({
  results: [], loaded: false, error: null,
  load: () => {
    if (state().loaded) return Promise.resolve();
    if (!loading) loading = get<unknown>(key).then(data => {
      const results = data === undefined ? [] : parseHistory(JSON.stringify(data));
      set({results, loaded: true, error: null});
    }).catch(error => { set({loaded: true, error: `History could not be loaded: ${String(error)}`}); }).finally(() => { loading = undefined; });
    return loading;
  },
  add: async result => {
    await state().load();
    const previous = personalBests(state().results).find(r => resultKey(r) === resultKey(result));
    const isPB = personalBests([result]).length > 0 && (!previous || better(result, previous));
    const results = [result, ...state().results.filter(r => r.id !== result.id)];
    set({results});
    try { await persist(results); set({error: null}); }
    catch { set({error: 'History could not be saved. Export your results to keep a backup.'}); }
    return isPB;
  },
  importJSON: async json => {
    const imported = parseHistory(json);
    await state().load();
    const merged = new Map(state().results.map(r => [r.id, r]));
    for (const r of imported) merged.set(r.id, r);
    const results = [...merged.values()].sort((a,b) => Date.parse(b.date) - Date.parse(a.date));
    await persist(results);
    set({results, error: null});
    return imported.length;
  },
  exportJSON: () => JSON.stringify({version: 1, results: state().results}, null, 2),
  clear: async () => { await persist([]); set({results: [], error: null}); },
}));
