import 'package:flutter/widgets.dart';

import '../foundation/magic.dart';
import '../localization/translator.dart';
import '../localization/lang_delegate.dart';

/// The Lang Facade.
///
/// Provides Laravel-style localization access from anywhere in your app,
/// without needing BuildContext.
///
/// ## Usage
///
/// ```dart
/// // Get a translation
/// Lang.get('welcome', {'name': 'Magic'});
///
/// // Change locale at runtime
/// await Lang.setLocale(Locale('tr'));
///
/// // Detect device locale
/// final detected = Lang.detectLocale();
///
/// // Listen to locale changes
/// Lang.addListener(() => print('Locale changed!'));
/// ```
class Lang {
  // Prevent instantiation
  Lang._();

  /// Get the Translator instance.
  static Translator get _translator => Translator.instance;

  // ---------------------------------------------------------------------------
  // Translation
  // ---------------------------------------------------------------------------

  /// Get a translated string.
  ///
  /// ```dart
  /// Lang.get('welcome'); // "Welcome!"
  /// Lang.get('greeting', {'name': 'John'}); // "Hello, John!"
  /// ```
  static String get(String key, [Map<String, dynamic>? replace]) {
    return _translator.get(key, replace);
  }

  /// Check if a translation key exists.
  static bool has(String key) {
    return _translator.has(key);
  }

  // ---------------------------------------------------------------------------
  // Locale Management
  // ---------------------------------------------------------------------------

  /// Get the current locale.
  static Locale get current => _translator.locale;

  /// Check if translations are loaded.
  static bool get isLoaded => _translator.isLoaded;

  /// Get supported locales.
  static List<Locale> get supportedLocales => _translator.supportedLocales;

  /// Set the current locale at runtime.
  ///
  /// Loads translations for the new locale and triggers app reload if [reload]
  /// is true (default). The app reload ensures all widgets rebuild with the
  /// new locale.
  ///
  /// ```dart
  /// // After user login
  /// await Lang.setLocale(Locale(user.preferredLocale));
  ///
  /// // Without app reload (just load translations)
  /// await Lang.setLocale(Locale('tr'), reload: false);
  /// ```
  static Future<void> setLocale(Locale locale, {bool reload = true}) async {
    await _translator.setLocale(locale);
    if (reload) {
      Magic.reload();
    }
  }

  /// Detect the best matching locale from device/browser.
  ///
  /// Does NOT change the current locale. Returns the best match
  /// from supported locales.
  ///
  /// ```dart
  /// final detected = Lang.detectLocale();
  /// print(detected); // e.g., Locale('tr')
  /// ```
  static Locale detectLocale() {
    return _translator.detectLocale();
  }

  /// Detect and set the best matching locale from device/browser.
  ///
  /// ```dart
  /// // On app start, auto-detect user's language
  /// await Lang.detectAndSetLocale();
  /// ```
  static Future<Locale> detectAndSetLocale() async {
    return _translator.detectAndSetLocale();
  }

  /// Set supported locales.
  ///
  /// ```dart
  /// Lang.setSupportedLocales([Locale('en'), Locale('tr')]);
  /// ```
  static void setSupportedLocales(List<Locale> locales) {
    _translator.setSupportedLocales(locales);
  }

  // ---------------------------------------------------------------------------
  // Change Notification
  // ---------------------------------------------------------------------------

  /// Add a listener for locale changes.
  ///
  /// ```dart
  /// Lang.addListener(() {
  ///   print('Locale changed to: ${Lang.current}');
  /// });
  /// ```
  static void addListener(VoidCallback listener) {
    _translator.addListener(listener);
  }

  /// Remove a locale change listener.
  static void removeListener(VoidCallback listener) {
    _translator.removeListener(listener);
  }

  // ---------------------------------------------------------------------------
  // Flutter Integration
  // ---------------------------------------------------------------------------

  /// Get the LocalizationsDelegate for Flutter.
  static const LocalizationsDelegate<Translator> delegate = LangDelegate();
}

// -----------------------------------------------------------------------------
// Global Helper Function
// -----------------------------------------------------------------------------

/// Translate a key with optional replacements.
///
/// This is the Laravel-style `trans()` helper for quick translations:
///
/// ```dart
/// Text(trans('welcome', {'name': 'Magic'}))
/// Text(trans('auth.failed'))
/// ```
String trans(String key, [Map<String, dynamic>? replace]) {
  return Lang.get(key, replace);
}
