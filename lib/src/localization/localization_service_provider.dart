import 'dart:ui' show Locale;

import '../support/service_provider.dart';
import '../facades/config.dart';
import '../facades/log.dart';
import 'translator.dart';
import 'loaders/json_asset_loader.dart';

/// The Localization Service Provider.
///
/// Register this provider in your `config/app.dart` to enable localization.
class LocalizationServiceProvider extends ServiceProvider {
  /// Create a new localization service provider.
  LocalizationServiceProvider(super.app);

  @override
  void register() {
    // Get config values
    final path = Config.get<String>('localization.path', 'lang') ?? 'lang';
    final fallback =
        Config.get<String>('localization.fallback_locale', 'en') ?? 'en';

    // Bind the translator as a singleton
    app.singleton('translator', () {
      final translator = Translator.instance;
      translator.setLoader(JsonAssetLoader(
        basePath: path,
        fallbackLocale: fallback,
      ));
      return translator;
    });

    // Mark localization as enabled
    app.setInstance('localization.enabled', true);
  }

  @override
  Future<void> boot() async {
    final translator = Translator.instance;

    // Load supported locales from config
    final supportedLocalesConfig =
        Config.get<List<dynamic>>('localization.supported_locales', null);
    if (supportedLocalesConfig != null) {
      final locales = supportedLocalesConfig.map((code) {
        if (code is Locale) return code;
        return Locale(code.toString());
      }).toList();
      translator.setSupportedLocales(locales);
    }

    // Get fallback locale
    final fallbackLocale =
        Config.get<String>('localization.fallback_locale', 'en') ?? 'en';
    translator.setFallbackLocale(Locale(fallbackLocale));

    // Determine initial locale
    final autoDetect =
        Config.get<bool>('localization.auto_detect_locale', false) ?? false;

    if (autoDetect) {
      // Auto-detect from device/browser
      final detected = await translator.detectAndSetLocale();
      Log.info('Locale auto-detected [${detected.languageCode}]');
    } else {
      // Use configured locale
      final localeStr = Config.get<String>('localization.locale', 'en') ?? 'en';
      await translator.load(Locale(localeStr));
      Log.info('Localization ready [$localeStr]');
    }
  }
}
