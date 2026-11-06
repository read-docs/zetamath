import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/scoring.dart';
import '../../store/history.dart';
import '../../themes/themes.dart';
import '../common/widgets.dart';
import '../practice/practice_providers.dart';
import 'pace_chart.dart';

/// Stats for a finished test, shown in place of the test as on web.
class ResultsView extends ConsumerWidget {
  const ResultsView({super.key, required this.result, required this.personalBest, this.error});
  final Result result;
  final bool personalBest;
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final z = context.zeta;
    final r = result;
    final solves = r.logs;
    final worst = slowest(solves);
    String seconds(double ms) => (ms / 1000).toStringAsFixed(2);

    // Try again stays pinned under the thumb; the stats scroll above it.
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              Text('A little sharper.', style: TextStyle(color: z.text, fontSize: 24)),
              if (personalBest)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('✦ new personal best', style: TextStyle(color: z.main)),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(error!, style: TextStyle(color: z.error)),
                ),
              const SizedBox(height: 16),
              Wrap(
                runSpacing: 12,
                children: [
                  for (final tile in [
                    StatTile(label: 'solved', value: '${solves.length}'),
                    StatTile(label: 'pace', value: '${r.pace.round()} ppm'),
                    StatTile(label: 'time', value: '${seconds(r.elapsedMs)}s'),
                    StatTile(
                      label: 'variation',
                      value: '${consistency(solves).toStringAsFixed(1)}%',
                      note: 'lower is more consistent',
                    ),
                  ])
                    FractionallySizedBox(widthFactor: .5, child: tile),
                ],
              ),
              const SizedBox(height: 8),
              PaceChart(points: paceSeries(solves, r.elapsedMs)),
              const SizedBox(height: 16),
              Panel(
                title: 'by operation',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final b in breakdown(solves))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${opLabel(b.op.symbol)} · ${b.count} solved · avg ${b.count > 0 ? seconds(b.averageMs) : '—'}s · median ${b.count > 0 ? seconds(b.medianMs) : '—'}s',
                          style: TextStyle(color: b.count > 0 ? z.text : z.sub, fontSize: 14),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Panel(
                title: 'slowest problems',
                child: Column(
                  children: [
                    for (final (i, s) in worst.indexed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              child: Text('${i + 1}.', style: TextStyle(color: z.sub)),
                            ),
                            Expanded(
                              child: Text(
                                '${s.problem.a} ${opLabel(s.op.symbol)} ${s.problem.b} = ${s.problem.answer}',
                                style: TextStyle(color: z.text),
                              ),
                            ),
                            Text('${seconds(s.timeMs)}s', style: TextStyle(color: z.sub)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton(
                        onPressed: worst.isEmpty
                            ? null
                            : () => ref.read(practiceProvider).restart(drill: [for (final s in worst) s.problem]),
                        child: const Text('drill these'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => ref.read(practiceProvider).restart(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('try again'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => ref.read(tabProvider.notifier).go(AppTab.profile),
                  child: const Text('view profile'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
