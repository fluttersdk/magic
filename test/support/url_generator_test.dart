import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// A [TranslationLoader] that never touches the asset bundle.
///
/// Mirrors `magic_app_widget_locale_test.dart`'s `_FakeTranslationLoader`:
/// the default [JsonAssetLoader] reads through `rootBundle`, which blocks
/// for the real 10-minute test timeout in a unit test with no mocked asset
/// manifest, rather than failing fast.
class _FakeTranslationLoader implements TranslationLoader {
  const _FakeTranslationLoader();

  @override
  Future<Map<String, dynamic>> load(Locale locale) async => const {};
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    MagicApp.reset();
    Magic.flush();
    Env.reset();
    Translator.reset();
    Translator.instance.setLoader(const _FakeTranslationLoader());
    UrlGenerator.originKey = 'app.url';
  });

  group('UrlGenerator.to', () {
    test('composes the path over the origin read from config', () {
      Config.set('app.url', 'https://config.test');

      expect(UrlGenerator.to('/terms'), 'https://config.test/terms');
    });

    test('falls back to Env.filled when the config key is empty', () async {
      await Env.load(mergeWith: {'APP_URL': 'https://env.test'});

      expect(UrlGenerator.to('/terms'), 'https://env.test/terms');
    });

    test('strips a wrapping quote pair left by a .env parser', () {
      Config.set('app.url', '"https://x.test/"');

      expect(UrlGenerator.to('/terms'), 'https://x.test/terms');
    });

    test('strips a trailing slash from the origin', () {
      Config.set('app.url', 'https://x.test/');

      expect(UrlGenerator.to('/terms'), 'https://x.test/terms');
    });

    test('reads a custom origin key when overridden', () {
      UrlGenerator.originKey = 'app.web_url';
      Config.set('app.web_url', 'https://web.test');

      expect(UrlGenerator.to('/terms'), 'https://web.test/terms');
    });

    test('appends a query map', () {
      Config.set('app.url', 'https://x.test');

      expect(
        UrlGenerator.to('/terms', query: {'ref': 'app'}),
        'https://x.test/terms?ref=app',
      );
    });
  });

  group('UrlGenerator.localized', () {
    test('stays on the bare path for the default language', () async {
      Config.set('app.url', 'https://x.test');
      Config.set('localization.locale', 'en');
      Config.set('localization.supported_locales', ['en', 'tr']);
      await Lang.setLocale(const Locale('en'), reload: false);

      expect(UrlGenerator.localized('/terms'), 'https://x.test/terms');
    });

    test('prefixes a supported non-default language', () async {
      Config.set('app.url', 'https://x.test');
      Config.set('localization.locale', 'en');
      Config.set('localization.supported_locales', ['en', 'tr']);
      await Lang.setLocale(const Locale('tr'), reload: false);

      expect(UrlGenerator.localized('/terms'), 'https://x.test/tr/terms');
    });

    test('stays on the bare path for an unsupported language', () async {
      Config.set('app.url', 'https://x.test');
      Config.set('localization.locale', 'en');
      Config.set('localization.supported_locales', ['en', 'tr']);
      await Lang.setLocale(const Locale('de'), reload: false);

      expect(UrlGenerator.localized('/terms'), 'https://x.test/terms');
    });
  });

  group('url() helper', () {
    test('delegates to UrlGenerator.to', () {
      Config.set('app.url', 'https://x.test');

      expect(url('/terms'), 'https://x.test/terms');
    });
  });
}
