import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../store/history.dart';
import '../../store/settings.dart';
import '../../themes/themes.dart';
import '../common/widgets.dart';
import '../settings/quick_settings_sheet.dart';
import 'practice_providers.dart';

const modeIcons = {
  TestMode.time: Icons.schedule,
  TestMode.count: Icons.tag,
  TestMode.zen: Icons.landscape_outlined,
  TestMode.custom: Icons.build_outlined,
};

/// Mode chips, then the lengths for that mode, then quick settings and restart.
/// The chips are locked while a test runs, as on web, and fade out in focus mode.
/// Restart and quick settings stay reachable throughout.
class ModeBar extends ConsumerWidget {
  const ModeBar({super.key, required this.running, required this.focus});
  final bool running, focus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final update = ref.read(settingsProvider.notifier).update;
    final z = context.zeta;

    Widget chip(String label, bool selected, VoidCallback onTap, {IconData? icon, String? tooltip}) => Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ChoiceChip(
        avatar: icon == null ? null : Icon(icon, size: 16, color: selected ? z.main : z.sub),
        label: Text(label),
        tooltip: tooltip,
        selected: selected,
        labelStyle: TextStyle(color: selected ? z.main : z.sub),
        onSelected: running ? null : (_) => onTap(),
      ),
    );

    Future<void> askLength(bool timed) async {
      final n = await askNumber(
        context,
        title: timed ? 'test length in seconds' : 'number of problems',
        initial: timed ? s.duration : s.count,
      );
      if (n != null) {
        update((s) => timed ? s.copyWith(duration: n.toInt()) : s.copyWith(count: n.toInt()));
      }
    }

    final lengths = <Widget>[];
    if (s.mode == TestMode.time || s.mode == TestMode.count) {
      final timed = s.mode == TestMode.time,
          values = timed ? timeOptions : countOptions,
          current = timed ? s.duration : s.count;
      for (final n in values) {
        lengths.add(
          chip('$n', current == n, () => update((s) => timed ? s.copyWith(duration: n) : s.copyWith(count: n))),
        );
      }
      final preset = values.contains(current);
      lengths.add(
        chip(
          preset ? '…' : '$current',
          !preset,
          () => askLength(timed),
          tooltip: timed ? 'custom duration' : 'custom count',
        ),
      );
    } else if (s.mode == TestMode.custom) {
      for (final kind in CustomKind.values) {
        lengths.add(chip(kind.name, s.customKind == kind, () => update((s) => s.copyWith(customKind: kind))));
      }
      final timed = s.customKind == CustomKind.time;
      lengths.add(
        chip(
          timed ? '${s.duration}s' : '${s.count}',
          false,
          () => askLength(timed),
          tooltip: timed ? 'set duration' : 'set count',
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: AnimatedOpacity(
              opacity: running && focus ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final m in TestMode.values)
                          chip(m.name, s.mode == m, () => update((s) => s.copyWith(mode: m)), icon: modeIcons[m]),
                      ],
                    ),
                  ),
                  if (lengths.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: lengths),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'quick settings',
            icon: Icon(Icons.tune, color: z.sub),
            onPressed: () => showQuickSettings(context),
          ),
          IconButton(
            tooltip: 'restart',
            icon: Icon(Icons.refresh, color: z.sub),
            onPressed: () => ref.read(practiceProvider).restart(),
          ),
        ],
      ),
    );
  }
}
