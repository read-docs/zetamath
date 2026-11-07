import { useMemo, useState } from "react";
import {
  ResponsiveContainer,
  ComposedChart,
  Line,
  Scatter,
  XAxis,
  YAxis,
  Tooltip,
  CartesianGrid,
} from "recharts";
import {
  useHistory,
  isCountRun,
  isCompletedRun,
  pace,
  type Result,
} from "../store/history";
import { useSettings } from "../store/settings";
import { currentDifficulty } from "../store/difficulty";
import {
  activityByDay,
  bestsFor,
  dayKey,
  formatDuration,
  level,
  paceSeries,
  streaks,
  summary,
  variation,
} from "../store/profile";
import { countOptions, timeOptions } from "./ModeBar";

const months = [
  "jan",
  "feb",
  "mar",
  "apr",
  "may",
  "jun",
  "jul",
  "aug",
  "sep",
  "oct",
  "nov",
  "dec",
];
const dateLabel = (iso: string) =>
  new Date(iso).toLocaleDateString(undefined, {
    day: "numeric",
    month: "short",
    year: "numeric",
  });

function Heatmap({ results }: { results: Result[] }) {
  const { weeks, total, max } = useMemo(() => {
    const days = activityByDay(results),
      today = new Date();
    const start = new Date(
      today.getFullYear(),
      today.getMonth(),
      today.getDate() - today.getDay() - 52 * 7,
    );
    const weeks: { date: Date; count: number }[][] = [];
    let total = 0,
      max = 0;
    for (
      let d = start;
      d <= today;
      d = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1)
    ) {
      if (d.getDay() === 0) weeks.push([]);
      const count = days.get(dayKey(d)) || 0;
      weeks[weeks.length - 1].push({ date: d, count });
      total += count;
      max = Math.max(max, count);
    }
    return { weeks, total, max };
  }, [results]);
  const shade = (n: number) =>
    n === 0 ? 0 : Math.min(4, Math.ceil((n / max) * 4));
  return (
    <div className="profile-box">
      <div className="box-head">
        <span>test activity</span>
        <span>
          {total} {total === 1 ? "test" : "tests"} in the last year
        </span>
      </div>
      <details>
        <summary>Activity by day</summary>
        <ul>
          {[...activityByDay(results)]
            .sort((a, b) => b[0].localeCompare(a[0]))
            .map(([date, count]) => (
              <li key={date}>
                {date}: {count} sessions
              </li>
            ))}
        </ul>
      </details>
      <div className="heatmap-scroll" aria-hidden="true">
        <div
          className="heatmap"
          style={{ gridTemplateColumns: `repeat(${weeks.length}, 1fr)` }}
        >
          {weeks.map((w, i) => {
            const first = w.find((d) => d.date.getDate() === 1);
            return (
              <span key={"m" + i} className="heatmap-month">
                {first ? months[first.date.getMonth()] : ""}
              </span>
            );
          })}
          {weeks.map((w, i) => (
            <div key={i} className="heatmap-week">
              {w.map((d) => (
                <span
                  key={d.date.getTime()}
                  className={`heatmap-day level-${shade(d.count)}`}
                  title={`${d.count} ${d.count === 1 ? "test" : "tests"} on ${dateLabel(d.date.toISOString())}`}
                />
              ))}
            </div>
          ))}
        </div>
      </div>
      <div className="heatmap-legend">
        <span>less</span>
        {[0, 1, 2, 3, 4].map((l) => (
          <span key={l} className={`heatmap-day level-${l}`} />
        ))}
        <span>more</span>
      </div>
    </div>
  );
}

