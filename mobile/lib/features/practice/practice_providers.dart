import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../store/history_store.dart';
import '../../store/settings.dart';
import 'practice_controller.dart';

/// Monotonic milliseconds. A [Stopwatch], never wall-clock time, so solve times can't jump.
final clockProvider = Provider<double Function()>((ref) {
  final watch = Stopwatch()..start();
  return () => watch.elapsedMicroseconds / 1000;
});

/// Keeps the screen on during a test. Overridden in widget tests, which have no platform plugins.
final wakelockProvider = Provider<void Function(bool)>(
  (ref) =>
      (on) => WakelockPlus.toggle(enable: on).catchError((_) {}),
);

/// The one practice session, shared by the practice tab, the profile (to open a past result)
/// and the shell (to end a test when leaving the tab).
final practiceProvider = Provider<PracticeController>((ref) {
  final c = PracticeController(
    readSettings: () => ref.read(settingsProvider),
    clock: ref.read(clockProvider),
    onFinish: (r) => ref.read(historyProvider.notifier).add(r),
    onSolve: () {
      if (ref.read(settingsProvider).haptics) HapticFeedback.lightImpact();
    },
  );
  ref.listen(settingsProvider, (previous, next) {
    if (previous != null && next.changesTest(previous)) {
      c.finish();
      c.restart();
    }
  });
  ref.onDispose(c.dispose);
  c.restart();
  return c;
});

enum AppTab { practice, profile, settings }

final tabProvider = NotifierProvider<TabNotifier, AppTab>(TabNotifier.new);

class TabNotifier extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.practice;

  /// Leaving practice ends a running test, as navigating away does on web.
  void go(AppTab tab) {
    if (tab != AppTab.practice) ref.read(practiceProvider).finish();
    state = tab;
  }
}
