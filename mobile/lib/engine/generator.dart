import 'js_json.dart';

/// The four operations. [symbol] is the character web uses in ids, JSON keys and personal-best keys.
enum Operation {
  add('+'),
  subtract('-'),
  multiply('×'),
  divide('÷');

  const Operation(this.symbol);
  final String symbol;

  static Operation? fromSymbol(Object? symbol) {
    for (final op in values) {
      if (op.symbol == symbol) return op;
    }
    return null;
  }
}

/// Thrown for settings that cannot produce problems. [message] matches the web wording.
class RangeConfigError implements Exception {
  const RangeConfigError(this.message);
  final String message;
  @override
  String toString() => message;
}

class OperationRange {
  const OperationRange({
    required this.enabled,
    required this.weight,
    required this.minA,
    required this.maxA,
    required this.minB,
    required this.maxB,
  });

  final bool enabled;
  final double weight;
  final int minA, maxA, minB, maxB;

  OperationRange copyWith({bool? enabled, double? weight, int? minA, int? maxA, int? minB, int? maxB}) =>
      OperationRange(
        enabled: enabled ?? this.enabled,
        weight: weight ?? this.weight,
        minA: minA ?? this.minA,
        maxA: maxA ?? this.maxA,
        minB: minB ?? this.minB,
        maxB: maxB ?? this.maxB,
      );

  /// Throws [RangeConfigError] with the web validation message when a field has the wrong type.
  factory OperationRange.fromJson(Object? json) {
    if (json is! Map || json['enabled'] is! bool || json['weight'] is! num) {
      throw const RangeConfigError('Invalid operation settings.');
    }
    int whole(String key) {
      final n = wholeNumber(json[key]);
      if (n == null) {
        throw const RangeConfigError('Ranges must use whole numbers from 1 to 1,000,000.');
      }
      return n;
    }

    return OperationRange(
      enabled: json['enabled'] as bool,
      weight: (json['weight'] as num).toDouble(),
      minA: whole('minA'),
      maxA: whole('maxA'),
      minB: whole('minB'),
      maxB: whole('maxB'),
    );
  }

  /// Same key order as web, so exports look the same.
  Map<String, Object> toJson() => {
    'enabled': enabled,
    'weight': jsNum(weight),
    'minA': minA,
    'maxA': maxA,
    'minB': minB,
    'maxB': maxB,
  };

  @override
  bool operator ==(Object other) =>
      other is OperationRange &&
      other.enabled == enabled &&
      other.weight == weight &&
      other.minA == minA &&
      other.maxA == maxA &&
      other.minB == minB &&
      other.maxB == maxB;
  @override
  int get hashCode => Object.hash(enabled, weight, minA, maxA, minB, maxB);
}

/// One [OperationRange] per operation, like web's `RangeConfig`.
class RangeConfig {
  RangeConfig(Map<Operation, OperationRange> ranges) : _ranges = Map.unmodifiable(ranges) {
    assert(Operation.values.every(_ranges.containsKey));
  }

  final Map<Operation, OperationRange> _ranges;

  OperationRange operator [](Operation op) => _ranges[op]!;

  RangeConfig withRange(Operation op, OperationRange range) => RangeConfig({..._ranges, op: range});

  factory RangeConfig.fromJson(Object? json) {
    if (json is! Map) {
      throw const RangeConfigError('Invalid operation settings.');
    }
    return RangeConfig({for (final op in Operation.values) op: OperationRange.fromJson(json[op.symbol])});
  }

  Map<String, Object> toJson() => {for (final op in Operation.values) op.symbol: this[op].toJson()};

  @override
  bool operator ==(Object other) => other is RangeConfig && Operation.values.every((op) => other[op] == this[op]);
  @override
  int get hashCode => Object.hashAll(Operation.values.map((op) => this[op]));
}

