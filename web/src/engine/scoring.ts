import { operations, type Problem, type Operation } from './generator';
export type Solve = { problem: Problem; op: Operation; timeMs: number };
export function median(values: number[]): number {
  if (!values.length) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}
export function ppm(count: number, elapsedMs: number): number {
  return elapsedMs > 0 ? count * 60000 / elapsedMs : 0;
}
/** Coefficient of variation, as a percentage; lower is more consistent. */
export function consistency(solves: Solve[]): number {
  if (!solves.length) return 0;
  const mean = solves.reduce((s, x) => s + x.timeMs, 0) / solves.length;
  return mean > 0 ? Math.sqrt(solves.reduce((s, x) => s + (x.timeMs - mean) ** 2, 0) / solves.length) / mean * 100 : 0;
}
export function breakdown(solves: Solve[]) {
  return operations.map(op => {
    const times = solves.filter(s => s.op === op).map(s => s.timeMs);
    return { op, count: times.length, averageMs: times.length ? times.reduce((a, b) => a + b, 0) / times.length : 0, medianMs: median(times) };
  });
}
export function slowest(solves: Solve[], limit = 10): Solve[] {
  return [...solves].sort((a, b) => b.timeMs - a.timeMs).slice(0, limit);
}
export function paceSeries(solves: Solve[], elapsedMs: number, windowSeconds = 10) {
  let time = 0;
  const events = solves.map(s => ({ end: time += s.timeMs, timeMs: s.timeMs }));
  const slowThreshold = median(solves.map(s => s.timeMs)) * 1.5;
  return Array.from({ length: Math.ceil(elapsedMs / 1000) }, (_, i) => {
    const end = Math.min((i + 1) * 1000, elapsedMs);
    const start = Math.max(0, end - windowSeconds * 1000);
    const recent = events.filter(e => e.end > start && e.end <= end);
    return { second: end / 1000, ppm: ppm(recent.length, end - start), slow: events.some(e => e.end > i * 1000 && e.end <= end && e.timeMs > slowThreshold) };
  });
}
/** Stable serialization is sufficient as a collision-free configuration key. */
export function configKey(config: unknown): string {
  const stable = (value: unknown): unknown => Array.isArray(value) ? value.map(stable) : value !== null && typeof value === 'object'
    ? Object.fromEntries(Object.entries(value).sort(([a], [b]) => a.localeCompare(b)).map(([key, v]) => [key, stable(v)])) : value;
  return JSON.stringify(stable(config));
}
