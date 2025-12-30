import 'dart:ui';

/// The Translation Loader Contract.
///
/// Defines the interface for loading translation files from various sources
/// (assets, network, database, etc.).
///
/// ## Implementation
///
/// ```dart
/// class JsonAssetLoader implements TranslationLoader {
///   @override
///   Future<Map<String, dynamic>> load(Locale locale) async {
///     final json = await rootBundle.loadString('assets/lang/${locale.languageCode}.json');
///     return jsonDecode(json);
///   }
/// }
/// ```
abstract class TranslationLoader {
  /// Load translations for the given locale.
  ///
  /// Returns a map of translation keys to their values.
  /// Nested keys (e.g., `{'auth': {'failed': 'Error'}}`) are allowed
  /// and will be flattened by the Translator.
  Future<Map<String, dynamic>> load(Locale locale);
}
