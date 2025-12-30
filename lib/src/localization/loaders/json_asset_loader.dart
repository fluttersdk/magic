import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

/// The JSON Asset Loader.
///
/// Loads translation files from `assets/lang/{locale}.json`.
///
/// ## Setup
///
/// 1. Create translation files in `assets/lang/`:
///    - `assets/lang/en.json`
///    - `assets/lang/tr.json`
///
/// 2. Register in `pubspec.yaml`:
///    ```yaml
///    flutter:
///      assets:
///        - assets/lang/
///    ```
///
/// ## JSON Format
///
/// Supports nested keys that will be flattened:
///
/// ```json
/// {
///   "welcome": "Welcome, :name!",
///   "auth": {
///     "failed": "Login failed.",
///     "throttle": "Too many attempts."
///   }
/// }
/// ```
///
/// Becomes: `auth.failed`, `auth.throttle`
class JsonAssetLoader implements TranslationLoader {
  /// The base path for translation files.
  final String basePath;

  /// The fallback locale to use when the requested locale is not found.
  final String fallbackLocale;

  /// Create a new JSON asset loader.
  const JsonAssetLoader({
    this.basePath = 'assets/lang',
    this.fallbackLocale = 'en',
  });

  @override
  Future<Map<String, dynamic>> load(Locale locale) async {
    try {
      final json = await _loadJson(locale.languageCode);
      return _flatten(json);
    } catch (e) {
      // Try fallback locale
      if (locale.languageCode != fallbackLocale) {
        try {
          final json = await _loadJson(fallbackLocale);
          return _flatten(json);
        } catch (_) {
          // Return empty if fallback also fails
          return {};
        }
      }
      return {};
    }
  }

  /// Load and parse JSON file.
  Future<Map<String, dynamic>> _loadJson(String languageCode) async {
    final path = '$basePath/$languageCode.json';
    Log.info('Loading translation file [$path]');
    final content = await rootBundle.loadString(path);
    return jsonDecode(content) as Map<String, dynamic>;
  }

  /// Flatten nested JSON keys for O(1) lookup.
  ///
  /// Example:
  /// ```dart
  /// {'auth': {'failed': 'Error'}} -> {'auth.failed': 'Error'}
  /// ```
  Map<String, dynamic> _flatten(
    Map<String, dynamic> json, [
    String prefix = '',
  ]) {
    final result = <String, dynamic>{};

    for (final entry in json.entries) {
      final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';

      if (entry.value is Map<String, dynamic>) {
        result.addAll(_flatten(entry.value as Map<String, dynamic>, key));
      } else {
        result[key] = entry.value;
      }
    }

    return result;
  }
}
