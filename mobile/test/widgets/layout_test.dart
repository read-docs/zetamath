import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zetamath/engine/generator.dart';
import 'package:zetamath/features/practice/practice_providers.dart';
import 'package:zetamath/store/history_store.dart';
import 'package:zetamath/store/settings.dart';

import 'harness.dart';

/// The A54 at default zoom, the A54 zoomed, the A54 with large text, and a small older phone.
const sizes = <(String, Size, double)>[
  ('A54', Size(411, 891), 1),
  ('A54 zoomed', Size(360, 780), 1),
  ('A54 large text', Size(411, 891), 1.3),
  ('small phone', Size(360, 640), 1),
];

void main() {
  final history = File('../shared/fixtures/history-v1.json').readAsStringSync();

  for (final (name, size, scale) in sizes) {
    testWidgets('every screen fits without overflow: $name', (tester) async {
      final container = await pumpApp(
        tester,
        size: size,
        textScale: scale,
        history: history,
        clock: FakeClock(),
        settings: defaultSettings.copyWith(size: 8),
      );

      // A long problem must shrink onto one line, not wrap or overflow.
      container.read(settingsProvider.notifier).update((s) => s.copyWith(ranges: hugeRanges(s)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (final tab in ['profile', 'settings']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        await tester.fling(find.byType(Scrollable).first, const Offset(0, -3000), 3000);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
      }

      final saved = container.read(historyProvider).results.firstWhere((r) => r.logs.length > 20);
      await tester.tap(find.text('practice'));
      container.read(practiceProvider).show(saved);
      await tester.pumpAndSettle();
      expect(find.text('A little sharper.'), findsOneWidget);
      await tester.fling(find.byType(Scrollable).first, const Offset(0, -3000), 3000);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'results');
    });
  }

  testWidgets('keypad keys are at least 72 dp tall on the A54', (tester) async {
    await pumpApp(tester);
    final key = tester.getSize(find.byKey(const ValueKey('keypad-5')));
    expect(key.height, greaterThanOrEqualTo(72));
    expect(key.width, greaterThanOrEqualTo(110));
  });
}

RangeConfig hugeRanges(Settings s) {
  var r = s.ranges;
  for (final op in Operation.values) {
    r = r.withRange(op, r[op].copyWith(minA: 999990, maxA: 1000000, minB: 999990, maxB: 1000000));
  }
  return r;
}
