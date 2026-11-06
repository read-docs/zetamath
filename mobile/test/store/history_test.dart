import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zetamath/engine/generator.dart';
import 'package:zetamath/engine/js_json.dart';
import 'package:zetamath/engine/scoring.dart';
import 'package:zetamath/store/history.dart';

import '../fixtures.dart';

void main() {
  final exportText = File('../shared/fixtures/history-v1.json').readAsStringSync();
  final profile = fixture('profile.json');

  test('reads a web export and writes it back byte for byte', () {
    final results = parseHistory(exportText);
    expect(results, hasLength(18));
    expect(exportHistory(results), exportText.trimRight());
  });

  test('computes the same keys, paces and personal bests as web', () {
    final results = parseHistory(exportText);
    for (final (i, k) in (profile['resultKeys'] as List).indexed) {
      final r = results[i];
      expect(r.id, k['id']);
      expect(rangesKey(r.ranges), k['rangesKey']);
      expect(resultKey(r), k['resultKey']);
      expect(r.isCountRun, k['countRun']);
      expect(r.pace, k['pace']);
    }
    expect([for (final r in personalBests(results)) r.id], profile['personalBests']);
  });

  test('accepts a bare array and rejects other versions and wrong answers', () {
    final raw = (jsonDecode(exportText) as Map)['results'] as List;
    expect(parseHistory(jsonEncode(raw)), hasLength(18));
    expect(() => parseHistory(jsonEncode({'version': 2, 'results': []})), throwsA(isA<HistoryFormatError>()));
    final broken = jsonDecode(jsonEncode(raw)) as List;
    broken[0]['logs'][0]['problem']['answer'] += 1;
    expect(() => parseHistory(jsonEncode(broken)), throwsA(isA<HistoryFormatError>()));
    final badDate = jsonDecode(jsonEncode(raw)) as List;
    badDate[1]['date'] = 'yesterday';
    expect(() => parseHistory(jsonEncode(badDate)), throwsA(isA<HistoryFormatError>()));
  });

  test('accepts whole numbers written with a decimal point, as JavaScript does', () {
    final raw = (jsonDecode(exportText) as Map)['results'] as List;
    final text = jsonEncode(raw).replaceAll('"duration":15,', '"duration":15.0,');
    expect(parseHistory(text).firstWhere((r) => r.id == 'fixture-15').duration, 15);
  });

  test('a new mobile result exports in the web shape', () {
    final r = Result(
      id: 'm1',
      date: '2026-11-06T10:00:00.000Z',
      mode: TestMode.count,
      duration: 120,
      count: 1,
      customKind: CustomKind.time,
      ranges: defaultRanges,
      seed: 's',
      elapsedMs: 2000,
      drill: false,
      logs: [Solve(problem: Problem.make(Operation.add, 2, 3), timeMs: 2000)],
    );
    expect(
      jsStringify(r.toJson()),
      '{"id":"m1","date":"2026-11-06T10:00:00.000Z","mode":"count","duration":120,"count":1,"customKind":"time","ranges":${jsStringify(defaultRanges.toJson())},"seed":"s","elapsedMs":2000,"logs":[{"problem":{"a":2,"b":3,"op":"+","answer":5,"id":"2+3"},"timeMs":2000}],"drill":false}',
    );
    expect(parseHistory(exportHistory([r])).single.toJson(), r.toJson());
  });

  test('formats dates like toISOString', () {
    expect(isoDate(DateTime.utc(2026, 1, 2, 3, 4, 5, 678, 999)), '2026-01-02T03:04:05.678Z');
    expect(isoDate(DateTime.utc(2026, 1, 2)), '2026-01-02T00:00:00.000Z');
  });
}
