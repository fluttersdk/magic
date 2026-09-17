import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../support/date_manager.dart';
import 'contracts/translation_loader.dart';
import 'loaders/json_asset_loader.dart';
import '../facades/log.dart';
import '../foundation/magic.dart';
import '../facades/event.dart';
import '../foundation/events/app_events.dart';

/// The Translator Service.
///
/// Singleton service that manages translations and provides O(1) lookups.
/// Integrates with DateManager for consistent date localization.
/// Supports runtime locale switching with change notifications.
///
/// ## Usage
///
/// The Translator is typically accessed via the `Lang` facade or `trans()` helper:
///
/// ```dart
/// // Via facade
/// Lang.get('welcome', {'name': 'Magic'});
///
/// // Change locale at runtime
/// await Lang.setLocale(Locale('tr'));
///
/// // Detect device locale
/// Lang.detectLocale();
/// ```
class Translator extends ChangeNotifier {
  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------

  static Translator? _instance;

  /// Get the singleton instance.
  static Translator get instance {
    _instance ??= Translator._();
    return _instance!;
  }

  Translator._();

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  /// The current locale.
  Locale _locale = const Locale('en');

  /// Supported locales (from config).
  List<Locale> _supportedLocales = [const Locale('en')];

  /// The translation sentences (flattened keys).
  Map<String, String> _sentences = {};

  /// The translation loader.
  TranslationLoader _loader = const JsonAssetLoader();

  /// Whether translations have been loaded.
  bool _loaded = false;

  /// The fallback locale.
  Locale _fallbackLocale = const Locale('en');

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  /// Set the translation loader.
  void setLoader(TranslationLoader loader) {
    _loader = loader;
  }

  /// Set supported locales.
  void setSupportedLocales(List<Locale> locales) {
    _supportedLocales = locales;
  }

  /// Set the fallback locale.
  void setFallbackLocale(Locale locale) {
    _fallbackLocale = locale;
  }

  /// Get the fallback locale.
  Locale get fallbackLocale => _fallbackLocale;

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  /// Load translations for the given locale.
  ///
  /// This method:
  /// 1. Loads the fallback catalogue, then [locale]'s, and layers the second
  ///    over the first so a key missing from [locale] is served by the
  ///    fallback
  /// 2. Flattens and caches the sentences
  /// 3. Syncs DateManager locale for date formatting
  /// 4. Notifies listeners of the locale change
  ///
  /// ### Why the fallback is merged rather than chosen
  ///
  /// [get] answers `_sentences[key] ?? key`, and the only fallback that
  /// existed was `JsonAssetLoader`'s, which is whole-FILE: it reads the
  /// fallback catalogue when the requested one fails to load at all, and never
  /// when the requested one loads and is simply incomplete. A half-translated
  /// app therefore rendered raw dotted keys on screen rather than the English
  /// sentence sitting in its own `en.json`.
  ///
  /// Merging here rather than in the loader is deliberate: this class owns
  /// [fallbackLocale], and every [TranslationLoader] a host writes gets the
  /// behaviour without knowing about it.
  Future<void> load(Locale locale) async {
    if (_loaded && _locale == locale) return;

    // Both reads start before either is awaited, so a locale with a fallback
    // pays one round trip rather than two. The spread order is what decides
    // precedence, and it is unaffected by the order they complete in.
    final fallback = _loadFallbackFor(locale);
    final own = _loader.load(locale);

    final data = <String, dynamic>{...await fallback, ...await own};

    // Convert all values to strings
    _sentences = data.map((key, value) => MapEntry(key, value.toString()));
    _locale = locale;

    // Sync DateManager locale for date formatting (Carbon)
    await _syncDateManagerLocale(locale);

    _loaded = true;
    notifyListeners();
    await Event.dispatch(LocaleChanged(locale));
  }

