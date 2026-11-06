import 'package:flutter/material.dart';

import '../../engine/scoring.dart';
import '../../store/settings.dart';
import '../../themes/themes.dart';

/// Countdown (timed) or elapsed seconds, and the shrinking time bar. Listens to [elapsed] only,
/// so a frame tick repaints just this widget.
class LiveTimer extends StatelessWidget {
  const LiveTimer({super.key, required this.elapsed, required this.config});
  final ValueNotifier<double> elapsed;
  final Settings config;

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
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: config.timed ? 'seconds remaining' : 'seconds elapsed',
                value: '$seconds',
                child: Text('$seconds', style: TextStyle(color: z.main, fontSize: 24)),
              ),
              if (config.timed)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: (1 - ms / (config.duration * 1000)).clamp(0, 1),
                      minHeight: 3,
                      color: z.main,
                      backgroundColor: z.sub.withValues(alpha: .15),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Solved count and pace during a test.
class LiveScore extends StatelessWidget {
  const LiveScore({
    super.key,
    required this.score,
    required this.elapsed,
    required this.showScore,
    required this.showPace,
  });
  final int score;
  final ValueNotifier<double> elapsed;
  final bool showScore, showPace;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(color: context.zeta.sub, fontSize: 18);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showScore)
          Semantics(
            label: '$score solved',
            excludeSemantics: true,
            child: Text('$score', style: style),
          ),
        if (showScore && showPace) const SizedBox(width: 16),
        if (showPace)
          ValueListenableBuilder<double>(
            valueListenable: elapsed,
            builder: (_, ms, _) => Text('${ppm(score, ms).round()} ppm', style: style),
          ),
      ],
    );
  }
}
