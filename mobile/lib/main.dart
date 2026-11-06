import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'store/settings.dart';

/// Settings in `shared_preferences`, read once at startup so the first frame already has them.
class PreferencesSettingsStorage implements SettingsStorage {
  PreferencesSettingsStorage(this._prefs);
  final SharedPreferences _prefs;

  @override
  String? read() => _prefs.getString(settingsKey);

  @override
  Future<void> write(String value) => _prefs.setString(settingsKey, value);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [settingsStorageProvider.overrideWithValue(PreferencesSettingsStorage(prefs))],
      child: const ZetamathApp(),
    ),
  );
}