  /// The fallback catalogue to layer [locale]'s own strings over.
  ///
  /// Empty when [locale] IS the fallback, so that case reads its file once
  /// rather than twice and never merges a map with itself.
  ///
  /// A fallback that will not load answers empty rather than throwing. It is a
  /// courtesy and never a requirement: a missing or broken fallback catalogue
  /// must not take the locale's own strings down with it, which is the one
  /// thing worse than a raw key on screen.
  Future<Map<String, dynamic>> _loadFallbackFor(Locale locale) async {
    if (locale.languageCode == _fallbackLocale.languageCode) {
      return const <String, dynamic>{};
    }

    try {
      return await _loader.load(_fallbackLocale);
    } on Object catch (error) {
      // `Log.warning` resolves `log` through the container, which THROWS for
      // an unbound key (`foundation/application.dart:269-274`). So logging
      // here unguarded would defeat the whole point of this catch: a widget
      // test that builds `MaterialApp` through `LangDelegate` without a full
      // `Magic.init()`, or a locale switch before `LogServiceProvider` boots,
      // would take the exception straight out of `load()`.
      if (Magic.bound('log')) {
        Log.warning(
          'Could not load the fallback locale '
          '[${_fallbackLocale.languageCode}]: $error. Keys missing from '
          '[${locale.languageCode}] will render as themselves.',
        );
      }

      return const <String, dynamic>{};
    }
  }

  /// Switch to a new locale at runtime.
  ///
  /// ```dart
  /// await Translator.instance.setLocale(Locale('tr'));
  /// ```
  Future<void> setLocale(Locale locale) async {
    // Force reload even if already loaded
    _loaded = false;
    await load(locale);
  }

  /// Detect and set the best matching locale from device/browser.
  ///
  /// Matches the device locale against supported locales.
  /// Falls back to first supported locale if no match.
  ///
  /// ```dart
  /// await Translator.instance.detectAndSetLocale();
  /// ```
  Future<Locale> detectAndSetLocale() async {
    final detected = detectLocale();
    await setLocale(detected);
    return detected;
  }

  /// Detect the best matching locale from device/browser.
  ///
  /// Does NOT change the current locale, just returns the best match.
  Locale detectLocale() {
    // Get device locale
    final deviceLocale = PlatformDispatcher.instance.locale;

    // Try exact match
    for (final supported in _supportedLocales) {
      if (supported.languageCode == deviceLocale.languageCode &&
          (supported.countryCode == null ||
              supported.countryCode == deviceLocale.countryCode)) {
        return supported;
      }
    }

    // Try language-only match
    for (final supported in _supportedLocales) {
      if (supported.languageCode == deviceLocale.languageCode) {
        return supported;
      }
    }

    // Fallback to first supported
    return _supportedLocales.isNotEmpty
        ? _supportedLocales.first
        : const Locale('en');
  }

  /// Sync DateManager locale for Carbon date formatting.
  Future<void> _syncDateManagerLocale(Locale locale) async {
    try {
      await DateManager.instance.setLocale(locale.languageCode);
    } catch (_) {
      // DateManager might not be booted, ignore errors
    }
  }

  // ---------------------------------------------------------------------------
  // Translation
  // ---------------------------------------------------------------------------

  /// Get a translation by key.
  ///
  /// Supports `:key` replacements:
  ///
  /// ```dart
  /// // JSON: "welcome": "Welcome, :name!"
  /// translator.get('welcome', {'name': 'Magic'});
  /// // Returns: "Welcome, Magic!"
  /// ```
  String get(String key, [Map<String, dynamic>? replace]) {
    var sentence = _sentences[key] ?? key;

    // Apply replacements
    if (replace != null) {
      for (final entry in replace.entries) {
        sentence = sentence.replaceAll(':${entry.key}', entry.value.toString());
      }
    }

    return sentence;
  }

  /// Check if a translation exists.
  bool has(String key) => _sentences.containsKey(key);

  // ---------------------------------------------------------------------------
  // Accessors
  // ---------------------------------------------------------------------------

  /// Get the current locale.
  Locale get locale => _locale;

  /// Get supported locales.
  List<Locale> get supportedLocales => List.unmodifiable(_supportedLocales);

  /// Check if translations are loaded.
  bool get isLoaded => _loaded;

  /// Get all loaded sentences.
  Map<String, String> get sentences => Map.unmodifiable(_sentences);

  // ---------------------------------------------------------------------------
  // Testing
  // ---------------------------------------------------------------------------

  /// Reset the translator (for testing).
  static void reset() {
    _instance?.dispose();
    _instance = null;
  }
}
