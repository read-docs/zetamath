import { lazy, Suspense, useMemo } from "react";
import { operations, type Problem } from "../engine/generator";
import { isCountRun, pace, type Result } from "../store/history";
import { variation } from "../store/profile";
import { resultChart } from "./resultChart";
const Chart = lazy(() => import("./PaceChart"));

export default function ResultsView({
  result,
  personalBest,
  restart,
  profile,
}: {
  result: Result;
  personalBest: boolean;
  restart: (problems?: Problem[]) => void;
  profile: () => void;
}) {
  const graph = useMemo(() => resultChart(result), [result]);
  const slowest = useMemo(
    () => [...result.logs].sort((a, b) => b.timeMs - a.timeMs).slice(0, 10),
    [result],
  );
  const complete =
    result.mode === "zen" ||
    (isCountRun(result)
      ? result.logs.length >= result.count
      : result.elapsedMs >= result.duration * 1000);
  return (
    <section>
      <h1 className="page-title">
        {complete ? "A little sharper." : "Practice saved."}
      </h1>
      {!complete && (
        <p>
          This session ended early. It does not count as a completed test or
          personal best.
        </p>
      )}
      {personalBest && <p role="status">✦ new personal best</p>}
      <div className="stats-grid">
        <div className="stat">
          solved<strong>{result.logs.length}</strong>
        </div>
        <div className="stat">
          pace
          <strong>
            {Math.round(pace(result))} <small>ppm</small>
          </strong>
          <small>problems per minute</small>
        </div>
        <div className="stat">
          time<strong>{(result.elapsedMs / 1000).toFixed(2)}s</strong>
        </div>
        <div className="stat">
          variation<strong>{variation(result).toFixed(1)}%</strong>
          <small>lower means more consistent solve times</small>
        </div>
      </div>
      <Suspense fallback={<p>Loading chart…</p>}>
        <Chart data={graph} />
      </Suspense>
      <div className="settings-grid">
        <div className="panel">
          <h2>By operation</h2>
          {operations.map((op) => {
            const times = result.logs
              .filter((log) => log.problem.op === op)
              .map((log) => log.timeMs)
              .sort((a, b) => a - b);
            return (
              <p key={op}>
                {op} · {times.length} solved · avg{" "}
                {times.length
                  ? (
                      times.reduce((a, b) => a + b, 0) /
                      times.length /
                      1000
                    ).toFixed(2)
                  : "—"}
                s · median{" "}
                {times.length
                  ? (
                      (times[Math.floor((times.length - 1) / 2)] +
                        times[Math.floor(times.length / 2)]) /
                      2000
                    ).toFixed(2)
                  : "—"}
                s
              </p>
            );
          })}
        </div>
        <div className="panel">
          <h2>Practice your slowest problems</h2>
          <p>Take your time with these, then try another test.</p>
          <ol className="slow-list">
            {slowest.map((log, i) => (
              <li key={i}>
                {log.problem.a} {log.problem.op} {log.problem.b} ={" "}
                {log.problem.answer}
                <span>{(log.timeMs / 1000).toFixed(2)}s</span>
              </li>
            ))}
          </ol>
          <button
            disabled={!slowest.length}
            onClick={() => restart(slowest.map((log) => log.problem))}
          >
            drill these
          </button>
        </div>
      </div>
      <div className="result-actions">
        <button onClick={() => restart()}>try again</button>
        <button onClick={profile}>view profile</button>
      </div>
    </section>
  );
}
