import 'package:flutter_test/flutter_test.dart';
import 'package:zetamath/engine/generator.dart';
import 'package:zetamath/engine/scoring.dart';

import '../fixtures.dart';

Solve _solve(Map json) => Solve(problem: Problem.fromJson(json['problem']), timeMs: (json['timeMs'] as num).toDouble());

void main() {
  final scoring = fixture('scoring.json');

  test('matches web stats for every solve log', () {
    for (final c in scoring['cases'] as List) {
      final solves = [for (final s in c['solves'] as List) _solve(s)];
      final elapsed = (c['elapsedMs'] as num).toDouble();
      final why = c['name'] as String;
      expect(median([for (final s in solves) s.timeMs]), c['median'], reason: why);
      expect(ppm(solves.length, elapsed), c['ppm'], reason: why);
      expect(consistency(solves), c['consistency'], reason: why);
      expect([for (final b in breakdown(solves)) b.toJson()], c['breakdown'], reason: why);
      expect([for (final s in slowest(solves)) solves.indexOf(s)], c['slowest'], reason: why);
      expect([for (final p in paceSeries(solves, elapsed)) p.toJson()], c['paceSeries'], reason: why);
      expect(
        [for (final p in paceSeries(solves, elapsed, windowSeconds: 5)) p.toJson()],
        c['paceSeries5'],
        reason: why,
      );
    }
  });

  test('keeps tied solves in their original order', () {
    final ties = scoring['slowestTies'];
    final solves = [for (final s in ties['solves'] as List) _solve(s)];
    expect([for (final s in slowest(solves, limit: 3)) solves.indexOf(s)], ties['slowest']);
  });

  test('takes the median of any list', () {
    for (final c in scoring['medians'] as List) {
      expect(median([for (final v in c['values'] as List) (v as num).toDouble()]), c['median']);
    }
  });

  test('builds the same configuration keys as web', () {
    for (final c in scoring['configKeys'] as List) {
      expect(configKey(c['config']), c['key']);
    }
  });
}
