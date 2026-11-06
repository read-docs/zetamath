import '../engine/generator.dart';

/// Operand maxima per preset: (sum for + and −, a for × and ÷, b for × and ÷).
enum Difficulty {
  easy(20, 5, 20),
  normal(100, 12, 100),
  hard(1000, 20, 200);

  const Difficulty(this.sum, this.mulA, this.mulB);
  final int sum, mulA, mulB;
}

/// Applies a preset's bounds and keeps each operation's enabled flag and weight.
RangeConfig difficultyRanges(Difficulty d, RangeConfig ranges) => RangeConfig({
  for (final op in Operation.values)
    op: ranges[op].copyWith(
      minA: 2,
      minB: 2,
      maxA: op == Operation.add || op == Operation.subtract ? d.sum : d.mulA,
      maxB: op == Operation.add || op == Operation.subtract ? d.sum : d.mulB,
    ),
});

/// The preset whose bounds [ranges] use, or null for hand-edited ranges.
Difficulty? difficultyOf(RangeConfig ranges) {
  for (final d in Difficulty.values) {
    final preset = difficultyRanges(d, ranges);
    if (Operation.values.every((op) => preset[op] == ranges[op])) return d;
  }
  return null;
}

/// `easy`, `normal`, `hard` or `custom`, as web labels it.
String currentDifficulty(RangeConfig ranges) => difficultyOf(ranges)?.name ?? 'custom';
