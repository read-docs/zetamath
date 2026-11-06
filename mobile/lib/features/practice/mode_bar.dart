import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../store/difficulty.dart';
import '../../store/history.dart';
import '../../store/settings.dart';
import '../../themes/themes.dart';
import '../settings/quick_settings_sheet.dart';
import 'practice_providers.dart';

const modeIcons = {
  TestMode.time: Icons.schedule,
  TestMode.count: Icons.tag,
  TestMode.zen: Icons.self_improvement,
  TestMode.custom: Icons.tune,
};

/// `time · 60s`, `count · 25`, `zen`, `custom · 45s`: what the next test is, in a few characters.
String testSummary(Settings s) => switch (s.mode) {
  TestMode.zen => 'zen',
  TestMode.custom => 'custom · ${s.timed ? '${s.duration}s' : '${s.count}'}',
  _ => '${s.mode.name} · ${s.timed ? '${s.duration}s' : '${s.count}'}',
};

/// One row: a pill that names the current test and opens the test sheet (finish during a zen run),
/// and restart.
/// The pill is locked while a test runs, as the web mode bar is, and fades in focus mode.
/// Restart always stays.
class ModeBar extends ConsumerWidget {
  const ModeBar({super.key, required this.running, required this.focus});
  final bool running, focus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final z = context.zeta;
    final difficulty = difficultyOf(s.ranges)?.name ?? 'custom ranges';
    final practice = ref.read(practiceProvider);
    final zen = running && practice.config.mode == TestMode.zen;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                // Zen has no end of its own, so its run gets a finish button where the locked pill was,
                // well away from restart, which discards the run.
                child: zen
                    ? TextButton.icon(
                        onPressed: practice.finish,
                        icon: Icon(Icons.stop_rounded, color: z.main),
                        label: Text('finish', style: TextStyle(color: z.muted, fontSize: 15)),
                      )
                    : AnimatedOpacity(
                        opacity: running ? (focus ? 0 : .4) : 1,
                        duration: const Duration(milliseconds: 200),
                        child: Tooltip(
                          message: 'test settings',
                          child: Material(
                            color: z.raised,
                            borderRadius: BorderRadius.circular(24),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: running ? null : () => showQuickSettings(context),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(modeIcons[s.mode], size: 18, color: z.main),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: testSummary(s),
                                              style: TextStyle(color: z.text),
                                            ),
                                            TextSpan(
                                              text: '  $difficulty',
                                              style: TextStyle(color: z.muted),
                                            ),
                                          ],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.expand_more, size: 20, color: z.muted),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            IconButton(
              tooltip: 'restart',
              icon: Icon(Icons.refresh, color: z.muted),
              onPressed: () => ref.read(practiceProvider).restart(),
            ),
          ],
        ),
      ),
    );
  }
}
