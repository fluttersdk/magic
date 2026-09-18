import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart' show Magic, MagicApp;
import 'package:magic/src/localization/contracts/translation_loader.dart';
import 'package:magic/src/localization/translator.dart';

/// Records which locales were asked for, so a test can assert the fallback is
/// loaded once rather than on every lookup.
class _RecordingLoader implements TranslationLoader {
  _RecordingLoader(this._locales, {this.throwsFor});

  final Map<String, Map<String, dynamic>> _locales;

  /// Language code this loader refuses outright, so a test can reach the
  /// failure branch. A loader that answers an EMPTY map for a locale it does
  /// not carry is not a failure: it loads fine and simply has nothing, which
  /// is why the first version of this file never executed the `catch` at all
  /// and passed against a `Translator` with no `try` in it.
  final String? throwsFor;

  final List<String> asked = <String>[];

  @override
  Future<Map<String, dynamic>> load(Locale locale) async {
    asked.add(locale.languageCode);

    if (locale.languageCode == throwsFor) {
      throw StateError('no catalogue for ${locale.languageCode}');
    }

    return Map<String, dynamic>.from(_locales[locale.languageCode] ?? {});
  }
}

/// A catalogue that is missing a key its fallback has used to render the raw
/// key to the user.
///
/// `Translator.get` was `_sentences[key] ?? key`, and the only fallback
/// anywhere was `JsonAssetLoader`'s, which is whole-FILE: it reads the
/// fallback catalogue when the requested one fails to load at all, and never
/// when the requested one loads and is simply incomplete. So a half-translated
/// app showed `magic_starter.auth.login.title` on screen instead of the
/// English sentence sitting in `en.json`.
///
/// Measured in a consumer app whose `tr.json` carried 12 of the 357 keys its
/// `en.json` had: every one of the other 345 rendered as its dotted path.
void main() {
  group('Translator falls back per key, not per file', () {
    setUp(() {
      // `.claude/rules/tests.md:7` asks every setUp for these two, without
      // exception. They also leave `log` unbound, which one test below reads
      // as its precondition.
      MagicApp.reset();
      Magic.flush();
      Translator.reset();
    });

    test('a key missing from the locale is served from the fallback', () async {
      final loader = _RecordingLoader({
        'en': {'greeting': 'Hello', 'farewell': 'Goodbye'},
        'tr': {'greeting': 'Merhaba'},
      });

      Translator.instance.setLoader(loader);
      Translator.instance.setFallbackLocale(const Locale('en'));
      await Translator.instance.load(const Locale('tr'));

      expect(Translator.instance.get('greeting'), 'Merhaba');
      expect(Translator.instance.get('farewell'), 'Goodbye');
    });

    test('the locale still wins where it has the key', () async {
      final loader = _RecordingLoader({
        'en': {'greeting': 'Hello'},
        'tr': {'greeting': 'Merhaba'},
      });

      Translator.instance.setLoader(loader);
      Translator.instance.setFallbackLocale(const Locale('en'));
      await Translator.instance.load(const Locale('tr'));

      expect(Translator.instance.get('greeting'), 'Merhaba');
    });

    test('a key in neither catalogue still answers the key itself', () async {
      // The last resort is unchanged: a key nothing defines renders as itself
      // rather than as an empty string, which is what makes a missing entry
      // visible at all.
      final loader = _RecordingLoader({
        'en': {'greeting': 'Hello'},
        'tr': {'greeting': 'Merhaba'},
      });

      Translator.instance.setLoader(loader);
      Translator.instance.setFallbackLocale(const Locale('en'));
      await Translator.instance.load(const Locale('tr'));

      expect(
        Translator.instance.get('nobody.defined.this'),
        'nobody.defined.this',
      );
    });

    test('has() reports a key the fallback supplies', () async {
      // `has` reads the same map `get` does, so a caller branching on it must
      // see the merged view or it will hide a string that would have rendered.
      final loader = _RecordingLoader({
        'en': {'greeting': 'Hello', 'farewell': 'Goodbye'},
        'tr': {'greeting': 'Merhaba'},
      });

      Translator.instance.setLoader(loader);
      Translator.instance.setFallbackLocale(const Locale('en'));
      await Translator.instance.load(const Locale('tr'));

      expect(Translator.instance.has('farewell'), isTrue);
      expect(Translator.instance.has('nobody.defined.this'), isFalse);
    });

    test('the fallback is loaded once, at load, not per lookup', () async {
      final loader = _RecordingLoader({
        'en': {'greeting': 'Hello', 'farewell': 'Goodbye'},
        'tr': {'greeting': 'Merhaba'},
      });

      Translator.instance.setLoader(loader);
      Translator.instance.setFallbackLocale(const Locale('en'));
      await Translator.instance.load(const Locale('tr'));

      Translator.instance.get('farewell');
      Translator.instance.get('farewell');
      Translator.instance.get('greeting');

      expect(loader.asked, <String>['en', 'tr']);
    });

    test('loading the fallback locale itself asks for it once', () async {
      // No second read of the same file, and no merge of a map with itself.
      final loader = _RecordingLoader({
        'en': {'greeting': 'Hello'},
      });

      Translator.instance.setLoader(loader);
      Translator.instance.setFallbackLocale(const Locale('en'));
      await Translator.instance.load(const Locale('en'));

      expect(loader.asked, <String>['en']);
      expect(Translator.instance.get('greeting'), 'Hello');
    });

    test('a fallback that THROWS leaves the locale usable', () async {
      // The fallback is a courtesy, never a requirement: a broken fallback
      // catalogue must not take the locale's own strings down with it.
      //
      // The loader has to throw for this to mean anything. An earlier version
      // used a loader that simply had no `en` entry, which answers an empty
      // map, never enters the `catch`, and passes against a `Translator` with
      // no `try` in it at all.
      final loader = _RecordingLoader({
        'tr': {'greeting': 'Merhaba'},
      }, throwsFor: 'en');

      Translator.instance.setLoader(loader);
      Translator.instance.setFallbackLocale(const Locale('en'));
      await Translator.instance.load(const Locale('tr'));

      expect(Translator.instance.get('greeting'), 'Merhaba');
    });

    test('and does not need a bound logger to stay silent', () async {
      // The recovery path used to call `Log.warning` unguarded, and
      // `Magic.make` throws for an unbound key
      // (`foundation/application.dart:269-274`). So the handler itself threw
      // and the exception escaped `load()`, which is the exact outcome the
      // catch exists to prevent. `Magic.flush()` in `setUp` leaves `log`
      // unbound, which is the state a widget test using `LangDelegate` without
      // a full `Magic.init()` is in.
      expect(Magic.bound('log'), isFalse);

      final loader = _RecordingLoader({
        'tr': {'greeting': 'Merhaba'},
      }, throwsFor: 'en');

      Translator.instance.setLoader(loader);
      Translator.instance.setFallbackLocale(const Locale('en'));

      await expectLater(
        Translator.instance.load(const Locale('tr')),
        completes,
      );
      expect(Translator.instance.get('greeting'), 'Merhaba');
    });
  });
}
