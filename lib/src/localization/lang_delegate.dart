import 'package:flutter/material.dart';

import 'translator.dart';
import '../facades/config.dart';

/// The Lang Delegate.
///
/// Connects the Magic translation system to Flutter's localization lifecycle.
/// When the device locale changes, Flutter will trigger a reload.
///
/// ## Usage
///
/// Add to your MaterialApp:
///
/// ```dart
/// MaterialApp(
///   localizationsDelegates: [
///     Lang.delegate,
///     GlobalMaterialLocalizations.delegate,
///     GlobalWidgetsLocalizations.delegate,
///     GlobalCupertinoLocalizations.delegate,
///   ],
///   supportedLocales: [Locale('en'), Locale('tr')],
/// )
/// ```
class LangDelegate extends LocalizationsDelegate<Translator> {
  /// Create a new Lang delegate.
  const LangDelegate();

  /// Check if the given locale is supported.
  ///
  /// Compares against `localization.supported_locales` from config.
  @override
  bool isSupported(Locale locale) {
    final supportedLocales = _getSupportedLocales();
    return supportedLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    );
  }

  /// Load translations for the given locale.
  ///
  /// Delegates to [Translator.instance.load] and returns the singleton.
  @override
  Future<Translator> load(Locale locale) async {
    await Translator.instance.load(locale);
    return Translator.instance;
  }

  /// Whether the delegate should reload.
  ///
  /// Returns `false` since translations are cached in the singleton.
  @override
  bool shouldReload(covariant LocalizationsDelegate<Translator> old) => false;

  /// Get supported locales from config.
  ///
  /// Reads `localization.supported_locales` from config. If not set, defaults to `['en']`.
  List<Locale> _getSupportedLocales() {
    final locales =
        Config.get<List<dynamic>>('localization.supported_locales', null);
    if (locales == null) return [const Locale('en')];
    return locales.map((code) {
      if (code is Locale) return code;
      return Locale(code.toString());
    }).toList();
  }
}
