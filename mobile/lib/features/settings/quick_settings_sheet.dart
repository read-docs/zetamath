import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../store/difficulty.dart';
import '../../store/history.dart';
import '../../store/settings.dart';
import '../../themes/themes.dart';
import '../common/segmented.dart';
import '../common/widgets.dart';
import '../practice/mode_bar.dart';
import '../practice/practice_providers.dart';

/// The touch stand-in for web's Esc command palette: what kind of test, how long, how hard, and the theme.
Future<void> showQuickSettings(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => const QuickSettingsSheet(),
);

const _modeHints = {
  TestMode.time: 'Solve as many as you can before the clock runs out.',
  TestMode.count: 'Solve a set number of problems as fast as you can.',
  TestMode.zen: 'No clock and no target. Finish whenever you like.',
  TestMode.custom: 'Pick your own time limit or problem count.',
};

class QuickSettingsSheet extends ConsumerWidget {
  const QuickSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final update = ref.read(settingsProvider.notifier).update;
    final practice = ref.read(practiceProvider);
    final z = context.zeta;
    final difficulty = difficultyOf(s.ranges);

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(text, style: TextStyle(color: z.muted, fontSize: 13, letterSpacing: .5)),
    );

    Future<void> askLength() async {
      final n = await askNumber(
        context,
        title: s.timed ? 'seconds' : 'problems',
        initial: s.timed ? s.duration : s.count,
      );
      if (n != null) update((s) => s.timed ? s.copyWith(duration: n.toInt()) : s.copyWith(count: n.toInt()));
    }

    // Length presets plus a last segment for any other value, which shows that value once set.
    Widget lengths() {
      final presets = s.timed ? timeOptions : countOptions;
      final current = s.timed ? s.duration : s.count;
      final unit = s.timed ? 's' : '';
      final custom = presets.contains(current) ? null : current;
      return Segmented<int?>(
        options: [...presets, custom],
        value: custom ?? current,
        label: (n) => n == null ? 'other' : '$n$unit',
        onSelected: (n) {
          if (n == null || n == custom) {
            askLength();
            return;
          }
          update((s) => s.timed ? s.copyWith(duration: n) : s.copyWith(count: n));
        },
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'test',
              style: TextStyle(color: z.text, fontSize: 22, fontWeight: FontWeight.w700),
            ),
            heading('mode'),
            Segmented(
              options: TestMode.values,
              value: s.mode,
              label: (m) => m.name,
              icon: (m) => modeIcons[m]!,
              height: 64,
              onSelected: (m) => update((s) => s.copyWith(mode: m)),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_modeHints[s.mode]!, style: TextStyle(color: z.muted, fontSize: 13)),
            ),
            if (s.mode == TestMode.custom) ...[
              heading('ends after'),
              Segmented(
                options: CustomKind.values,
                value: s.customKind,
                label: (k) => k == CustomKind.time ? 'a time limit' : 'a problem count',
                onSelected: (k) => update((s) => s.copyWith(customKind: k)),
              ),
            ],
            if (s.mode != TestMode.zen) ...[heading(s.timed ? 'length' : 'problems'), lengths()],
            heading('difficulty'),
            Segmented<Difficulty>(
              options: Difficulty.values,
              value: difficulty,
              label: (d) => d.name,
              onSelected: (d) => update((s) => s.copyWith(ranges: difficultyRanges(d, s.ranges))),
            ),
            if (difficulty == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Your ranges are custom. Edit them under settings, or pick a preset.',
                  style: TextStyle(color: z.muted, fontSize: 13),
                ),
              ),
            heading('theme'),
            SizedBox(
              height: 44,
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
            const SizedBox(height: 24),
            if (practice.running)
              OutlinedButton(
                onPressed: () {
                  practice.finish();
                  Navigator.pop(context);
                },
                child: const Text('finish test'),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('done')),
              ),
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
