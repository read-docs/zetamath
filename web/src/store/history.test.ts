import { describe, expect, it, vi } from 'vitest';
import { defaultRanges } from '../engine/generator';
import { createHistoryStore, parseHistory, personalBests, resultKey, type Result } from './history';
const result = (id: string, elapsedMs = 2000): Result => ({
  id, date: '2026-11-06T10:00:00Z', mode: 'count', duration: 120, count: 1,
  customKind: 'time', ranges: structuredClone(defaultRanges), seed: 'test', elapsedMs,
  logs: [{problem: {a: 2,b: 3,op: '+',answer: 5,id: '2+3'}, timeMs: elapsedMs}],
});
describe('history', () => {
  it('round trips versioned exports and rejects malformed answers', () => {
    const r = result('a');
    expect(parseHistory(JSON.stringify({version: 1,results: [r]}))).toEqual([r]);
    r.logs[0].problem.answer = 6;
    expect(() => parseHistory(JSON.stringify([r]))).toThrow('Invalid history');
    expect(() => parseHistory('{"version":2,"results":[]}')).toThrow();
  });
  it('uses faster count results and excludes drills', () => {
    const a = result('a'), b = result('b', 1000), drill = {...result('drill', 100), drill: true};
    expect(personalBests([a,b,drill])).toEqual([b]);
  });
  it('separates operation configurations and count targets', () => {
    const a = result('a'), b = result('b');
    b.ranges['+'].weight = 2;
    expect(resultKey(a)).not.toBe(resultKey(b));
    b.ranges = a.ranges;
    b.count = 25;
    expect(resultKey(a)).not.toBe(resultKey(b));
  });
  it('excludes unfinished sessions from personal bests', () => {
    expect(personalBests([{...result('partial'),count:10}])).toEqual([]);
    expect(personalBests([{...result('partial'),mode:'time'}])).toEqual([]);
  });
  it('scores time mode by solved count', () => {
    const a = {...result('a'),elapsedMs:120000,mode: 'time' as const};
    const b = {...a,id: 'b', logs: [...a.logs,...a.logs]};
    expect(personalBests([a,b])).toEqual([b]);
  });
});

describe('history persistence', () => {
  it('blocks writes after failed loads and retries without losing stored records', async () => {
    const load = vi.fn().mockRejectedValue(new Error('offline'));
    const save = vi.fn().mockResolvedValue(undefined);
    const store = createHistoryStore({load, save});
    await expect(store.getState().add(result('new'))).rejects.toThrow('offline');
    await expect(store.getState().importJSON(JSON.stringify([result('import')]))).rejects.toThrow();
    await expect(store.getState().clear()).rejects.toThrow();
    expect(save).not.toHaveBeenCalled();
    expect(store.getState().loaded).toBe(false);
    load.mockResolvedValue([result('existing')]);
    await store.getState().add(result('new'));
    expect(save).toHaveBeenLastCalledWith([result('new'), result('existing')]);
  });

  it('serializes overlapping imports and additions against delayed storage', async () => {
    let release!: () => void;
    const gate = new Promise<void>(resolve => { release = resolve; });
    const save = vi.fn().mockImplementationOnce(() => gate).mockResolvedValue(undefined);
    const store = createHistoryStore({load: async () => [], save});
    const first = store.getState().importJSON(JSON.stringify([result('a')]));
    await vi.waitFor(() => expect(save).toHaveBeenCalledTimes(1));
    const second = store.getState().importJSON(JSON.stringify([result('b')]));
    const third = store.getState().add(result('c'));
    release();
    await Promise.all([first, second, third]);
    expect(store.getState().results.map(r => r.id).sort()).toEqual(['a','b','c']);
    expect(save.mock.calls.at(-1)?.[0]).toEqual(store.getState().results);
  });

  it('continues processing after a failed mutation', async () => {
    const save = vi.fn().mockRejectedValueOnce(new Error('full')).mockResolvedValue(undefined);
    const store = createHistoryStore({load: async () => [result('a')], save});
    await expect(store.getState().clear()).rejects.toThrow('full');
    expect(store.getState().results).toEqual([result('a')]);
    await store.getState().add(result('b'));
    expect(store.getState().results.map(r => r.id)).toEqual(['b','a']);
  });
});
