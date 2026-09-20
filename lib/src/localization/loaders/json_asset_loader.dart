import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:magic/magic.dart';

import 'debug_asset_reader_stub.dart'
    if (dart.library.io) 'debug_asset_reader_io.dart'
    if (dart.library.js_interop) 'debug_asset_reader_web.dart';

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

  /// Reads [locale]'s catalogue, falling back to [fallbackLocale]'s whole file.
  ///
  /// **An empty map is the failure, and it used to be a silent one.** Every
  /// caller reads a miss as a key rendering as itself, so a catalogue that did
  /// not load and a catalogue with a missing key are indistinguishable on
  /// screen. The warnings below are what tell them apart, and they are guarded
  /// on `Magic.bound('log')` for exactly the reason
  /// `Translator._loadFallbackFor` already records: `Log` resolves `log`
  /// through the container and THROWS for an unbound key, so logging a failure
  /// unguarded would replace it with a different one.
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
        } catch (fallbackError) {
          if (Magic.bound('log')) {
            Log.warning(
              'Could not load translations for [${locale.languageCode}] '
              '($e) or for the fallback [$fallbackLocale] ($fallbackError). '
              'Every key will render as itself.',
            );
          }

          return {};
        }
      }

      if (Magic.bound('log')) {
        Log.warning(
          'Could not load translations for [${locale.languageCode}] from '
          '[$basePath] ($e). Every key will render as itself.',
        );
      }

      return {};
    }
  }

  /// Load and parse JSON file.
  ///
  /// **Reads nothing out of the container, deliberately.** This used to open
  /// with `Log.info('Loading translation file [$path]')`, and `Log` resolves
  /// `log` through the container, which throws for an unbound key
  /// (`foundation/application.dart:269-274`). [load]'s catch then turned that
  /// throw into an empty catalogue, so a host that loads translations before
  /// its logging provider boots, or a widget test that never calls
  /// `Magic.init`, got every key rendering as itself with nothing to read.
  ///
  /// Measured from a consumer app's test: `rootBundle` reads the asset fine
  /// (19,345 bytes), `Translator.load` reports `loaded: true` for the right
  /// locale, and this loader still answers zero keys.
  ///
  /// A loader that reads a file should not need a service to do it. The line
  /// is gone rather than guarded: it fired twice per `Translator.load`, once
  /// for the locale and once for the fallback, and nothing consumed it.
  Future<Map<String, dynamic>> _loadJson(String languageCode) async {
    final path = '$basePath/$languageCode.json';

    // In debug mode, attempt to bypass the asset bundle cache so that
    // hot restart picks up JSON changes. Best-effort: works reliably on
    // desktop and web; on mobile the file usually does not exist on disk,
    // so we fall back to rootBundle.
    if (kDebugMode) {
      final content = await debugReadAssetFile(path);

      if (content != null) {
        return jsonDecode(content) as Map<String, dynamic>;
      }
    }

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
