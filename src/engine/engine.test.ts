import { describe, expect, it } from 'vitest';
import { createRng } from './rng';
import { defaultRanges, generateProblem, operations, validateRanges, type Problem } from './generator';
import { breakdown, configKey, consistency, median, paceSeries, ppm, type Solve } from './scoring';
describe('seeded arithmetic', () => {
  it('replays exactly from a seed', () => {
    const run = () => { const rng = createRng('shared'); return Array.from({length:100}, () => generateProblem(defaultRanges, rng)); };
    expect(run()).toEqual(run());
  });
  it('generates correct integer arithmetic without immediate repeats', () => {
    const rng = createRng('invariants'); let previous: Problem | undefined;
    for (let i = 0; i < 5000; i++) {
      const p = generateProblem(defaultRanges, rng, previous);
      expect(p.id).not.toBe(previous?.id);
      expect(p.answer).toBe({ '+': p.a + p.b, '-': p.a - p.b, '×': p.a * p.b, '÷': p.a / p.b }[p.op]);
      expect(Number.isInteger(p.answer)).toBe(true); expect(p.answer).toBeGreaterThanOrEqual(0);
      previous = p;
    }
  });
  it('honors enabled operations and weights', () => {
    const ranges = structuredClone(defaultRanges); ranges['+'].weight = 0;
    for (const op of ['-', '÷'] as const) ranges[op].enabled = false;
    for (let i=0;i<100;i++) expect(generateProblem(ranges, createRng(String(i))).op).toBe('×');
  });
  it('rejects empty settings and impossible repetition without hanging', () => {
    const ranges = structuredClone(defaultRanges);
    for (const op of operations) ranges[op].enabled = false;
    expect(validateRanges(ranges)).toBeTruthy();
    ranges['+'] = {enabled:true,weight:1,minA:2,maxA:2,minB:3,maxB:3};
    const p = generateProblem(ranges, createRng('a'));
    expect(() => generateProblem(ranges, createRng('a'), p)).toThrow('only one problem');
  });
});
describe('scoring', () => {
  const problem = generateProblem(defaultRanges, createRng('score'));
  const solves: Solve[] = [1000,3000].map(timeMs => ({problem,op:problem.op,timeMs}));
  it('calculates median, pace and population coefficient of variation', () => {
    expect(median([3,1,2,4])).toBe(2.5); expect(ppm(2,4000)).toBe(30); expect(consistency(solves)).toBe(50);
    expect(breakdown(solves).find(x => x.op === problem.op)?.averageMs).toBe(2000);
    expect(paceSeries(solves,4000).at(-1)?.ppm).toBe(30);
  });
  it('keys equivalent configurations independent of object order', () => {
    expect(configKey({a:1,b:{c:2,d:3}})).toBe(configKey({b:{d:3,c:2},a:1}));
  });
});
