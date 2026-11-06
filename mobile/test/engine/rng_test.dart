import 'package:flutter_test/flutter_test.dart';
import 'package:zetamath/engine/rng.dart';

import '../fixtures.dart';

void main() {
  test('matches the web Mulberry32 stream for every fixture seed', () {
    for (final c in fixture('problems.json')['rng'] as List) {
      final rng = createRng(c['seed'] as String);
      final values = [for (var i = 0; i < 50; i++) rng()];
      expect(values, c['values'], reason: 'seed "${c['seed']}"');
    }
  });
}
