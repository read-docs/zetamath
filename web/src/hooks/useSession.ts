import {useEffect, useRef, useState} from 'react';
import {generateProblem, validateRanges, type Problem} from '../engine/generator';
import {createRng} from '../engine/rng';
import {useSettings, type Settings} from '../store/settings';
import {useHistory, type Result} from '../store/history';

export function useSession(setError: (message: string) => void) {
  const [problem, setProblem] = useState<Problem | null>(null);
  const [input, setInput] = useState('');
  const [elapsed, setElapsed] = useState(0);
  const [running, setRunning] = useState(false);
  const [ready, setReady] = useState(false);
  const [result, updateResult] = useState<Result | null>(null);
  const [pb, setPb] = useState(false);
  const [score, setScore] = useState(0);
  const field = useRef<HTMLInputElement>(null);
  const start = useRef<number | null>(null);
  const last = useRef(0);
  const logs = useRef<Result['logs']>([]);
  const rng = useRef(createRng(''));
  const seed = useRef('');
  const config = useRef<Settings>(useSettings.getState());
  const drill = useRef<Problem[] | null>(null);
  const drillIndex = useRef(0);
  const displayedResult = useRef<string | null>(null);
  const mounted = useRef(true);
  const currentProblem = useRef<Problem | null>(null);

  function setResult(value: Result | null) {
    displayedResult.current = value?.id ?? null;
    setPb(false);
    updateResult(value);
  }

  function next(previous?: Problem) {
    const p = drill.current
      ? drill.current[drillIndex.current++ % drill.current.length]
      : generateProblem(config.current.ranges, rng.current, previous);
    currentProblem.current = p;
    setProblem(p);
  }

  function restart(problems: Problem[] | null = null) {
    start.current = null;
    currentProblem.current = null;
    setRunning(false);
    setElapsed(0);
    setScore(0);
    logs.current = [];
    setInput('');
    setProblem(null);
    setResult(null);
    config.current = {...useSettings.getState()};
    drill.current = problems?.length ? problems : null;
    drillIndex.current = 0;
    seed.current = new URLSearchParams(location.search).get('seed') || crypto.randomUUID();
    rng.current = createRng(seed.current);
    const issue = drill.current ? null : validateRanges(config.current.ranges);
    setError(issue || '');
    setReady(!issue);
  }

  // Reveal the problem only when timing begins: reading the first question counts too.
  function begin() {
    if (!ready || start.current !== null) return;
    try { next(); }
    catch (e) { setReady(false); setError(String(e)); return; }
    start.current = performance.now();
    last.current = start.current;
    setReady(false);
    setRunning(true);
    requestAnimationFrame(() => field.current?.focus());
  }

  function finish(now = performance.now()) {
    if (start.current === null) return;
    const c = config.current;
    const timed = c.mode === 'time' || c.mode === 'custom' && c.customKind === 'time';
    const ms = Math.max(0, Math.min(now - start.current, timed ? c.duration * 1000 : Infinity));
    start.current = null;
    setRunning(false);
    setElapsed(ms);
    const r: Result = {
      id: crypto.randomUUID(), date: new Date().toISOString(), mode: c.mode,
      duration: c.duration, count: c.count, customKind: c.customKind,
      ranges: c.ranges, seed: seed.current, elapsedMs: ms,
      logs: [...logs.current], drill: !!drill.current,
    };
    setResult(r);
    void useHistory.getState().add(r).then(value => {
      if (mounted.current && displayedResult.current === r.id) setPb(value);
    }).catch(e => {
      if (mounted.current && displayedResult.current === r.id) setError(String(e));
    });
  }

  useEffect(() => {
    mounted.current = true;
    const hidden = () => { if (document.visibilityState === 'hidden') finish(); };
    const leave = () => finish();
    document.addEventListener('visibilitychange', hidden);
    window.addEventListener('pagehide', leave);
    return () => {
      mounted.current = false;
      document.removeEventListener('visibilitychange', hidden);
      window.removeEventListener('pagehide', leave);
    };
  }, []);

  useEffect(() => {
    if (!running) return;
    let frame: number;
    const tick = () => {
      if (start.current === null) return;
      const ms = performance.now() - start.current;
      const c = config.current;
      const timed = c.mode === 'time' || c.mode === 'custom' && c.customKind === 'time';
      if (timed && ms >= c.duration * 1000) { finish(); return; }
      setElapsed(ms);
      frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [running]);

  function answer(value: string) {
    const p = currentProblem.current;
    if (!p || start.current === null) return;
    // Reject malformed input rather than interpreting a valid numeric prefix.
    if (!/^-?\d*$/.test(value)) return;
    setInput(value);
    const now = performance.now();
    const c = config.current;
    if ((c.mode === 'time' || c.mode === 'custom' && c.customKind === 'time') && now - start.current >= c.duration * 1000) {
      finish(now); return;
    }
    if (/^-?\d+$/.test(value) && Number(value) === p.answer) {
      logs.current.push({problem: p, timeMs: now - last.current});
      last.current = now;
      setScore(logs.current.length);
      setInput('');
      if ((c.mode === 'count' || c.mode === 'custom' && c.customKind === 'count') && logs.current.length >= c.count) {
        finish(now); return;
      }
      try { next(p); }
      catch (e) { setError(String(e)); finish(now); }
    }
  }

  return {problem, input, elapsed, running, ready, result, pb, score, field, config, restart, begin, finish, answer, setResult};
}
