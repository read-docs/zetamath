import 'dart:convert';

import 'package:collection/collection.dart';

import '../engine/generator.dart';
import '../engine/js_json.dart';
import '../engine/scoring.dart';

enum TestMode { time, count, zen, custom }

enum CustomKind { time, count }

/// One finished (or abandoned) test. Field names and JSON shape match web `Result`,
/// so exports move between the two apps.
class Result {
  const Result({
    required this.id,
    required this.date,
    required this.mode,
    required this.duration,
    required this.count,
    required this.customKind,
    required this.ranges,
    required this.seed,
    required this.elapsedMs,
    required this.logs,
    this.drill,
  });

  final String id;

  /// ISO 8601 in UTC with milliseconds, as `Date.toISOString` writes it.
  final String date;
  final TestMode mode;
  final int duration, count;
  final CustomKind customKind;
  final RangeConfig ranges;
  final String seed;
  final double elapsedMs;
  final List<Solve> logs;

  /// Older web exports leave this out, so null is kept to write the file back unchanged.
  final bool? drill;

  bool get isDrill => drill ?? false;
  bool get isCountRun => mode == TestMode.count || (mode == TestMode.custom && customKind == CustomKind.count);
  bool get isCompletedRun => mode != TestMode.zen && (isCountRun ? logs.length >= count : elapsedMs >= duration * 1000);
  bool get isScoredRun => !isDrill && isCompletedRun && elapsedMs > 0 && logs.isNotEmpty;
  String get statusLabel => isDrill
      ? 'drill'
      : mode == TestMode.zen
      ? 'free practice'
      : isCompletedRun
      ? 'completed'
      : 'interrupted';
  double get pace => elapsedMs > 0 ? logs.length * 60000 / elapsedMs : 0;

  Result copyWith({List<Solve>? logs}) => Result(
    id: id,
    date: date,
    mode: mode,
    duration: duration,
    count: count,
    customKind: customKind,
    ranges: ranges,
    seed: seed,
    elapsedMs: elapsedMs,
    logs: logs ?? this.logs,
    drill: drill,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'date': date,
    'mode': mode.name,
    'duration': duration,
    'count': count,
    'customKind': customKind.name,
    'ranges': ranges.toJson(),
    'seed': seed,
    'elapsedMs': jsNum(elapsedMs),
    'logs': [
      for (final l in logs) {'problem': l.problem.toJson(), 'timeMs': jsNum(l.timeMs)},
    ],
    'drill': ?drill,
  };

  /// Throws [HistoryFormatError] unless [json] passes the same checks as web `validResult`.
  factory Result.fromJson(Object? json) {
    const invalid = HistoryFormatError();
    if (json is! Map) throw invalid;
    final id = json['id'],
        seed = json['seed'],
        date = json['date'],
        elapsed = json['elapsedMs'],
        logs = json['logs'],
        drill = json['drill'];
    final mode = TestMode.values.firstWhereOrNull((m) => m.name == json['mode']);
    final customKind = CustomKind.values.firstWhereOrNull((k) => k.name == json['customKind']);
    final duration = wholeNumber(json['duration']), count = wholeNumber(json['count']);
    if (id is! String ||
        id.isEmpty ||
        seed is! String ||
        date is! String ||
        DateTime.tryParse(date) == null ||
        mode == null ||
        customKind == null ||
        elapsed is! num ||
        !elapsed.isFinite ||
        elapsed < 0 ||
        duration == null ||
        duration <= 0 ||
        count == null ||
        count <= 0 ||
        logs is! List ||
        (drill != null && drill is! bool)) {
      throw invalid;
    }
    final RangeConfig ranges;
    try {
      ranges = RangeConfig.fromJson(json['ranges']);
    } on RangeConfigError {
      throw invalid;
    }
    for (final op in Operation.values) {
      final r = ranges[op];
      final bounds = [r.minA, r.maxA, r.minB, r.maxB];
      if (!r.weight.isFinite ||
          r.weight < 0 ||
          bounds.any((n) => n < 0 || n > 1000000) ||
          r.minA > r.maxA ||
          r.minB > r.maxB) {
        throw invalid;
      }
    }
    final solves = <Solve>[];
    for (final l in logs) {
      if (l is! Map) throw invalid;
      final Problem p;
      try {
        p = Problem.fromJson(l['problem']);
      } on FormatException {
        throw invalid;
      }
      final time = l['timeMs'];
      if (time is! num || !time.isFinite || time < 0 || !_correct(p)) {
        throw invalid;
      }
      solves.add(Solve(problem: p, timeMs: time.toDouble()));
    }
    return Result(
      id: id,
      date: date,
      mode: mode,
      duration: duration,
      count: count,
      customKind: customKind,
      ranges: ranges,
      seed: seed,
      elapsedMs: elapsed.toDouble(),
      logs: solves,
      drill: drill as bool?,
    );
  }
}

