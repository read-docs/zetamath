import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zetamath/app.dart';
import 'package:zetamath/features/practice/practice_providers.dart';
import 'package:zetamath/store/history_store.dart';
import 'package:zetamath/store/settings.dart';

class MemorySettingsStorage implements SettingsStorage {
  MemorySettingsStorage([this.value]);
  String? value;
  @override
  String? read() => value;
  @override
  Future<void> write(String v) async => value = v;
}

class MemoryHistoryBackend implements HistoryBackend {
  MemoryHistoryBackend([this.value]);
  String? value;
  @override
  Future<String?> load() async => value;
  @override
  Future<void> save(String json) async => value = json;
}

class FakeClock {
  double now = 0;
}

/// Pumps the whole app with in-memory storage, a hand-driven clock and no platform plugins.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  Settings? settings,
  String? history,
  FakeClock? clock,
  Size size = const Size(411, 891),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size * 2.625;
  tester.view.devicePixelRatio = 2.625;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final storage = MemorySettingsStorage();
  final container = ProviderContainer(
    overrides: [
      settingsStorageProvider.overrideWithValue(storage),
      historyBackendProvider.overrideWithValue(MemoryHistoryBackend(history)),
      wakelockProvider.overrideWithValue((_) {}),
      if (clock != null) clockProvider.overrideWithValue(() => clock.now),
    ],
  );
  addTearDown(container.dispose);
  if (settings != null) {
    container.read(settingsProvider.notifier).update((_) => settings);
  }
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const ZetamathApp()));
  await tester.pumpAndSettle();
  return container;
}