final defaultRanges = RangeConfig({
  Operation.add: const OperationRange(enabled: true, weight: 1, minA: 2, maxA: 100, minB: 2, maxB: 100),
  Operation.subtract: const OperationRange(enabled: true, weight: 1, minA: 2, maxA: 100, minB: 2, maxB: 100),
  Operation.multiply: const OperationRange(enabled: true, weight: 1, minA: 2, maxA: 12, minB: 2, maxB: 100),
  Operation.divide: const OperationRange(enabled: true, weight: 1, minA: 2, maxA: 12, minB: 2, maxB: 100),
});

class Problem {
  const Problem({required this.a, required this.b, required this.op, required this.answer, required this.id});

  final int a, b, answer;
  final Operation op;
  final String id;

  /// Subtraction and division are built backwards from addition and multiplication,
  /// so answers are never negative and always whole.
  factory Problem.make(Operation op, int a, int b) {
    final answer = switch (op) {
      Operation.add => a + b,
      Operation.multiply => a * b,
      Operation.subtract || Operation.divide => a,
    };
    if (op == Operation.subtract) a += b;
    if (op == Operation.divide) a *= b;
    return Problem(a: a, b: b, op: op, answer: answer, id: '$a${op.symbol}$b');
  }

  /// Reads the shape only. History import checks the arithmetic separately.
  factory Problem.fromJson(Object? json) {
    final op = json is Map ? Operation.fromSymbol(json['op']) : null;
    if (json is! Map || op == null || json['id'] is! String) {
      throw const FormatException('Invalid problem');
    }
    final [a, b, answer] = [
      for (final k in ['a', 'b', 'answer']) wholeNumber(json[k]) ?? (throw const FormatException('Invalid problem')),
    ];
    return Problem(a: a, b: b, op: op, answer: answer, id: json['id'] as String);
  }

  Map<String, Object> toJson() => {'a': a, 'b': b, 'op': op.symbol, 'answer': answer, 'id': id};

  @override
  bool operator ==(Object other) => other is Problem && other.id == id && other.answer == answer;
  @override
  int get hashCode => Object.hash(id, answer);
}

String? validateRanges(RangeConfig ranges) {
  var enabled = 0;
  for (final op in Operation.values) {
    final r = ranges[op];
    if (!r.weight.isFinite || r.weight < 0 || r.weight > 1000) {
      return 'Weights must be between 0 and 1000.';
    }
    for (final value in [r.minA, r.maxA, r.minB, r.maxB]) {
      if (value < 1 || value > 1000000) {
        return 'Ranges must use whole numbers from 1 to 1,000,000.';
      }
    }
    if (r.minA > r.maxA || r.minB > r.maxB) {
      return 'Range minimum must not exceed maximum.';
    }
    if (r.enabled && r.weight > 0) enabled++;
  }
  return enabled > 0 ? null : 'Enable at least one operation with a positive weight.';
}

/// Port of web `generateProblem`. Consumes [rng] in exactly the same order, so a seed replays identically.
Problem generateProblem(RangeConfig ranges, double Function() rng, {String? previousId}) {
  final error = validateRanges(ranges);
  if (error != null) throw RangeConfigError(error);
  final enabled = [
    for (final op in Operation.values)
      if (ranges[op].enabled && ranges[op].weight > 0) op,
  ];
  final total = enabled.fold<double>(0, (sum, op) => sum + ranges[op].weight);
  int pickInt(int min, int max) => min + (rng() * (max - min + 1)).floor();
  for (var attempt = 0; attempt < 64; attempt++) {
    var pick = rng() * total;
    final op = enabled.firstWhere((key) => (pick -= ranges[key].weight) < 0, orElse: () => enabled.last);
    final r = ranges[op];
    final candidate = Problem.make(op, pickInt(r.minA, r.maxA), pickInt(r.minB, r.maxB));
    if (candidate.id != previousId) return candidate;
  }
  // Deterministic fallback prevents random retries from hanging on tiny domains.
  for (final op in enabled) {
    final r = ranges[op];
    for (final a in [r.minA, r.maxA]) {
      for (final b in [r.minB, r.maxB]) {
        final problem = Problem.make(op, a, b);
        if (problem.id != previousId) return problem;
      }
    }
  }
  throw const RangeConfigError('These ranges contain only one problem. Widen a range to avoid consecutive repeats.');
}
