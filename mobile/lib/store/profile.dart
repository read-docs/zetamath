import 'dart:math' as math;

import 'package:collection/collection.dart';

import '../engine/generator.dart';
import 'history.dart';
import 'settings.dart';

String dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
double _mean(Iterable<double> xs) => xs.isEmpty ? 0 : xs.sum / xs.length;
DateTime _local(String iso) => DateTime.parse(iso).toLocal();

/// Coefficient of variation of solve times, in percent. Lower is steadier.
double variation(Result r) {
  final times = [for (final l in r.logs) l.timeMs], m = _mean(times);
  return m != 0 ? math.sqrt(_mean(times.map((t) => math.pow(t - m, 2).toDouble()))) / m * 100 : 0;
}

/// Tests per local calendar day, in first-seen order.
Map<String, int> activityByDay(Iterable<Result> results) {
  final days = <String, int>{};
  for (final r in results) {
    final k = dayKey(_local(r.date));
    days[k] = (days[k] ?? 0) + 1;
  }
  return days;
}

/// The current streak counts back from today, or from yesterday if nothing has been done today yet.
({int current, int longest}) streaks(Iterable<Result> results, {DateTime? today}) {
  final now = today ?? DateTime.now();
  final days = activityByDay(results);
  var current = 0;
  for (
    var d = days.containsKey(dayKey(now)) ? now : _addDays(now, -1);
    days.containsKey(dayKey(d));
    d = _addDays(d, -1)
  ) {
    current++;
  }
  var longest = 0, run = 0;
  DateTime? previous;
  for (final k in days.keys.toList()..sort()) {
    final [y, m, dd] = k.split('-').map(int.parse).toList();
    final d = DateTime(y, m, dd);
    run = previous != null && dayKey(_addDays(previous, 1)) == k ? run + 1 : 1;
    longest = math.max(longest, run);
    previous = d;
  }
  return (current: current, longest: longest);
}

class Summary {
  const Summary({
    required this.tests,
    required this.solved,
    required this.timeMs,
    required this.joined,
    required this.highestPace,
    required this.averagePace,
    required this.last10Pace,
    required this.averageVariation,
  });
  final int tests, solved;
  final double timeMs, highestPace, averagePace, last10Pace, averageVariation;
  final String? joined;

  Map<String, Object?> toJson() => {
    'tests': tests,
    'solved': solved,
    'timeMs': timeMs,
    'joined': joined,
    'highestPace': highestPace,
    'averagePace': averagePace,
    'last10Pace': last10Pace,
    'averageVariation': averageVariation,
  };
}

/// Comparable mode, goal and ranges for the selected settings.
bool matchesSettings(Result r, Settings? settings) =>
    settings == null ||
    (r.mode == settings.mode &&
        (r.mode != TestMode.custom || r.customKind == settings.customKind) &&
        (r.isCountRun ? r.count == settings.count : r.duration == settings.duration) &&
        rangesKey(r.ranges) == rangesKey(settings.ranges));

/// All practice contributes solved/time totals; only completed scored tests contribute pace.
Summary summary(List<Result> results, {Settings? settings}) {
  final scored = [
    for (final r in results)
      if (r.isScoredRun && matchesSettings(r, settings)) r,
  ];
  scored.sort((a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)));
  final paces = [for (final r in scored) r.pace];
  return Summary(
    tests: results.where((r) => r.isScoredRun).length,
    solved: results.fold(0, (n, r) => n + r.logs.length),
    timeMs: results.fold(0.0, (n, r) => n + r.elapsedMs),
    joined: results.isEmpty ? null : results.map((r) => r.date).reduce((a, d) => d.compareTo(a) < 0 ? d : a),
    highestPace: paces.isEmpty ? 0 : paces.max,
    averagePace: _mean(paces),
    last10Pace: _mean(paces.take(10)),
    averageVariation: _mean(scored.map(variation)),
  );
}

/// Best result per standard length, for runs played with exactly these ranges.
Map<int, Result> bestsFor(Iterable<Result> results, TestMode mode, List<int> targets, RangeConfig ranges) {
  final key = rangesKey(ranges), bests = <int, Result>{};
  for (final r in personalBests(results)) {
    if (r.mode != mode || rangesKey(r.ranges) != key) continue;
    final target = r.isCountRun ? r.count : r.duration;
    if (targets.contains(target)) bests[target] = r;
  }
  return bests;
}

class HistoryPoint {
  const HistoryPoint({
    required this.test,
    required this.ppm,
    required this.average10,
    required this.average100,
    required this.date,
  });
  final int test, ppm, average10, average100;
  final String date;
  Map<String, Object> toJson() => {
    'test': test,
    'ppm': ppm,
    'average10': average10,
    'average100': average100,
    'date': date,
  };
}

/// Oldest-first pace per test with trailing averages over the last 10 and 100 tests.
List<HistoryPoint> profilePaceSeries(Iterable<Result> results, {Settings? settings}) {
  final ordered = [
    for (final r in results)
      if (r.isScoredRun && matchesSettings(r, settings)) r,
  ];
  mergeSort(ordered, compare: (a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)));
  final paces = [for (final r in ordered) r.pace];
  int trailing(int i, int n) => _mean(paces.sublist(math.max(0, i - n + 1), i + 1)).round();
  return [
    for (final (i, r) in ordered.indexed)
      HistoryPoint(
        test: i + 1,
        ppm: paces[i].round(),
        average10: trailing(i, 10),
        average100: trailing(i, 100),
        date: r.date,
      ),
  ];
}

/// 10 xp per solved problem. Each level costs 50 xp more than the one before, starting at 100.
({int level, int xp, int into, int needed}) level(Iterable<Result> results) {
  final xp = results.fold(0, (n, r) => n + r.logs.length * 10);
  var lvl = 1, floor = 0, step = 100;
  while (xp >= floor + step) {
    floor += step;
    lvl++;
    step += 50;
  }
  return (level: lvl, xp: xp, into: xp - floor, needed: step);
}

String formatDuration(double ms) {
  final s = ms ~/ 1000, h = s ~/ 3600, m = s % 3600 ~/ 60;
  return h > 0
      ? '${h}h ${m}m'
      : m > 0
      ? '${m}m ${s % 60}s'
      : '${s}s';
}
