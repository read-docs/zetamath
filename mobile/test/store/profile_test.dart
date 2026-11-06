import 'package:flutter_test/flutter_test.dart';
import 'package:zetamath/engine/generator.dart';
import 'package:zetamath/store/difficulty.dart';
import 'package:zetamath/store/history.dart';
import 'package:zetamath/store/profile.dart';

import '../fixtures.dart';

void main() {
  final f = fixture('profile.json');
  final results = [for (final r in f['history'] as List) Result.fromJson(r)];

  test('variation and difficulty per result', () {
    for (final (i, k) in (f['resultKeys'] as List).indexed) {
      expect(variation(results[i]), k['variation']);
      expect(currentDifficulty(results[i].ranges), k['difficulty']);
    }
  });

  test('activity and streaks by local day', () {
    expect([
      for (final e in activityByDay(results).entries.toList()..sort((a, b) => a.key.compareTo(b.key))) [e.key, e.value],
    ], f['activityByDay']);
    for (final s in f['streaks'] as List) {
      final [y, m, d] = (s['today'] as String).split('-').map(int.parse).toList();
      final streak = streaks(results, today: DateTime(y, m, d));
      expect(
        (current: streak.current, longest: streak.longest),
        (current: s['current'], longest: s['longest']),
        reason: s['today'],
      );
    }
  });

  test('summary totals', () {
    expect(summary(results).toJson(), f['summary']);
    expect(summary([]).toJson(), f['emptySummary']);
  });

  test('best result per standard length for the given ranges', () {
    for (final b in f['bests'] as List) {
      final bests = bestsFor(results, b['mode'] == 'time' ? TestMode.time : TestMode.count, [
        ...b['targets'],
      ], RangeConfig.fromJson(b['ranges']));
      expect([
        for (final e in bests.entries) [e.key, e.value.id],
      ], b['bests']);
    }
  });

  test('pace history with trailing averages', () {
    expect([for (final p in profilePaceSeries(results)) p.toJson()], f['paceSeries']);
  });

  test('levels and durations', () {
    for (final l in f['levels'] as List) {
      final solved = l['solved'] as int;
      final input = solved == 0
          ? <Result>[]
          : [results.first.copyWith(logs: List.filled(solved, results.first.logs.first))];
      final got = level(input);
      expect(
        [got.level, got.xp, got.into, got.needed],
        [l['level'], l['xp'], l['into'], l['needed']],
        reason: '$solved solved',
      );
    }
    for (final d in f['durations'] as List) {
      expect(formatDuration((d['ms'] as num).toDouble()), d['text']);
    }
  });

  test('difficulty presets keep operation selection and weights', () {
    final base = defaultRanges.withRange(
      Operation.add,
      defaultRanges[Operation.add].copyWith(enabled: false, weight: 3),
    );
    for (final d in f['difficulties'] as List) {
      final ranges = difficultyRanges(Difficulty.values.byName(d['name']), base);
      expect(ranges.toJson(), d['ranges']);
      expect(currentDifficulty(ranges), d['name']);
    }
    expect(currentDifficulty(base.withRange(Operation.add, base[Operation.add].copyWith(maxA: 99))), 'custom');
  });
}
