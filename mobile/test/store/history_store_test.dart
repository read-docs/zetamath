import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zetamath/engine/generator.dart';
import 'package:zetamath/engine/scoring.dart';
import 'package:zetamath/store/history.dart';
import 'package:zetamath/store/history_store.dart';

Result _count(String id, double elapsedMs, {String date = '2026-11-06T10:00:00.000Z'}) => Result(
  id: id,
  date: date,
  mode: TestMode.count,
  duration: 120,
  count: 1,
  customKind: CustomKind.time,
  ranges: defaultRanges,
  seed: 's',
  elapsedMs: elapsedMs,
  drill: false,
  logs: [Solve(problem: Problem.make(Operation.add, 2, 3), timeMs: elapsedMs)],
);

void main() {
  late Directory dir;
  late ProviderContainer container;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('zetamath');
    container = ProviderContainer(overrides: [historyBackendProvider.overrideWithValue(FileHistoryBackend(dir))]);
  });
  tearDown(() {
    container.dispose();
    dir.deleteSync(recursive: true);
  });

  HistoryNotifier history() => container.read(historyProvider.notifier);

  test('adds results newest first, flags personal bests and survives a restart', () async {
    expect(await history().add(_count('a', 2000)), isTrue);
    expect(await history().add(_count('b', 3000)), isFalse);
    expect(await history().add(_count('c', 1000)), isTrue);
    final reopened = ProviderContainer(overrides: [historyBackendProvider.overrideWithValue(FileHistoryBackend(dir))]);
    addTearDown(reopened.dispose);
    await reopened.read(historyProvider.notifier).load();
    expect([for (final r in reopened.read(historyProvider).results) r.id], ['c', 'b', 'a']);
    expect(dir.listSync().map((f) => f.uri.pathSegments.last), ['zetamath-results-v1.json']);
  });

  test('imports a web export, merges by id and sorts newest first', () async {
    await history().add(_count('fixture-00', 1, date: '2030-01-01T00:00:00.000Z'));
    await history().add(_count('local', 1, date: '2026-10-15T00:00:00.000Z'));
    final count = await history().importJson(File('../shared/fixtures/history-v1.json').readAsStringSync());
    expect(count, 18);
    final results = container.read(historyProvider).results;
    expect(results, hasLength(19));
    expect(results.firstWhere((r) => r.id == 'fixture-00').seed, 'seed-0');
    expect([for (final r in results) r.date], [for (final r in results) r.date]..sort((a, b) => b.compareTo(a)));
  });

  test('rejects a bad import without touching history', () async {
    await history().add(_count('a', 2000));
    await expectLater(history().importJson('{"version":1,"results":[{}]}'), throwsA(isA<HistoryFormatError>()));
    expect(container.read(historyProvider).results, hasLength(1));
  });

  test('oversized imports are rejected without touching history', () async {
    await history().add(_count('a', 2000));
    await expectLater(history().importJson(' ' * (maxHistoryImportBytes + 1)), throwsA(isA<HistoryImportSizeError>()));
    expect(container.read(historyProvider).results.single.id, 'a');
  });

  test('an unreadable history file is never overwritten', () async {
    final file = File('${dir.path}/zetamath-results-v1.json')
      ..writeAsStringSync('{"version":1,"results":[{"broken":true}]}');
    await history().load();
    expect(container.read(historyProvider).error, startsWith('History could not be loaded'));
    await expectLater(history().add(_count('a', 2000)), throwsA(isA<HistoryUnavailableError>()));
    await expectLater(
      history().importJson(File('../shared/fixtures/history-v1.json').readAsStringSync()),
      throwsA(isA<HistoryUnavailableError>()),
    );
    await expectLater(history().clear(), throwsA(isA<HistoryUnavailableError>()));
    expect(file.readAsStringSync(), '{"version":1,"results":[{"broken":true}]}');
  });

  test('concurrent adds both land and judge personal bests in order', () async {
    final results = await Future.wait([history().add(_count('a', 2000)), history().add(_count('b', 1000))]);
    expect(results, [isTrue, isTrue]);
    expect([for (final r in container.read(historyProvider).results) r.id], ['b', 'a']);
  });

  test('clear empties the file', () async {
    await history().add(_count('a', 2000));
    await history().clear();
    expect(parseHistory(File('${dir.path}/zetamath-results-v1.json').readAsStringSync()), isEmpty);
  });
}
