import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../store/difficulty.dart';
import '../../store/history.dart';
import '../../store/settings.dart';
import '../../themes/themes.dart';
import '../common/widgets.dart';
import '../practice/practice_providers.dart';

/// The touch stand-in for web's Esc command palette: mode, length, difficulty and theme.
Future<void> showQuickSettings(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => const QuickSettingsSheet(),
);

class QuickSettingsSheet extends ConsumerWidget {
  const QuickSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final update = ref.read(settingsProvider.notifier).update;
    final practice = ref.read(practiceProvider);
    final z = context.zeta;
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(text, style: TextStyle(color: z.sub)),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label('mode'),
            ChoiceChips(
              options: TestMode.values,
              value: s.mode,
              label: (m) => m.name,
              onSelected: (m) => update((s) => s.copyWith(mode: m)),
            ),
            if (s.mode != TestMode.zen) ...[
              label(s.timed ? 'seconds' : 'problems'),
              ChoiceChips(
                options: s.timed ? timeOptions : countOptions,
                value: s.timed ? s.duration : s.count,
                onSelected: (n) => update((s) => s.timed ? s.copyWith(duration: n) : s.copyWith(count: n)),
              ),
            ],
            label('difficulty'),
            ChoiceChips<Difficulty?>(
              options: [...Difficulty.values, if (difficultyOf(s.ranges) == null) null],
              value: difficultyOf(s.ranges),
              label: (d) => d?.name ?? 'custom',
              onSelected: (d) {
                if (d != null) {
                  update((s) => s.copyWith(ranges: difficultyRanges(d, s.ranges)));
                }
              },
            ),
            label('theme'),
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final e in themes.entries)
                    ThemeSwatch(
                      name: e.key,
                      theme: e.value,
                      selected: s.theme == e.key,
                      onTap: () => update((s) => s.copyWith(theme: e.key)),
                    ),
                ],
              ),
            ),
            if (practice.running) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  practice.finish();
                  Navigator.pop(context);
                },
                child: const Text('finish test'),
              ),
              Text('the test timer keeps running while this is open', style: TextStyle(color: z.sub, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

/// A theme preview: its name in its accent colour on its background, with three colour dots.
class ThemeSwatch extends StatelessWidget {
  const ThemeSwatch({
    super.key,
    required this.name,
    required this.theme,
    required this.selected,
    required this.onTap,
    this.width = 112,
  });
  final String name;
  final ZetaTheme theme;
  final bool selected;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Semantics(
      selected: selected,
      button: true,
      label: '$name theme',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: theme.bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? theme.main : theme.sub.withValues(alpha: .3), width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.main, fontSize: 13),
                ),
              ),
              for (final c in [theme.main, theme.sub, theme.text])
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(left: 2),
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
