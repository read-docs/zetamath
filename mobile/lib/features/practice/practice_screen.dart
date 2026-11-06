import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../store/settings.dart';
import '../../themes/themes.dart';
import '../common/widgets.dart';
import '../results/results_view.dart';
import 'keypad.dart';
import 'live_stats.dart';
import 'mode_bar.dart';
import 'practice_controller.dart';
import 'practice_providers.dart';

/// Problem in the upper half, keypad in the lower half. Results replace both when a test ends.
class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key});

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> with SingleTickerProviderStateMixin {
  late final PracticeController _practice = ref.read(practiceProvider);
  late final Ticker _ticker = createTicker((_) => _practice.tick());
  late final AppLifecycleListener _lifecycle;
  var _wasRunning = false;

  @override
  void initState() {
    super.initState();
    _practice.addListener(_syncRunning);
    // Leaving the app ends the test. It is saved, and unfinished runs never count as personal bests.
    _lifecycle = AppLifecycleListener(onPause: _practice.finish);
  }

  void _syncRunning() {
    final running = _practice.running;
    if (running == _wasRunning) return;
    _wasRunning = running;
    running ? _ticker.start() : _ticker.stop();
    ref.read(wakelockProvider)(running);
  }

  @override
  void dispose() {
    _practice.removeListener(_syncRunning);
    _lifecycle.dispose();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clock = ref.read(clockProvider);
    return ListenableBuilder(
      listenable: _practice,
      builder: (context, _) {
        final s = ref.watch(settingsProvider);
        final result = _practice.result;
        return Column(
          children: [
            ModeBar(running: _practice.running, focus: s.focusMode),
            if (result != null)
              Expanded(
                child: ResultsView(result: result, personalBest: _practice.personalBest, error: _practice.error),
              )
            else ...[
              Expanded(
                child: _Stage(practice: _practice, settings: s),
              ),
              SizedBox(
                // ~72 dp keys on the A54, smaller on short screens.
                height: math.min(4 * 72 + 3 * 8, MediaQuery.sizeOf(context).height * .42),
                child: Keypad(
                  layout: s.keypadLayout,
                  enabled: _practice.problem != null,
                  onKey: (key) => _practice.press(key, at: clock()),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({required this.practice, required this.settings});
  final PracticeController practice;
  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final z = context.zeta;
    final config = practice.running ? practice.config : settings;
    final problem = practice.problem;
    final size = settings.size * 16;
    final answer = practice.input;
    final problemText = problem == null ? null : '${problem.a} ${opLabel(problem.op.symbol)} ${problem.b}';
    final operator = TextStyle(color: z.muted);
    // Monospace spaces are a full digit wide. Narrower, even gaps keep the problem reading as one unit.
    final gap = WidgetSpan(child: SizedBox(width: size * .28));

    Widget line(List<InlineSpan> spans) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Text.rich(
        TextSpan(children: spans),
        maxLines: 1,
        textScaler: TextScaler.noScaling,
        style: TextStyle(fontSize: size, color: z.text),
      ),
    );

    final Widget body;
    if (problemText == null) {
      body = Text(
        practice.error ?? 'configure your ranges',
        textAlign: TextAlign.center,
        style: TextStyle(color: z.error),
      );
    } else if (settings.answerStyle == AnswerStyle.inline) {
      body = Semantics(
        label: '$problemText equals ${answer.isEmpty ? 'blank' : answer}',
        excludeSemantics: true,
        child: line([
          TextSpan(text: '${problem!.a}'),
          gap,
          TextSpan(text: opLabel(problem.op.symbol), style: operator),
          gap,
          TextSpan(text: '${problem.b}'),
          gap,
          TextSpan(text: '=', style: operator),
          gap,
          TextSpan(
            text: answer.isEmpty ? ' ' : answer,
            style: TextStyle(color: z.main),
          ),
        ]),
      );
    } else {
      body = Semantics(
        label: '$problemText, answer ${answer.isEmpty ? 'blank' : answer}',
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            line([
              TextSpan(text: '${problem!.a}'),
              gap,
              TextSpan(text: opLabel(problem.op.symbol), style: operator),
              gap,
              TextSpan(text: '${problem.b}'),
            ]),
            const SizedBox(height: 12),
            Container(
              constraints: BoxConstraints(minWidth: size * 3),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: z.main, width: 2)),
              ),
              child: line([
                TextSpan(
                  text: answer.isEmpty ? '?' : answer,
                  style: TextStyle(color: answer.isEmpty ? z.sub : z.main),
                ),
              ]),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          StatusLine(
            elapsed: practice.elapsed,
            config: config,
            running: practice.running,
            score: practice.score,
            showTimer: settings.showTimer,
            showScore: settings.showScore,
            showPace: settings.showPace,
          ),
          Expanded(child: Center(child: body)),
          SizedBox(
            height: 32,
            child: practice.running
                ? null
                : Text('tap a digit to start', style: TextStyle(color: z.muted, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
