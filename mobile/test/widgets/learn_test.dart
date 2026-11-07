import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zetamath/features/learn/lessons.dart';
import 'package:zetamath/engine/generator.dart';
import 'package:zetamath/store/history.dart';
import 'package:zetamath/store/settings.dart';
import 'package:zetamath/features/practice/practice_providers.dart';

import 'harness.dart';

void main() {
  testWidgets('learn topics show worked examples, reveal solutions and return to practice', (tester) async {
    final container = await pumpApp(tester);
    await tester.tap(find.text('learn'));
    await tester.pumpAndSettle();
    expect(container.read(tabProvider), AppTab.learn);

    for (final lesson in lessons) {
      final scrollable = find
          .descendant(of: find.byKey(const PageStorageKey('learn')), matching: find.byType(Scrollable))
          .first;
      await tester.drag(scrollable, const Offset(0, 3000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('${lesson.symbol} ${lesson.title}'));
      await tester.pumpAndSettle();
      final technique = lesson.techniques.first;
      expect(find.text(technique.example), findsOneWidget);
      final reveal = find.text('Show solution').first;
      await Scrollable.ensureVisible(tester.element(reveal), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(reveal);
      await tester.pumpAndSettle();
      expect(find.text(technique.solution), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    final scrollable = find
        .descendant(of: find.byKey(const PageStorageKey('learn')), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.text('Practice division'), 400, scrollable: scrollable);
    await tester.tap(find.text('Practice division'));
    await tester.pumpAndSettle();
    expect(container.read(tabProvider), AppTab.practice);
    expect(container.read(practiceProvider).running, isFalse);
    final settings = container.read(settingsProvider);
    expect(settings.mode, TestMode.zen);
    expect(Operation.values.where((op) => settings.ranges[op].enabled), [Operation.divide]);
  });
}
