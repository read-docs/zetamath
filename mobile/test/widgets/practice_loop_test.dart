import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zetamath/engine/generator.dart';
import 'package:zetamath/engine/rng.dart';
import 'package:zetamath/features/practice/practice_providers.dart';
import 'package:zetamath/store/history.dart';
import 'package:zetamath/store/history_store.dart';
import 'package:zetamath/store/settings.dart';

import 'harness.dart';

void main() {
  testWidgets('tapping answers auto-advances, ends the count test and saves the result', (tester) async {
    final clock = FakeClock();
    final container = await pumpApp(
      tester,
      clock: clock,
      settings: defaultSettings.copyWith(mode: TestMode.count, count: 3, seed: 'widget'),
    );
    await tester.tap(find.text('Start practice'));
    await tester.pump();
    final rng = createRng('widget');
    Problem? previous;
    for (var i = 0; i < 3; i++) {
      final problem = previous = generateProblem(defaultRanges, rng, previousId: previous?.id);
      final shown = '${problem.a} ${problem.op == Operation.subtract ? '−' : problem.op.symbol} ${problem.b}';
      expect(find.bySemanticsLabel(RegExp('^${RegExp.escape(shown)} equals')), findsOneWidget);
      for (final d in '${problem.answer}'.split('')) {
        clock.now += 300;
        await tester.tap(find.byKey(ValueKey('keypad-$d')));
        await tester.pump();
      }
    }
    await tester.pumpAndSettle();
    expect(find.text('A little sharper.'), findsOneWidget);
    final saved = container.read(historyProvider).results.single;
    expect(saved.logs, hasLength(3));
    expect(saved.seed, 'widget');
    expect(find.text('✦ new personal best'), findsOneWidget);

    await tester.tap(find.text('try again'));
    await tester.pumpAndSettle();
    expect(find.text('start when you are ready'), findsOneWidget);
  });

  testWidgets('a timed test counts down on the ticker and ends by itself', (tester) async {
    final clock = FakeClock();
    final container = await pumpApp(
      tester,
      clock: clock,
      settings: defaultSettings.copyWith(mode: TestMode.time, duration: 15, seed: 'widget'),
    );
    expect(find.text('15 s left', findRichText: true), findsOneWidget);
    await tester.tap(find.text('Start practice'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('keypad-1')));
    clock.now += 4200;
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('11 s left', findRichText: true), findsOneWidget);
    clock.now += 11000;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pumpAndSettle();
    expect(find.text('A little sharper.'), findsOneWidget);
    expect(container.read(historyProvider).results.single.elapsedMs, 15000);
  });

  testWidgets('leaving the practice tab ends a running test', (tester) async {
    final container = await pumpApp(
      tester,
      clock: FakeClock(),
      settings: defaultSettings.copyWith(focusMode: false, seed: 'widget'),
    );
    await tester.tap(find.text('Start practice'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('keypad-1')));
    await tester.pump();
    expect(container.read(practiceProvider).running, isTrue);
    await tester.tap(find.text('profile'));
    await tester.pumpAndSettle();
    expect(container.read(practiceProvider).running, isFalse);
    expect(container.read(historyProvider).results, hasLength(1));
  });

  testWidgets('back ends a running zen test in focus mode, then leaves other tabs for practice', (tester) async {
    final container = await pumpApp(
      tester,
      clock: FakeClock(),
      settings: defaultSettings.copyWith(mode: TestMode.zen, focusMode: true, seed: 'widget'),
    );
    await tester.tap(find.text('Start practice'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('keypad-1')));
    await tester.pump();
    expect(container.read(practiceProvider).running, isTrue);
    expect(find.text('profile'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(container.read(practiceProvider).running, isFalse);
    expect(container.read(historyProvider).results.single.mode, TestMode.zen);
    expect(find.text('profile'), findsOneWidget);

    await tester.tap(find.text('profile'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(container.read(tabProvider), AppTab.practice);
  });

  testWidgets('finish ends and saves a zen run, and only shows while one runs', (tester) async {
    final container = await pumpApp(
      tester,
      clock: FakeClock(),
      settings: defaultSettings.copyWith(mode: TestMode.zen, focusMode: true, seed: 'widget'),
    );
    expect(find.text('finish'), findsNothing);
    await tester.tap(find.text('Start practice'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('keypad-1')));
    await tester.pump();
    await tester.tap(find.text('finish'));
    await tester.pumpAndSettle();
    expect(container.read(practiceProvider).running, isFalse);
    expect(container.read(historyProvider).results.single.mode, TestMode.zen);
    expect(find.text('finish'), findsNothing);
  });

  testWidgets('quick settings switch the mode and restart the test', (tester) async {
    final container = await pumpApp(tester);
    await tester.tap(find.byTooltip('test settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('zen').last);
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).mode, TestMode.zen);
    expect(container.read(practiceProvider).config.mode, TestMode.zen);
  });

  testWidgets('mid-test the test settings are locked but restart still works, even in focus mode', (tester) async {
    final container = await pumpApp(
      tester,
      clock: FakeClock(),
      settings: defaultSettings.copyWith(seed: 'widget'),
    );
    await tester.tap(find.text('Start practice'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('keypad-1')));
    await tester.pump();
    expect(find.byTooltip('test settings'), findsNothing);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('difficulty'), findsNothing);
    expect(container.read(settingsProvider).mode, TestMode.time);
    expect(container.read(practiceProvider).running, isTrue);
    await tester.tap(find.byTooltip('restart and discard this run'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Discard and restart'));
    await tester.pump();
    expect(container.read(practiceProvider).running, isFalse);
    expect(container.read(historyProvider).results, isEmpty);
  });
}
