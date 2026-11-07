import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../engine/generator.dart';
import '../../engine/rng.dart';
import '../../engine/scoring.dart';
import '../../store/history.dart';
import '../../store/settings.dart';

/// A key on the in-app keypad.
sealed class KeypadKey {
  const KeypadKey();
  const factory KeypadKey.digit(int value) = DigitKey;
  static const backspace = BackspaceKey();
  static const clear = ClearKey();
}

class DigitKey extends KeypadKey {
  const DigitKey(this.value);
  final int value;
}

class BackspaceKey extends KeypadKey {
  const BackspaceKey();
}

class ClearKey extends KeypadKey {
  const ClearKey();
}

/// Longest answer the keypad accepts: 1,000,000 × 1,000,000 has 13 digits.
const _maxDigits = 13;

/// The practice loop from web `App.tsx`, without widgets: problems, typed input, timing and the
/// finished [Result]. Times are monotonic milliseconds from [clock], passed in with each key press
/// so a solve is timed from the finger landing, not lifting.
class PracticeController extends ChangeNotifier {
  PracticeController({required this.readSettings, required this.clock, required this.onFinish, this.onSolve});

  final Settings Function() readSettings;
  final double Function() clock;

  /// Saves the result and reports whether it is a personal best.
  final Future<bool> Function(Result) onFinish;

  /// Called on each correct answer, for haptic feedback.
  final void Function()? onSolve;

  /// Settings for the current test, fixed when it starts so mid-test edits don't change it.
  late Settings config = readSettings();
  Problem? problem;
  Problem? _prepared;
  String input = '';
  Result? result;
  bool personalBest = false;
  String? error;

  /// Milliseconds since the first problem was revealed. Separate from [notifyListeners] so the timer can
  /// repaint every frame without rebuilding the screen.
  final elapsed = ValueNotifier<double>(0);

  double? _start;
  double _last = 0;
  final _logs = <Solve>[];
  List<Problem>? _drill;
  var _drillIndex = 0;
  late String _seed;
  late double Function() _rng;

  bool get running => _start != null;
  bool get ready => _prepared != null && !running && result == null;
  int get score => _logs.length;

  void restart({List<Problem>? drill}) {
    _start = null;
    elapsed.value = 0;
    _logs.clear();
    input = '';
    result = null;
    personalBest = false;
    error = null;
    config = readSettings();
    _drill = drill;
    _drillIndex = 0;
    _seed = config.seed.isNotEmpty ? config.seed : const Uuid().v4();
    _rng = createRng(_seed);
    problem = null;
    _prepared = null;
    try {
      _next();
      _prepared = problem;
      problem = null;
    } on RangeConfigError catch (e) {
      error = e.message;
    }
    notifyListeners();
  }

  /// Reveals the first problem at the same instant its solve time begins.
  void begin() {
    if (!ready) return;
    problem = _prepared;
    _prepared = null;
    _start = clock();
    _last = _start!;
    notifyListeners();
  }

  /// Shows a saved result in place of the test, as opening one from the profile does on web.
  void show(Result saved) {
    _start = null;
    result = saved;
    personalBest = false;
    elapsed.value = saved.elapsedMs;
    notifyListeners();
  }

  void _next() {
    final drill = _drill;
    problem = drill != null
        ? drill[_drillIndex++ % drill.length]
        : generateProblem(config.ranges, _rng, previousId: problem?.id);
  }

  void press(KeypadKey key, {required double at}) {
    if (!running || problem == null || result != null) return;
    switch (key) {
      case DigitKey(:final value):
        if (input.length < _maxDigits) input += '$value';
      case BackspaceKey():
        if (input.isNotEmpty) input = input.substring(0, input.length - 1);
      case ClearKey():
        input = '';
    }
    final start = _start;
    if (start == null) return notifyListeners();
    if (_endIfTimeUp(start, at)) return;
    if (int.tryParse(input) == problem!.answer) {
      _logs.add(Solve(problem: problem!, timeMs: at - _last));
      _last = at;
      input = '';
      onSolve?.call();
      if (config.counted && _logs.length >= config.count) return finish(at: at);
      try {
        _next();
      } on RangeConfigError catch (e) {
        error = e.message;
        return finish(at: at);
      }
    }
    notifyListeners();
  }

  /// Called every frame while running. Ends a timed test at exactly its duration.
  void tick() {
    final start = _start;
    if (start == null) return;
    final now = clock();
    if (!_endIfTimeUp(start, now)) elapsed.value = now - start;
  }

  /// Finishes a timed test whose time has run out, recording exactly its duration, as web does.
  bool _endIfTimeUp(double start, double now) {
    final limit = config.duration * 1000;
    if (!config.timed || now - start < limit) return false;
    finish(at: start + limit);
    return true;
  }

  /// Ends the test and saves it. Does nothing before begin.
  void finish({double? at}) {
    final start = _start;
    if (start == null) return;
    final ms = ((at ?? clock()) - start)
        .clamp(0.0, config.timed ? config.duration * 1000.0 : double.infinity)
        .toDouble();
    _start = null;
    elapsed.value = ms;
    final r = Result(
      id: const Uuid().v4(),
      date: isoDate(DateTime.now()),
      mode: config.mode,
      duration: config.duration,
      count: config.count,
      customKind: config.customKind,
      ranges: config.ranges,
      seed: _seed,
      elapsedMs: ms,
      logs: List.of(_logs),
      drill: _drill != null,
    );
    result = r;
    notifyListeners();
    onFinish(r).then(
      (pb) {
        if (result == r && pb) {
          personalBest = true;
          notifyListeners();
        }
      },
      onError: (Object e) {
        error = '$e';
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    elapsed.dispose();
    super.dispose();
  }
}
