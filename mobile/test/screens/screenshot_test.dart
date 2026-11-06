// Renders screens with the real fonts to PNGs for design review. Not part of the suite:
// run with `fvm flutter test test/screens --dart-define=SHOTS=<dir>`.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zetamath/app.dart';
import 'package:zetamath/features/practice/practice_controller.dart';
import 'package:zetamath/features/practice/practice_providers.dart';
import 'package:zetamath/store/history.dart';
import 'package:zetamath/store/history_store.dart';
import 'package:zetamath/store/settings.dart';

import '../widgets/harness.dart';

const out = String.fromEnvironment('SHOTS');

Future<void> loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

Future<void> shot(WidgetTester tester, String name, {bool settle = true}) async {
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    await loadFont('JetBrains Mono', ['assets/fonts/JetBrainsMono.ttf']);
    await loadFont('MaterialIcons', ['.fvm/flutter_sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  });

  testWidgets('screens', (tester) async {
    if (out.isEmpty) return;
    tester.view.physicalSize = const Size(411, 891) * 2.625;
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final clock = FakeClock();
    final container = ProviderContainer(
      overrides: [
        settingsStorageProvider.overrideWithValue(MemorySettingsStorage()),
        historyBackendProvider.overrideWithValue(
          MemoryHistoryBackend(File('../shared/fixtures/history-v1.json').readAsStringSync()),
        ),
        wakelockProvider.overrideWithValue((_) {}),
        clockProvider.overrideWithValue(() => clock.now),
      ],
    );
    addTearDown(container.dispose);
    container.read(settingsProvider.notifier).update((s) => s.copyWith(seed: 'shot', duration: 60));
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: UncontrolledProviderScope(container: container, child: const ZetamathApp()),
      ),
    );
    await shot(tester, '1-idle');

    final p = container.read(practiceProvider);
    p.press(const KeypadKey.digit(1), at: clock.now);
    p.press(KeypadKey.clear, at: clock.now);
    for (var i = 0; i < 7; i++) {
      for (final d in '${p.problem!.answer}'.split('')) {
        clock.now += 900;
        p.press(KeypadKey.digit(int.parse(d)), at: clock.now);
      }
    }
    final a = '${p.problem!.answer}';
    p.press(KeypadKey.digit(int.parse(a[0])), at: clock.now);
    clock.now += 500;
    p.tick();
    await shot(tester, '2-running', settle: false);

    p.restart();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('test settings'));
    await shot(tester, '3-sheet');
    expect(container.read(settingsProvider).mode, TestMode.time);
  });
}
