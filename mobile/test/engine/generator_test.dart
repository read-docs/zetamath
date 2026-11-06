import 'package:flutter_test/flutter_test.dart';
import 'package:zetamath/engine/generator.dart';
import 'package:zetamath/engine/rng.dart';

import '../fixtures.dart';

void main() {
  final problems = fixture('problems.json');

  test('generates the same 200 problems as web for every seed and range setup', () {
    for (final run in problems['runs'] as List) {
      final ranges = RangeConfig.fromJson(run['ranges']);
      final rng = createRng(run['seed'] as String);
      Problem? previous;
      final generated = [
        for (var i = 0; i < 200; i++) previous = generateProblem(ranges, rng, previousId: previous?.id),
      ];
      expect([for (final p in generated) p.toJson()], run['problems'], reason: '${run['name']} / "${run['seed']}"');
    }
  });

  test('falls back deterministically on tiny domains and rejects a single-problem domain', () {
    final fallback = problems['fallback'];
    expect(
      generateProblem(RangeConfig.fromJson(fallback['ranges']), () => 0.0, previousId: fallback['previous']).toJson(),
      fallback['expected'],
    );
    final single = problems['singleProblem'];
    expect(
      () => generateProblem(RangeConfig.fromJson(single['ranges']), () => 0.5, previousId: single['previous']),
      throwsA(isA<RangeConfigError>().having((e) => e.message, 'message', single['error'])),
    );
  });

  test('reports the same validation errors as web', () {
    for (final c in problems['validation'] as List) {
      String? error;
      try {
        error = validateRanges(RangeConfig.fromJson(c['ranges']));
      } on RangeConfigError catch (e) {
        error = e.message;
      }
      expect(error, c['error'], reason: '${c['ranges']}');
    }
  });

  test('round trips range JSON in the web shape', () {
    final run = (problems['runs'] as List).firstWhere((r) => r['name'] == 'fractionalWeights');
    expect(RangeConfig.fromJson(run['ranges']).toJson(), run['ranges']);
    expect(defaultRanges.toJson(), (problems['runs'] as List).first['ranges']);
  });
}
