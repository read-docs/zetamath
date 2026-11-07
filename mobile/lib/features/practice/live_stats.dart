import 'package:flutter/material.dart';

import '../../engine/scoring.dart';
import '../../store/history.dart';
import '../../store/settings.dart';
import '../../themes/themes.dart';

/// The scoreboard line over the problem: time on the left, solved and pace on the right,
/// and the time bar under both. Listens to [elapsed] directly so a frame tick repaints only this.
class StatusLine extends StatelessWidget {
  const StatusLine({
    super.key,
    required this.elapsed,
    required this.config,
    required this.running,
    required this.score,
    required this.showTimer,
    required this.showScore,
    required this.showPace,
  });
  final ValueNotifier<double> elapsed;
  final Settings config;
  final bool running, showTimer, showScore, showPace;
  final int score;

  @override
  Widget build(BuildContext context) {
    final z = context.zeta;
    return RepaintBoundary(
      child: ValueListenableBuilder<double>(
        valueListenable: elapsed,
        builder: (context, ms, _) {
          final seconds = config.timed
              ? (config.duration - ms / 1000).clamp(0, double.infinity).ceil()
              : (ms / 1000).floor();
          final big = TextStyle(
            fontSize: 28,
            height: 1,
            color: running ? z.main : z.muted,
            fontWeight: FontWeight.w700,
          );
          final small = TextStyle(fontSize: 13, color: z.muted);
          return Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (showTimer && config.mode != TestMode.zen || showTimer && running)
                      Semantics(
                        label: config.timed ? 'seconds remaining' : 'seconds elapsed',
                        value: '$seconds',
                        excludeSemantics: true,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: '$seconds', style: big),
                              TextSpan(text: config.timed ? ' s left' : ' s', style: small),
                            ],
                          ),
                        ),
                      ),
                    if (running && showPace) Text('${ppm(score, ms).round()} ppm   ', style: small),
                    if (running && showScore)
                      Semantics(
                        label: '$score solved',
                        excludeSemantics: true,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '$score',
                                style: big.copyWith(color: z.text),
                              ),
                              TextSpan(text: config.counted ? ' / ${config.count}' : ' solved', style: small),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (showTimer && (config.timed || config.counted))
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: config.timed
                        ? (1 - ms / (config.duration * 1000)).clamp(0, 1)
                        : (score / config.count).clamp(0, 1),
                    minHeight: 4,
                    color: running ? z.main : z.muted.withValues(alpha: .35),
                    backgroundColor: z.raised,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
