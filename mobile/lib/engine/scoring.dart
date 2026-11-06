import 'dart:math' as math;

import 'package:collection/collection.dart';

import 'generator.dart';
import 'js_json.dart';

class Solve {
  const Solve({required this.problem, required this.timeMs});
  final Problem problem;
  final double timeMs;
  Operation get op => problem.op;
}

double median(List<double> values) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}

double ppm(int count, double elapsedMs) => elapsedMs > 0 ? count * 60000 / elapsedMs : 0;

double _mean(Iterable<double> xs) => xs.isEmpty ? 0 : xs.fold<double>(0, (s, x) => s + x) / xs.length;

/// Coefficient of variation of solve times, as a percentage; lower is more consistent.
double consistency(List<Solve> solves) {
  if (solves.isEmpty) return 0;
  final mean = _mean(solves.map((s) => s.timeMs));
  if (mean <= 0) return 0;
  return math.sqrt(solves.fold<double>(0, (s, x) => s + math.pow(x.timeMs - mean, 2)) / solves.length) / mean * 100;
}

class OperationStats {
  const OperationStats({required this.op, required this.count, required this.averageMs, required this.medianMs});
  final Operation op;
  final int count;
  final double averageMs, medianMs;
  Map<String, Object> toJson() => {'op': op.symbol, 'count': count, 'averageMs': averageMs, 'medianMs': medianMs};
}

List<OperationStats> breakdown(List<Solve> solves) => [
  for (final op in Operation.values)
    () {
      final times = [
        for (final s in solves)
          if (s.op == op) s.timeMs,
      ];
      return OperationStats(op: op, count: times.length, averageMs: _mean(times), medianMs: median(times));
    }(),
];

/// Slowest first. Ties keep their order, as web's stable sort does.
List<Solve> slowest(List<Solve> solves, {int limit = 10}) {
  final sorted = [...solves];
  mergeSort(sorted, compare: (a, b) => b.timeMs.compareTo(a.timeMs));
  return sorted.take(limit).toList();
}

class PacePoint {
  const PacePoint({required this.second, required this.ppm, required this.slow});
  final double second, ppm;
  final bool slow;
  Map<String, Object> toJson() => {'second': second, 'ppm': ppm, 'slow': slow};
}

/// Problems per minute over a trailing window, one point per second. `slow` marks seconds
/// in which a solve took over 1.5× the median.
List<PacePoint> paceSeries(List<Solve> solves, double elapsedMs, {int windowSeconds = 10}) {
  var time = 0.0;
  final events = [for (final s in solves) (end: time += s.timeMs, timeMs: s.timeMs)];
  final slowThreshold = median([for (final s in solves) s.timeMs]) * 1.5;
  return List.generate((elapsedMs / 1000).ceil(), (i) {
    final end = math.min((i + 1) * 1000.0, elapsedMs);
    final start = math.max(0.0, end - windowSeconds * 1000);
    final recent = events.where((e) => e.end > start && e.end <= end).length;
    return PacePoint(
      second: end / 1000,
      ppm: ppm(recent, end - start),
      slow: events.any((e) => e.end > i * 1000 && e.end <= end && e.timeMs > slowThreshold),
    );
  });
}

/// Stable serialization of a JSON-shaped value with object keys sorted, like web `configKey`.
///
/// Web sorts keys with `localeCompare`, so this sorts with an approximation of the default
/// Unicode collation that agrees for the keys the app uses: ASCII identifiers and operator symbols.
String configKey(Object? config) {
  Object? stable(Object? value) => switch (value) {
    final List l => [for (final v in l) stable(v)],
    final Map m => {for (final k in (m.keys.cast<String>().toList()..sort(_localeCompare))) k: stable(m[k])},
    _ => value,
  };
  return jsStringify(stable(config));
}

// Root-collation order for the symbols, then digits, then letters ignoring case.
const _symbolOrder = '_-,;:!?.\'"()[]{}@*/\\&#%`^+±<=>|~÷×\$0123456789';

int _localeCompare(String a, String b) {
  int primary(int unit) {
    final ch = String.fromCharCode(unit);
    final symbol = _symbolOrder.indexOf(ch);
    if (symbol >= 0) return symbol;
    return 1000 + ch.toLowerCase().codeUnitAt(0);
  }

  for (var i = 0; i < math.min(a.length, b.length); i++) {
    final c = primary(a.codeUnitAt(i)).compareTo(primary(b.codeUnitAt(i)));
    if (c != 0) return c;
  }
  if (a.length != b.length) return a.length.compareTo(b.length);
  // Same letters: lowercase sorts before uppercase at the first case difference.
  for (var i = 0; i < a.length; i++) {
    final x = a.codeUnitAt(i), y = b.codeUnitAt(i);
    if (x != y) return y.compareTo(x);
  }
  return 0;
}