function Bests({
  unit,
  targets,
  bests,
}: {
  unit: string;
  targets: number[];
  bests: Map<number, Result>;
}) {
  return (
    <div className="profile-box pb-box">
      {targets.map((t) => {
        const r = bests.get(t);
        return (
          <div key={t} className="pb" tabIndex={r ? 0 : -1}>
            <div className="pb-summary">
              <span className="pb-label">
                {t} {unit}
              </span>
              <strong>{r ? Math.round(pace(r)) : "-"}</strong>
              <span className="pb-label">
                {r
                  ? isCountRun(r)
                    ? `${(r.elapsedMs / 1000).toFixed(2)}s`
                    : `${r.logs.length} solved`
                  : "-"}
              </span>
            </div>
            {r && (
              <div className="pb-detail">
                <span className="pb-label">
                  {t} {unit}
                </span>
                <span>{Math.round(pace(r))} ppm</span>
                <span>{r.logs.length} solved</span>
                <span>{(r.elapsedMs / 1000).toFixed(2)}s</span>
                <span>{variation(r).toFixed(1)}% var</span>
                <span className="pb-label">{dateLabel(r.date)}</span>
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

const Stat = ({ label, value }: { label: string; value: string | number }) => (
  <div className="profile-stat">
    <span>{label}</span>
    <strong>{value}</strong>
  </div>
);

export default function Profile({ open }: { open: (r: Result) => void }) {
  const h = useHistory(),
    s = useSettings();
  const [shown, setShown] = useState(10);
  const stats = useMemo(() => summary(h.results, s), [h.results, s]);
  const streak = useMemo(() => streaks(h.results), [h.results]);
  const xp = useMemo(() => level(h.results), [h.results]);
  const series = useMemo(() => paceSeries(h.results, s), [h.results, s]);
  const timeBests = useMemo(
    () => bestsFor(h.results, "time", timeOptions, s.ranges),
    [h.results, s.ranges],
  );
  const countBests = useMemo(
    () => bestsFor(h.results, "count", countOptions, s.ranges),
    [h.results, s.ranges],
  );
  const difficulty = currentDifficulty(s.ranges);
  const name = s.name.trim() || "guest";

  return (
    <section className="profile">
      <div className="profile-box profile-card">
        <div className="profile-id">
          <div className="avatar" aria-hidden="true">
            {name[0].toUpperCase()}
          </div>
          <div className="profile-who">
            <div className="profile-name">{name}</div>
            <div className="profile-sub">
              {stats.joined
                ? `joined ${dateLabel(stats.joined)}`
                : "no tests yet"}
            </div>
            <div className="profile-sub">
              {streak.current} day streak
              {streak.longest > streak.current
                ? ` · best ${streak.longest}`
                : ""}
            </div>
          </div>
          <div className="xp-row" title={`${xp.into} / ${xp.needed} xp`}>
            <span className="level-badge">{xp.level}</span>
            <div className="xp-bar">
              <div style={{ width: `${(xp.into / xp.needed) * 100}%` }} />
            </div>
            <span className="profile-sub">
              {xp.into}/{xp.needed}
            </span>
          </div>
        </div>
        <div className="profile-column">
          <Stat label="tests completed" value={stats.tests} />
          <Stat label="problems solved" value={stats.solved} />
          <Stat label="time practicing" value={formatDuration(stats.timeMs)} />
        </div>
        <div className="profile-column">
          <Stat
            label="highest pace"
            value={`${Math.round(stats.highestPace)} ppm`}
          />
          <Stat
            label="average pace"
            value={`${Math.round(stats.averagePace)} ppm`}
          />
          <Stat label="total xp" value={xp.xp} />
        </div>
      </div>

      <div className="pb-row">
        <Bests unit="seconds" targets={timeOptions} bests={timeBests} />
        <Bests unit="problems" targets={countOptions} bests={countBests} />
      </div>
      <p className="pb-caption">
        personal bests in problems per minute at{" "}
        {difficulty === "custom"
          ? "your custom ranges"
          : `${difficulty} difficulty`}{" "}
        · focus or hover for details
      </p>

      <Heatmap results={h.results} />

      {series.length > 1 && (
        <div className="profile-chart">
          <div className="box-head">
            <span>completed tests at current mode, goal and ranges</span>
            <span className="legend">
              <i className="dot" />
              ppm <i className="line main" />
              last 10 avg <i className="line sub" />
              last 100 avg
            </span>
          </div>
          <div style={{ height: 260, width: "100%" }}>
            <ResponsiveContainer>
              <ComposedChart data={series}>
                <CartesianGrid
                  stroke="var(--sub)"
                  strokeOpacity={0.12}
                  vertical={false}
                />
                <XAxis dataKey="test" stroke="var(--sub)" tickLine={false} />
                <YAxis
                  stroke="var(--sub)"
                  tickLine={false}
                  axisLine={false}
                  width={36}
                />
                <Tooltip
                  contentStyle={{
                    background: "var(--bg)",
                    borderColor: "var(--sub)",
                  }}
                  labelFormatter={(_, p) =>
                    p?.[0] ? dateLabel(p[0].payload.date) : ""
                  }
                />
                <Scatter
                  dataKey="ppm"
                  name="ppm"
                  fill="var(--main)"
                  fillOpacity={0.6}
                  isAnimationActive={false}
                />
                <Line
                  type="monotone"
                  dataKey="average10"
                  name="last 10 avg"
                  stroke="var(--main)"
                  strokeWidth={2}
                  dot={false}
                  isAnimationActive={false}
                />
                <Line
                  type="monotone"
                  dataKey="average100"
                  name="last 100 avg"
                  stroke="var(--sub)"
                  strokeWidth={2}
                  dot={false}
                  isAnimationActive={false}
                />
              </ComposedChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}

      <p className="pb-caption">
        Pace means problems per minute. Pace statistics and trends compare
        completed tests at your current mode, goal and ranges.
      </p>
      <div className="profile-stats">
        <Stat
          label="average pace (last 10 comparable tests)"
          value={`${Math.round(stats.last10Pace)} ppm`}
        />
        <Stat
          label="average solve-time variation"
          value={`${stats.averageVariation.toFixed(1)}%`}
        />
        <Stat label="longest streak" value={`${streak.longest}d`} />
      </div>

      {!h.results.length ? (
        <p className="hint">
          Your first session is the start of a habit. Completed tests will
          appear here.
        </p>
      ) : (
        <>
          <div className="table-wrap">
            <table className="results-table">
              <thead>
                <tr>
                  <th>ppm</th>
                  <th>solved</th>
                  <th>variation</th>
                  <th>mode</th>
                  <th>difficulty</th>
                  <th>date</th>
                </tr>
              </thead>
              <tbody>
                {h.results.slice(0, shown).map((r) => (
                  <tr key={r.id} onClick={() => open(r)}>
                    <td>{Math.round(pace(r))}</td>
                    <td>{r.logs.length}</td>
                    <td>{variation(r).toFixed(1)}%</td>
                    <td>
                      {r.mode === "zen"
                        ? "zen"
                        : `${r.mode === "custom" ? "custom " : ""}${isCountRun(r) ? `${r.count} problems` : `${r.duration}s`}`}
                      {r.drill
                        ? " · drill"
                        : r.mode === "zen"
                          ? " · practice"
                          : isCompletedRun(r)
                            ? " · complete"
                            : " · interrupted"}
                    </td>
                    <td>{currentDifficulty(r.ranges)}</td>
                    <td>
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          open(r);
                        }}
                      >
                        {new Date(r.date).toLocaleString(undefined, {
                          day: "numeric",
                          month: "short",
                          year: "numeric",
                          hour: "2-digit",
                          minute: "2-digit",
                        })}
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {shown < h.results.length && (
            <button
              className="load-more"
              onClick={() => setShown((n) => n + 10)}
            >
              load more
            </button>
          )}
        </>
      )}
    </section>
  );
}
