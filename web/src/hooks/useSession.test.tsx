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
    const answer = String(session.problem!.answer);
    await act(async () => session.answer(answer));
    expect(session.result?.logs).toHaveLength(1);
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
