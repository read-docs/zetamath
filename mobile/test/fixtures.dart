import 'dart:convert';
import 'dart:io';

/// Loads a JSON fixture written by `web/scripts/export-fixtures.ts`.
/// `flutter test` runs from the package root, so the shared folder is one level up.
dynamic fixture(String name) => jsonDecode(File('../shared/fixtures/$name').readAsStringSync());
