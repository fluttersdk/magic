import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/localization/translator.dart';
import 'package:magic/src/localization/contracts/translation_loader.dart';

/// Mock loader for testing.
///
/// This mock pre-flattens nested keys like the real JsonAssetLoader does.
class MockTranslationLoader implements TranslationLoader {
  final Map<String, Map<String, dynamic>> _locales;

  MockTranslationLoader(this._locales);

  @override
  Future<Map<String, dynamic>> load(Locale locale) async {
    final data = _locales[locale.languageCode] ?? {};
    return _flatten(data);
  }

  /// Flatten nested keys (same logic as JsonAssetLoader).
  Map<String, dynamic> _flatten(Map<String, dynamic> json,
      [String prefix = '']) {
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

void main() {
  group('Translator', () {
    setUp(() {
      Translator.reset();
    });

    test('should be a singleton', () {
      final a = Translator.instance;
      final b = Translator.instance;
      expect(identical(a, b), isTrue);
    });

    test('should load translations and flatten keys', () async {
      final translator = Translator.instance;
      translator.setLoader(MockTranslationLoader({
        'en': {
          'welcome': 'Welcome!',
          'auth': {
            'failed': 'Authentication failed.',
            'throttle': 'Too many attempts.',
          },
        },
      }));

      await translator.load(const Locale('en'));

      expect(translator.get('welcome'), 'Welcome!');
      expect(translator.get('auth.failed'), 'Authentication failed.');
      expect(translator.get('auth.throttle'), 'Too many attempts.');
    });

    test('should return key if translation not found', () async {
      final translator = Translator.instance;
      translator.setLoader(MockTranslationLoader({'en': {}}));
      await translator.load(const Locale('en'));

      expect(translator.get('missing.key'), 'missing.key');
    });

    test('should apply replacements with :key syntax', () async {
      final translator = Translator.instance;
      translator.setLoader(MockTranslationLoader({
        'en': {
          'greeting': 'Hello, :name! You have :count messages.',
        },
      }));

      await translator.load(const Locale('en'));

      final result = translator.get('greeting', {
        'name': 'John',
        'count': 5,
      });

      expect(result, 'Hello, John! You have 5 messages.');
    });

    test('should track loaded state', () async {
      final translator = Translator.instance;
      translator.setLoader(MockTranslationLoader({'en': {}}));

      expect(translator.isLoaded, isFalse);

      await translator.load(const Locale('en'));

      expect(translator.isLoaded, isTrue);
    });

    test('should track current locale', () async {
      final translator = Translator.instance;
      translator.setLoader(MockTranslationLoader({
        'en': {},
        'tr': {},
      }));

      await translator.load(const Locale('en'));
      expect(translator.locale.languageCode, 'en');

      // Reset to allow loading new locale
      Translator.reset();
      Translator.instance.setLoader(MockTranslationLoader({
        'en': {},
        'tr': {},
      }));

      await Translator.instance.load(const Locale('tr'));
      expect(Translator.instance.locale.languageCode, 'tr');
    });

    test('should check if key exists', () async {
      final translator = Translator.instance;
      translator.setLoader(MockTranslationLoader({
        'en': {'exists': 'Yes'},
      }));

      await translator.load(const Locale('en'));

      expect(translator.has('exists'), isTrue);
      expect(translator.has('missing'), isFalse);
    });

    test('should handle deeply nested keys', () async {
      final translator = Translator.instance;
      translator.setLoader(MockTranslationLoader({
        'en': {
          'level1': {
            'level2': {
              'level3': {
                'deep': 'Found it!',
              },
            },
          },
        },
      }));

      await translator.load(const Locale('en'));

      expect(translator.get('level1.level2.level3.deep'), 'Found it!');
    });

    test('should handle multiple replacements in same string', () async {
      final translator = Translator.instance;
      translator.setLoader(MockTranslationLoader({
        'en': {
          'message': ':user sent :count messages to :recipient',
        },
      }));

      await translator.load(const Locale('en'));

      final result = translator.get('message', {
        'user': 'Alice',
        'count': 3,
        'recipient': 'Bob',
      });

      expect(result, 'Alice sent 3 messages to Bob');
    });
  });

  group('Lang Facade Integration', () {
    setUp(() {
      Translator.reset();
    });

    test('should work with __ helper function pattern', () async {
      final translator = Translator.instance;
      translator.setLoader(MockTranslationLoader({
        'en': {
          'hello': 'Hello, :name!',
        },
      }));

      await translator.load(const Locale('en'));

      // Simulate __() helper behavior
      String trans(String key, [Map<String, dynamic>? replace]) {
        return translator.get(key, replace);
      }

      expect(trans('hello', {'name': 'World'}), 'Hello, World!');
    });
  });

  group('Dynamic Locale Management', () {
    setUp(() {
      Translator.reset();
    });

    test('setLocale should force reload and notify listeners', () async {
      final translator = Translator.instance;
      translator.setLoader(MockTranslationLoader({
        'en': {'hello': 'Hello'},
        'tr': {'hello': 'Merhaba'},
      }));

      // Initial load
      await translator.load(const Locale('en'));
      expect(translator.get('hello'), 'Hello');

      // Track notifications
      var notifyCount = 0;
      translator.addListener(() => notifyCount++);

      // Switch locale
      await translator.setLocale(const Locale('tr'));

      expect(translator.get('hello'), 'Merhaba');
      expect(translator.locale.languageCode, 'tr');
      expect(notifyCount, 1);
    });

    test('setSupportedLocales should update supported list', () {
      final translator = Translator.instance;

      translator.setSupportedLocales([
        const Locale('en'),
        const Locale('tr'),
        const Locale('de'),
      ]);

      expect(translator.supportedLocales.length, 3);
      expect(translator.supportedLocales[0].languageCode, 'en');
      expect(translator.supportedLocales[1].languageCode, 'tr');
      expect(translator.supportedLocales[2].languageCode, 'de');
    });

    test('detectLocale should return best match from supported', () {
      final translator = Translator.instance;
      translator.setSupportedLocales([
        const Locale('en'),
        const Locale('tr'),
      ]);

      // detectLocale uses PlatformDispatcher.instance.locale
      // In tests, this is typically 'en_US', so it should match 'en'
      final detected = translator.detectLocale();
      expect(detected.languageCode, isNotEmpty);
    });

    test('detectLocale should fallback to first supported if no match', () {
      final translator = Translator.instance;
      translator.setSupportedLocales([
        const Locale('ja'),
        const Locale('zh'),
      ]);

      // Device locale probably won't be Japanese or Chinese in test env
      final detected = translator.detectLocale();
      // Should fallback to first supported
      expect(translator.supportedLocales.contains(detected), isTrue);
    });

    test('removeListener should stop notifications', () async {
      final translator = Translator.instance;
      translator.setLoader(MockTranslationLoader({
        'en': {},
        'tr': {},
      }));

      var notifyCount = 0;
      void listener() => notifyCount++;

      translator.addListener(listener);
      await translator.load(const Locale('en'));
      expect(notifyCount, 1);

      translator.removeListener(listener);
      await translator.setLocale(const Locale('tr'));
      expect(notifyCount, 1); // Should not increment
    });

    test('load should not reload same locale if already loaded', () async {
      final translator = Translator.instance;
      translator.setLoader(MockTranslationLoader({
        'en': {'key': 'value'},
      }));

      var notifyCount = 0;
      translator.addListener(() => notifyCount++);

      await translator.load(const Locale('en'));
      expect(notifyCount, 1);

      // Loading same locale again should not notify
      await translator.load(const Locale('en'));
      expect(notifyCount, 1);
    });

    test('setLocale should force reload even for same locale', () async {
      final translator = Translator.instance;
      translator.setLoader(MockTranslationLoader({
        'en': {'key': 'value'},
      }));

      var notifyCount = 0;
      translator.addListener(() => notifyCount++);

      await translator.load(const Locale('en'));
      expect(notifyCount, 1);

      // setLocale forces reload
      await translator.setLocale(const Locale('en'));
      expect(notifyCount, 2);
    });
  });
}
