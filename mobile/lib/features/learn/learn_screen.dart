import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../themes/themes.dart';
import '../practice/practice_providers.dart';
import 'lessons.dart';

/// Lessons are bundled, so examples and solutions are available offline.
class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({super.key});

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  var _topic = 0;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lesson = lessons[_topic];
    return ListView(
      key: const PageStorageKey('learn'),
      controller: _scroll,
      padding: const EdgeInsets.all(20),
      children: [
        Text('Make the numbers easier.', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        const Text(
          'Learn a shortcut, work through an example, then try it yourself. Accuracy first; speed comes with practice.',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < lessons.length; i++)
              ChoiceChip(
                label: Text('${lessons[i].symbol} ${lessons[i].title}'),
                selected: _topic == i,
                onSelected: (_) {
                  setState(() => _topic = i);
                  _scroll.jumpTo(0);
                },
              ),
          ],
        ),
        const SizedBox(height: 20),
        Semantics(header: true, child: Text(lesson.title, style: Theme.of(context).textTheme.titleLarge)),
        Text(lesson.intro),
        const SizedBox(height: 16),
        for (final technique in lesson.techniques) _TechniqueCard(key: ValueKey(technique.title), technique: technique),
        const SizedBox(height: 12),
        Text('Turn a technique into a habit.', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Try a few problems slowly. Say the intermediate steps in your head. Check division by multiplying back, and subtraction by adding back.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start practicing'),
          onPressed: () {
            ref.read(practiceProvider).restart();
            ref.read(tabProvider.notifier).go(AppTab.practice);
          },
        ),
        const SizedBox(height: 12),
        const Text(
          'Further reading is linked on each card. Explanations and worked examples are written for Zetamath.',
        ),
      ],
    );
  }
}

class _TechniqueCard extends StatelessWidget {
  const _TechniqueCard({super.key, required this.technique});
  final Technique technique;

  Future<void> _openSource(BuildContext context) async {
    try {
      if (await launchUrl(Uri.parse(technique.sourceUrl), mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Surface unavailable browsers and platform failures without losing the lesson.
    }
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Could not open source'),
        content: SelectableText(technique.sourceUrl),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final z = context.zeta;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text(technique.title, style: Theme.of(context).textTheme.titleMedium)),
            const SizedBox(height: 8),
            Text(technique.when, style: TextStyle(color: z.sub)),
            const SizedBox(height: 8),
            Text(technique.tip),
            const SizedBox(height: 16),
            Text(technique.example, style: TextStyle(fontSize: 24, color: z.main)),
            for (var i = 0; i < technique.steps.length; i++)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text('${i + 1}. ${technique.steps[i]}')),
            const SizedBox(height: 20),
            Text('Try it mentally: ${technique.question}'),
            ExpansionTile(
              key: PageStorageKey(technique.title),
              tilePadding: EdgeInsets.zero,
              title: const Text('Show solution'),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Align(alignment: Alignment.centerLeft, child: Text(technique.solution)),
                ),
              ],
            ),
            TextButton(onPressed: () => _openSource(context), child: Text('${technique.sourceLabel} ↗')),
          ],
        ),
      ),
    );
  }
}