bool _correct(Problem p) => switch (p.op) {
  Operation.add => p.answer == p.a + p.b,
  Operation.subtract => p.answer == p.a - p.b,
  Operation.multiply => p.answer == p.a * p.b,
  Operation.divide => p.b != 0 && p.a % p.b == 0 && p.answer == p.a ~/ p.b,
};

class HistoryFormatError implements Exception {
  const HistoryFormatError();
  @override
  String toString() => 'Invalid history file. Choose a Zetamath JSON export.';
}

/// `Date.toISOString`: UTC, always three fractional digits.
String isoDate(DateTime date) {
  final d = date.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  final ms = d.millisecond.toString().padLeft(3, '0');
  return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}T${two(d.hour)}:${two(d.minute)}:${two(d.second)}.${ms}Z';
}

String rangesKey(RangeConfig ranges) => jsStringify([
  for (final op in Operation.values)
    [
      op.symbol,
      ranges[op].enabled,
      ranges[op].weight,
      ranges[op].minA,
      ranges[op].maxA,
      ranges[op].minB,
      ranges[op].maxB,
    ],
]);

/// Personal bests are compared only between results with the same key.
String resultKey(Result r) => jsStringify([
  r.mode.name,
  r.mode == TestMode.custom ? r.customKind.name : '',
  r.isCountRun ? r.count : r.duration,
  rangesKey(r.ranges),
]);

bool _better(Result a, Result b) => a.isCountRun ? a.elapsedMs < b.elapsedMs : a.logs.length > b.logs.length;

/// Completed, non-drill, non-zen results that beat every other result with the same key.
List<Result> personalBests(Iterable<Result> results) {
  final best = <String, Result>{};
  for (final r in results) {
    if (!r.isScoredRun) continue;
    final key = resultKey(r), previous = best[key];
    if (previous == null || _better(r, previous)) best[key] = r;
  }
  return best.values.toList();
}

/// Whether [result] is a new personal best compared with [existing].
bool isPersonalBest(Result result, Iterable<Result> existing) {
  if (personalBests([result]).isEmpty) return false;
  final key = resultKey(result);
  final previous = personalBests(existing).firstWhereOrNull((r) => resultKey(r) == key);
  return previous == null || _better(result, previous);
}

/// Accepts a `{version: 1, results}` export or a bare array, like web `parseHistory`.
List<Result> parseHistory(String json) {
  final Object? data;
  try {
    data = jsonDecode(json);
  } on FormatException {
    throw const HistoryFormatError();
  }
  final records = data is List
      ? data
      : data is Map && data['version'] == 1
      ? data['results']
      : null;
  if (records is! List) throw const HistoryFormatError();
  return [for (final r in records) Result.fromJson(r)];
}

/// The web export format: `JSON.stringify({version: 1, results}, null, 2)`.
String exportHistory(List<Result> results) => jsStringify({
  'version': 1,
  'results': [for (final r in results) r.toJson()],
}, indent: '  ');

/// Imported results replace local ones with the same id. Newest first, as web sorts after import.
List<Result> mergeHistory(List<Result> local, List<Result> imported) {
  final merged = {for (final r in local) r.id: r};
  for (final r in imported) {
    merged[r.id] = r;
  }
  final list = merged.values.toList();
  mergeSort(list, compare: (a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)));
  return list;
}
