// @vitest-environment jsdom
import {act} from 'react';
import {createRoot} from 'react-dom/client';
import {afterEach,expect,it,vi} from 'vitest';
import {useSession} from './useSession';
import {useHistory} from '../store/history';
import {defaultSettings,useSettings} from '../store/settings';

(globalThis as typeof globalThis & {IS_REACT_ACT_ENVIRONMENT: boolean}).IS_REACT_ACT_ENVIRONMENT = true;
afterEach(() => vi.restoreAllMocks());

it('finishes count sessions once and resets for the next run', async () => {
  useSettings.persist.setOptions({storage: {getItem: () => null, setItem: () => {}, removeItem: () => {}}});
  useSettings.setState({...defaultSettings,mode:'count',count:1});
  const add = vi.spyOn(useHistory.getState(), 'add').mockResolvedValue(false);
  vi.stubGlobal('requestAnimationFrame', () => 1);
  vi.stubGlobal('cancelAnimationFrame', () => {});
  let session!: ReturnType<typeof useSession>;
  function Harness() { session = useSession(vi.fn()); return null; }
  const root = createRoot(document.createElement('div'));
  try {
    await act(async () => root.render(<Harness/>));
    await act(async () => session.restart());
    expect(session.problem).toBeNull();
    expect(session.ready).toBe(true);
    let now = 100;
    vi.spyOn(performance, 'now').mockImplementation(() => now);
    await act(async () => session.begin());
    const answer = String(session.problem!.answer);
    for (const malformed of [answer + '-3', answer + '.0', answer + 'abc']) {
      await act(async () => session.answer(malformed));
      expect(session.score).toBe(0);
    }
    now += 1500;
    await act(async () => session.answer(answer));
    expect(session.result?.logs).toHaveLength(1);
    expect(session.result?.logs[0].timeMs).toBe(1500);
    expect(session.result?.elapsedMs).toBe(1500);
    expect(session.running).toBe(false);
    await act(async () => session.finish());
    expect(add).toHaveBeenCalledTimes(1);
    await act(async () => session.restart());
    expect(session.result).toBeNull();
    expect(session.score).toBe(0);
  } finally {
    await act(async () => root.unmount());
    vi.unstubAllGlobals();
  }
});

it('ignores stale personal bests and finishes backgrounded sessions once', async () => {
  useSettings.setState({...defaultSettings, mode:'time', duration:10});
  let resolve!: (value: boolean) => void;
  const add = vi.spyOn(useHistory.getState(), 'add').mockReturnValue(new Promise<boolean>(done => { resolve = done; }));
  vi.stubGlobal('requestAnimationFrame', () => 1);
  vi.stubGlobal('cancelAnimationFrame', () => {});
  let now = 100;
  vi.spyOn(performance, 'now').mockImplementation(() => now);
  let session!: ReturnType<typeof useSession>;
  function Harness() { session = useSession(vi.fn()); return null; }
  const root = createRoot(document.createElement('div'));
  try {
    await act(async () => root.render(<Harness/>));
    await act(async () => session.restart());
    await act(async () => session.begin());
    now += 20000;
    vi.spyOn(document, 'visibilityState', 'get').mockReturnValue('hidden');
    await act(async () => document.dispatchEvent(new Event('visibilitychange')));
    await act(async () => window.dispatchEvent(new Event('pagehide')));
    expect(session.result?.elapsedMs).toBe(10000);
    expect(add).toHaveBeenCalledTimes(1);
    await act(async () => session.restart());
    await act(async () => resolve(true));
    expect(session.pb).toBe(false);
    expect(session.result).toBeNull();
  } finally {
    await act(async () => root.unmount());
    vi.unstubAllGlobals();
  }
});
