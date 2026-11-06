import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'history.dart';

/// Where results live. A JSON file in the app documents directory; in memory for tests.
abstract interface class HistoryBackend {
  /// The stored export text, or null before the first save.
  Future<String?> load();
  Future<void> save(String json);
}

/// One JSON file in the export format, written atomically: a temp file, then a rename,
/// so a crash mid-write leaves the previous history intact.
class FileHistoryBackend implements HistoryBackend {
  FileHistoryBackend([this._directory]);
  final Directory? _directory;

  Future<File> _file() async =>
      File('${(_directory ?? await getApplicationDocumentsDirectory()).path}/zetamath-results-v1.json');

  @override
  Future<String?> load() async {
    final file = await _file();
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<void> save(String json) async {
    final file = await _file();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(json, flush: true);
    await temp.rename(file.path);
  }
}

class HistoryState {
  const HistoryState({this.results = const [], this.loaded = false, this.error});
  final List<Result> results;
  final bool loaded;
  final String? error;
}

final historyBackendProvider = Provider<HistoryBackend>((ref) => FileHistoryBackend());

final historyProvider = NotifierProvider<HistoryNotifier, HistoryState>(HistoryNotifier.new);

/// Thrown by writes while the stored history could not be read, so a save never replaces it.
class HistoryUnavailableError implements Exception {
  const HistoryUnavailableError(this.message);
  final String message;
  @override
  String toString() => message;
}

class HistoryNotifier extends Notifier<HistoryState> {
  Future<void>? _loading;
  Future<void> _mutations = Future.value();

  HistoryBackend get _backend => ref.read(historyBackendProvider);

  @override
  HistoryState build() => const HistoryState();

  /// On failure `loaded` stays false, so every write below refuses to run. Calling again retries.
  Future<void> load() {
    if (state.loaded) return Future.value();
    return _loading ??= () async {
      try {
        final text = await _backend.load();
        state = HistoryState(results: text == null ? const [] : parseHistory(text), loaded: true);
      } catch (e) {
        state = HistoryState(error: 'History could not be loaded: $e');
      } finally {
        _loading = null;
      }
    }();
  }

  /// Runs writes one at a time, each on the state the previous one left, like web `enqueue`.
  Future<T> _enqueue<T>(Future<T> Function() action) {
    final next = _mutations.then((_) async {
      await load();
      if (!state.loaded) throw HistoryUnavailableError(state.error ?? 'History is unavailable.');
      return action();
    });
    _mutations = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<void> _save(List<Result> results) => _backend.save(exportHistory(results));

  /// Adds [result] newest first and returns whether it is a new personal best.
  Future<bool> add(Result result) => _enqueue(() async {
    final pb = isPersonalBest(result, state.results);
    final results = [result, ...state.results.where((r) => r.id != result.id)];
    state = HistoryState(results: results, loaded: true, error: state.error);
    try {
      await _save(results);
      state = HistoryState(results: results, loaded: true);
    } catch (_) {
      state = HistoryState(
        results: results,
        loaded: true,
        error: 'History could not be saved. Export your results to keep a backup.',
      );
    }
    return pb;
  });

  /// Merges an export into history and returns how many results it held.
  /// Throws [HistoryFormatError] for a file that is not a valid export.
  Future<int> importJson(String json) async {
    final imported = parseHistory(json);
    return _enqueue(() async {
      final results = mergeHistory(state.results, imported);
      await _save(results);
      state = HistoryState(results: results, loaded: true);
      return imported.length;
    });
  }

  String exportJson() => exportHistory(state.results);

  Future<void> clear() => _enqueue(() async {
    try {
      await _save(const []);
      state = const HistoryState(loaded: true);
    } catch (_) {
      state = HistoryState(results: state.results, loaded: true, error: 'History could not be cleared.');
      rethrow;
    }
  });
}
