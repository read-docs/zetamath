export type Operation = '+' | '-' | '×' | '÷';
export type OperationRange = { enabled: boolean; weight: number; minA: number; maxA: number; minB: number; maxB: number };
export type RangeConfig = Record<Operation, OperationRange>;
export type Problem = { a: number; b: number; op: Operation; answer: number; id: string };
export const operations: Operation[] = ['+', '-', '×', '÷'];
export const defaultRanges: RangeConfig = {
  '+': { enabled: true, weight: 1, minA: 2, maxA: 100, minB: 2, maxB: 100 },
  '-': { enabled: true, weight: 1, minA: 2, maxA: 100, minB: 2, maxB: 100 },
  '×': { enabled: true, weight: 1, minA: 2, maxA: 12, minB: 2, maxB: 100 },
  '÷': { enabled: true, weight: 1, minA: 2, maxA: 12, minB: 2, maxB: 100 },
};
export function validateRanges(ranges: RangeConfig): string | null {
  let enabled = 0;
  for (const op of operations) {
    const r = ranges[op];
    if (!r || typeof r.enabled !== 'boolean') return 'Invalid operation settings.';
    if (!Number.isFinite(r.weight) || r.weight < 0 || r.weight > 1000) return 'Weights must be between 0 and 1000.';
    for (const value of [r.minA, r.maxA, r.minB, r.maxB]) {
      if (!Number.isInteger(value) || value < 1 || value > 1000000) return 'Ranges must use whole numbers from 1 to 1,000,000.';
    }
    if (r.minA > r.maxA || r.minB > r.maxB) return 'Range minimum must not exceed maximum.';
    if (r.enabled && r.weight > 0) enabled++;
  }
  return enabled ? null : 'Enable at least one operation with a positive weight.';
}
function make(op: Operation, a: number, b: number): Problem {
  const answer = op === '+' ? a + b : op === '-' ? a : op === '×' ? a * b : a;
  if (op === '-') a += b;
  if (op === '÷') a *= b;
  return { a, b, op, answer, id: `${a}${op}${b}` };
}
/** Reversed addition/multiplication produce nonnegative subtraction and integral division. */
export function generateProblem(ranges: RangeConfig, rng: () => number, previous?: Problem | string): Problem {
  const error = validateRanges(ranges);
  if (error) throw new Error(error);
  const enabled = operations.filter(op => ranges[op].enabled && ranges[op].weight > 0);
  const total = enabled.reduce((sum, op) => sum + ranges[op].weight, 0);
  const previousId = typeof previous === 'string' ? previous : previous?.id;
  const int = (min: number, max: number) => min + Math.floor(rng() * (max - min + 1));
  let candidate: Problem;
  for (let attempt = 0; attempt < 64; attempt++) {
    let pick = rng() * total;
    const op = enabled.find(key => (pick -= ranges[key].weight) < 0) ?? enabled[enabled.length - 1];
    const r = ranges[op];
    candidate = make(op, int(r.minA, r.maxA), int(r.minB, r.maxB));
    if (candidate.id !== previousId) return candidate;
  }
  // Deterministic fallback prevents random retries from hanging on tiny domains.
  for (const op of enabled) {
    const r = ranges[op];
    for (const a of [r.minA, r.maxA]) for (const b of [r.minB, r.maxB]) {
      const problem = make(op, a, b);
      if (problem.id !== previousId) return problem;
    }
  }
  throw new Error('These ranges contain only one problem. Widen a range to avoid consecutive repeats.');
}
