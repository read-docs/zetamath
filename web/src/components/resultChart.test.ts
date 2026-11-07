import { expect, it } from "vitest";
import { resultChart } from "./resultChart";
import { defaultSettings } from "../store/settings";
import type { Result } from "../store/history";
const result = (elapsedMs: number, times: number[]): Result => ({
  ...defaultSettings,
  id: "chart",
  date: "2026-01-01",
  seed: "test",
  elapsedMs,
  logs: times.map((timeMs) => ({
    timeMs,
    problem: { id: "1+1", a: 1, b: 1, op: "+", answer: 2 },
  })),
});
it("bounds chart allocation for arbitrarily long imported sessions", () => {
  const graph = resultChart(result(1e15, [1000, 2000]));
  expect(graph).toHaveLength(300);
  expect(graph.every((point) => Number.isFinite(point.ppm))).toBe(true);
});
it("calculates trailing ten-second pace without counting older solves", () => {
  const graph = resultChart(result(12000, [1000, 1000, 9000]));
  expect(graph[1].ppm).toBe(60);
  expect(graph[10].ppm).toBe(12);
  expect(graph[11].ppm).toBe(6);
  expect(graph[10].slow).toBe(true);
});
