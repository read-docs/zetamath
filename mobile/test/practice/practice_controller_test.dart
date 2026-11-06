import 'package:flutter_test/flutter_test.dart';
import 'package:zetamath/engine/generator.dart';
import 'package:zetamath/engine/rng.dart';
import 'package:zetamath/features/practice/practice_controller.dart';
import 'package:zetamath/store/history.dart';
import 'package:zetamath/store/settings.dart';

void main() {
  late double now;
  late Settings settings;
  late List<Result> finished;
  late PracticeController c;

  setUp(() {
    now = 1000;
    settings = defaultSettings.copyWith(seed: 'loop');
    finished = [];
    c = PracticeController(
      readSettings: () => settings,
      clock: () => now,
      onFinish: (r) async {
        finished.add(r);
        return false;
      },
    )..restart();
  });

  /// Types the answer to the current problem, one digit every [gapMs].
  void solve({double gapMs = 100}) {
    for (final d in c.problem!.answer.toString().split('')) {
      now += gapMs;
      c.press(KeypadKey.digit(int.parse(d)), at: now);
    }
  }

  test('replays the seeded problem sequence and auto-advances on a correct answer', () {
    final rng = createRng('loop');
    final first = generateProblem(defaultRanges, rng);
    expect(c.problem, first);
    solve();
    expect(c.problem, generateProblem(defaultRanges, rng, previousId: first.id));
    expect(c.score, 1);
    expect(c.input, '');
  });

  test('starts the clock on the first digit and times each solve from the previous one', () {
    expect(c.running, isFalse);
    final firstDigits = c.problem!.answer.toString().length;
    solve(gapMs: 250);
    expect(c.running, isTrue);
    final secondDigits = c.problem!.answer.toString().length;
    solve(gapMs: 400);
    c.finish(at: now);
    final r = finished.single;
    expect(r.logs.map((l) => l.timeMs), [250.0 * (firstDigits - 1), 400.0 * secondDigits]);
    expect(r.elapsedMs, 250.0 * (firstDigits - 1) + 400.0 * secondDigits);
    expect(r.seed, 'loop');
  });

  test('a count test ends on the last answer', () {
    settings = settings.copyWith(mode: TestMode.count, count: 3);
    c.restart();
    for (var i = 0; i < 3; i++) {
      solve();
    }
    expect(c.running, isFalse);
    expect(c.result, same(finished.single));
    expect(finished.single.logs, hasLength(3));
    expect(finished.single.mode, TestMode.count);
  });

  test('a time test ends at exactly its duration, even when the frame comes late', () {
    settings = settings.copyWith(mode: TestMode.time, duration: 15);
    c.restart();
    c.press(KeypadKey.digit(1), at: now);
    final start = now;
    now += 14999;
    c.tick();
    expect(c.running, isTrue);
    expect(c.elapsed.value, 14999);
    now = start + 15016;
    c.tick();
    expect(c.running, isFalse);
    expect(finished.single.elapsedMs, 15000);
  });

  test('a tap after time ran out finishes instead of scoring', () {
    settings = settings.copyWith(mode: TestMode.time, duration: 15);
    c.restart();
    c.press(KeypadKey.digit(1), at: now);
    c.press(KeypadKey.clear, at: now);
    now += 16000;
    solve();
    expect(finished.single.elapsedMs, 15000);
    expect(finished.single.logs, isEmpty);
  });

  test('wrong digits wait for backspace or clear', () {
    final answer = c.problem!.answer.toString();
    final wrong = (int.parse(answer[0]) + 1) % 10;
    c.press(KeypadKey.digit(wrong), at: now);
    c.press(KeypadKey.digit(wrong), at: now);
    expect(c.input, '$wrong$wrong');
    c.press(KeypadKey.backspace, at: now);
    expect(c.input, '$wrong');
    c.press(KeypadKey.clear, at: now);
    expect(c.input, '');
    solve();
    expect(c.score, 1);
  });

  test('a drill cycles through the given problems and is marked as a drill', () {
    final drill = [Problem.make(Operation.add, 2, 3), Problem.make(Operation.multiply, 4, 5)];
    c.restart(drill: drill);
    expect(c.problem, drill[0]);
    solve();
    expect(c.problem, drill[1]);
    solve();
    expect(c.problem, drill[0]);
    c.finish(at: now);
    expect(finished.single.drill, isTrue);
  });

  test('finishing before the first digit saves nothing', () {
    c.finish(at: now);
    expect(finished, isEmpty);
  });

  test('reports invalid ranges instead of a problem', () {
    settings = settings.copyWith(
      ranges: RangeConfig({for (final op in Operation.values) op: defaultRanges[op].copyWith(enabled: false)}),
    );
    c.restart();
    expect(c.problem, isNull);
    expect(c.error, 'Enable at least one operation with a positive weight.');
  });
}
