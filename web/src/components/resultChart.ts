import type { Result } from "../store/history";

/** At most 300 points; each solve is visited once even for very long sessions. */
export function resultChart(result: Result) {
  const duration = Math.max(1, Math.ceil(result.elapsedMs / 1000));
  const points = Math.min(300, duration);
  const mean =
    result.logs.reduce((sum, log) => sum + log.timeMs, 0) /
    (result.logs.length || 1);
  let accumulated = 0;
  const completions = result.logs.map((log) => ({
    at: (accumulated += log.timeMs) / 1000,
    slow: log.timeMs > mean * 1.5,
  }));
  let left = 0,
    right = 0,
    previousRight = 0;
  return Array.from({ length: points }, (_, i) => {
    const second = ((i + 1) * duration) / points;
    while (right < completions.length && completions[right].at <= second)
      right++;
    while (left < right && completions[left].at <= Math.max(0, second - 10))
      left++;
    let slow = false;
    for (let j = previousRight; j < right; j++) slow ||= completions[j].slow;
    previousRight = right;
    return { second, ppm: ((right - left) * 60) / Math.min(second, 10), slow };
  });
}
