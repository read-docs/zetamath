import 'dart:convert';

/// Numbers as JavaScript writes them: whole doubles lose their `.0`, so `1.0` encodes as `1` and `-0.0` as `0`.
/// Keys and exports built from Dart then match the strings the web app builds with `JSON.stringify`.
num jsNum(num n) => n is double && n.isFinite && n == n.truncateToDouble() && n.abs() < 1e21 ? n.toInt() : n;

/// `JSON.stringify` for JSON-shaped values (maps, lists, strings, numbers, bools, null).
/// With [indent], matches `JSON.stringify(value, null, indent)`.
String jsStringify(Object? value, {String? indent}) =>
    (indent == null ? const JsonEncoder() : JsonEncoder.withIndent(indent)).convert(_normalize(value));

Object? _normalize(Object? value) => switch (value) {
  final num n => jsNum(n),
  final List l => [for (final v in l) _normalize(v)],
  final Map m => {for (final e in m.entries) e.key as String: _normalize(e.value)},
  _ => value,
};

/// Reads a JSON number that must be a whole value (`5` or `5.0`), as `Number.isSafeInteger` accepts both.
int? wholeNumber(Object? value) {
  if (value is int) return value.abs() <= 9007199254740991 ? value : null;
  if (value is double && value.isFinite && value == value.truncateToDouble() && value.abs() <= 9007199254740991) {
    return value.toInt();
  }
  return null;
}
