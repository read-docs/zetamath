import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/generator.dart';
import 'history.dart';

enum AnswerStyle { inline, stacked }

/// Phone puts 1-2-3 on the top row, like the dialer. Calculator puts 7-8-9 there.
enum KeypadLayout { phone, calculator }

const timeOptions = [15, 30, 60, 120];
const countOptions = [10, 25, 50, 100];
const fonts = ['JetBrains Mono', 'Roboto Mono', 'Fira Code', 'IBM Plex Mono', 'Space Mono', 'Lexend Deca'];

/// The web `Settings` plus the touch-only options ([haptics], [keypadLayout]).
class Settings {
  const Settings({
    this.mode = TestMode.time,
    this.duration = 120,
    this.count = 25,
    this.customKind = CustomKind.time,
    required this.ranges,
    this.theme = 'iceberg',
    this.font = 'JetBrains Mono',
    this.size = 4,
    this.showTimer = true,
    this.showScore = true,
    this.showPace = false,
    this.focusMode = true,
    this.answerStyle = AnswerStyle.inline,
    this.name = '',
    this.haptics = true,
    this.keypadLayout = KeypadLayout.phone,
    this.seed = '',
  });

  final TestMode mode;
  final int duration, count;
  final CustomKind customKind;
  final RangeConfig ranges;
  final String theme, font, name;

  /// Problem text size in rem, 2 to 8, as on web. One rem is 16 logical pixels.
  final double size;
  final bool showTimer, showScore, showPace, focusMode, haptics;
  final AnswerStyle answerStyle;
  final KeypadLayout keypadLayout;

  /// Fixed seed for every test, like web's `?seed=`. Empty means a fresh random seed each time.
  final String seed;

  bool get timed => mode == TestMode.time || (mode == TestMode.custom && customKind == CustomKind.time);

  /// Whether a change from [other] to this alters the test itself, so a running test must end.
  bool changesTest(Settings other) =>
      mode != other.mode ||
      duration != other.duration ||
      count != other.count ||
      customKind != other.customKind ||
      ranges != other.ranges ||
      seed != other.seed;

  bool get counted => mode == TestMode.count || (mode == TestMode.custom && customKind == CustomKind.count);

  Settings copyWith({
    TestMode? mode,
    int? duration,
    int? count,
    CustomKind? customKind,
    RangeConfig? ranges,
    String? theme,
    String? font,
    double? size,
    bool? showTimer,
    bool? showScore,
    bool? showPace,
    bool? focusMode,
    AnswerStyle? answerStyle,
    String? name,
    bool? haptics,
    KeypadLayout? keypadLayout,
    String? seed,
  }) => Settings(
    mode: mode ?? this.mode,
    duration: duration ?? this.duration,
    count: count ?? this.count,
    customKind: customKind ?? this.customKind,
    ranges: ranges ?? this.ranges,
    theme: theme ?? this.theme,
    font: font ?? this.font,
    size: size ?? this.size,
    showTimer: showTimer ?? this.showTimer,
    showScore: showScore ?? this.showScore,
    showPace: showPace ?? this.showPace,
    focusMode: focusMode ?? this.focusMode,
    answerStyle: answerStyle ?? this.answerStyle,
    name: name ?? this.name,
    haptics: haptics ?? this.haptics,
    keypadLayout: keypadLayout ?? this.keypadLayout,
    seed: seed ?? this.seed,
  );

  Map<String, Object> toJson() => {
    'mode': mode.name,
    'duration': duration,
    'count': count,
    'customKind': customKind.name,
    'ranges': ranges.toJson(),
    'theme': theme,
    'font': font,
    'size': size,
    'showTimer': showTimer,
    'showScore': showScore,
    'showPace': showPace,
    'focusMode': focusMode,
    'answerStyle': answerStyle.name,
    'name': name,
    'haptics': haptics,
    'keypadLayout': keypadLayout.name,
    'seed': seed,
  };

  /// Reads each field on its own and falls back to the default for anything missing or invalid,
  /// so one bad value never resets the rest.
  factory Settings.fromJson(Map json) {
    final d = defaultSettings;
    T pick<T>(String key, T fallback, bool Function(T) valid) {
      final v = json[key];
      return v is T && valid(v) ? v : fallback;
    }

    E pickEnum<E extends Enum>(String key, List<E> values, E fallback) =>
        values.where((e) => e.name == json[key]).firstOrNull ?? fallback;
    RangeConfig ranges;
    try {
      ranges = RangeConfig.fromJson(json['ranges']);
      if (validateRanges(ranges) != null) ranges = d.ranges;
    } on RangeConfigError {
      ranges = d.ranges;
    }
    final size = json['size'];
    return Settings(
      mode: pickEnum('mode', TestMode.values, d.mode),
      duration: pick<int>('duration', d.duration, (n) => n >= 1 && n <= 86400),
      count: pick<int>('count', d.count, (n) => n >= 1 && n <= 86400),
      customKind: pickEnum('customKind', CustomKind.values, d.customKind),
      ranges: ranges,
      theme: pick<String>('theme', d.theme, (_) => true),
      font: pick<String>('font', d.font, fonts.contains),
      size: size is num && size >= 2 && size <= 8 ? size.toDouble() : d.size,
      showTimer: pick<bool>('showTimer', d.showTimer, (_) => true),
      showScore: pick<bool>('showScore', d.showScore, (_) => true),
      showPace: pick<bool>('showPace', d.showPace, (_) => true),
      focusMode: pick<bool>('focusMode', d.focusMode, (_) => true),
      answerStyle: pickEnum('answerStyle', AnswerStyle.values, d.answerStyle),
      name: pick<String>('name', d.name, (s) => s.length <= 24),
      haptics: pick<bool>('haptics', d.haptics, (_) => true),
      keypadLayout: pickEnum('keypadLayout', KeypadLayout.values, d.keypadLayout),
      seed: pick<String>('seed', d.seed, (_) => true),
    );
  }
}

final defaultSettings = Settings(ranges: defaultRanges);

/// Where the settings blob lives. `shared_preferences` in the app, a map in tests.
abstract interface class SettingsStorage {
  String? read();
  Future<void> write(String value);
}

/// Stored as `{"state": {...}, "version": 2}` under `zetamath-settings`, the zustand persist shape web uses.
const settingsKey = 'zetamath-settings';
const settingsVersion = 2;

final settingsStorageProvider = Provider<SettingsStorage>(
  (ref) => throw UnimplementedError('Override settingsStorageProvider in main'),
);

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<Settings> {
  @override
  Settings build() {
    final saved = ref.read(settingsStorageProvider).read();
    if (saved == null) return defaultSettings;
    try {
      final data = jsonDecode(saved);
      return data is Map && data['state'] is Map ? Settings.fromJson(data['state'] as Map) : defaultSettings;
    } on FormatException {
      return defaultSettings;
    }
  }

  void update(Settings Function(Settings) change) {
    state = change(state);
    ref.read(settingsStorageProvider).write(jsonEncode({'state': state.toJson(), 'version': settingsVersion}));
  }

  /// Resets everything except the profile name, as web does.
  void reset() => update((s) => defaultSettings.copyWith(name: s.name));
}
