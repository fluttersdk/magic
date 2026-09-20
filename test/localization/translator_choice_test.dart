import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart' show Lang, Magic, MagicApp, transChoice;
import 'package:magic/src/localization/contracts/translation_loader.dart';
import 'package:magic/src/localization/translator.dart';

/// Serves one catalogue per language from a map.
class _MapLoader implements TranslationLoader {
  _MapLoader(this._locales);

  final Map<String, Map<String, dynamic>> _locales;

  @override
  Future<Map<String, dynamic>> load(Locale locale) async =>
      Map<String, dynamic>.from(
        _locales[locale.languageCode] ?? <String, dynamic>{},
      );
}

/// `choice`, which is `trans_choice` in Laravel.
///
/// The gap this closes: a sentence carrying a number rendered one wording at
/// every count, because `get` is a map lookup plus a `replaceAll` per
/// parameter and nothing parsed a pipe. That reads correctly in a language
/// with no plural agreement and not in one that has it, so it survives review
/// in any app whose first locale is Turkish, Japanese or Chinese.
void main() {
  group('Translator.choice', () {
    setUp(() {
      // `.claude/rules/tests.md:7` asks every setUp for these two.
      MagicApp.reset();
      Magic.flush();
      Translator.reset();
    });

    Future<void> loadEnglish() async {
      final loader = _MapLoader(<String, Map<String, dynamic>>{
        'en': <String, dynamic>{
          'apples': 'There is one apple|There are :count apples',
          'inbox':
              '{0} Nothing here|[1,19] :count messages|[20,*] Lots of messages',
          'plain': 'One sentence',
        },
      });

      Translator.instance.setLoader(loader);
      await Translator.instance.load(const Locale('en'));
    }

    test('picks the singular at one and the plural above it', () async {
      await loadEnglish();

      expect(Translator.instance.choice('apples', 1), 'There is one apple');
      expect(Translator.instance.choice('apples', 4), 'There are 4 apples');
    });

    test('substitutes :count without the caller passing it', () async {
      await loadEnglish();

      // Laravel does this, and it is what makes the feature usable: a caller
      // that had to pass `{'count': n}` beside the `n` it already passed
      // would get them out of step eventually.
      expect(Translator.instance.choice('apples', 12), 'There are 12 apples');
    });

    test('an explicit replacement still wins over the count', () async {
      await loadEnglish();

      expect(
        Translator.instance.choice('apples', 4, <String, dynamic>{
          'count': 'four',
        }),
        'There are four apples',
      );
    });

    test('honours inline ranges', () async {
      await loadEnglish();

      expect(Translator.instance.choice('inbox', 0), 'Nothing here');
      expect(Translator.instance.choice('inbox', 7), '7 messages');
      expect(Translator.instance.choice('inbox', 99), 'Lots of messages');
    });

    test('a line with no pipe is returned whole', () async {
      await loadEnglish();

      expect(Translator.instance.choice('plain', 5), 'One sentence');
    });

    test('a missing key answers the key, as get does', () async {
      await loadEnglish();

      // Not an empty string and not a throw: `get`'s own contract, so a
      // caller switching between the two meets one behaviour.
      expect(Translator.instance.choice('nothing.here', 3), 'nothing.here');
    });

    test('the locale decides the index, not the caller', () async {
      final loader = _MapLoader(<String, Map<String, dynamic>>{
        'tr': <String, dynamic>{'channels': ':count kanal|:count kanallar'},
        'en': <String, dynamic>{'channels': ':count channel|:count channels'},
      });

      Translator.instance.setLoader(loader);

      await Translator.instance.load(const Locale('tr'));
      // Turkish has one form, so the second segment is unreachable whatever
      // the count. This is the assertion that fails if `choice` hardcodes the
      // English rule, which is the shape every hand-rolled version takes.
      expect(Translator.instance.choice('channels', 9), '9 kanal');

      await Translator.instance.load(const Locale('en'));
      expect(Translator.instance.choice('channels', 9), '9 channels');
      expect(Translator.instance.choice('channels', 1), '1 channel');
    });

    test('the key falls back per locale, as get does', () async {
      final loader = _MapLoader(<String, Map<String, dynamic>>{
        'en': <String, dynamic>{'only.english': 'one|:count many'},
        'tr': <String, dynamic>{},
      });

      Translator.instance.setLoader(loader);
      Translator.instance.setFallbackLocale(const Locale('en'));
      await Translator.instance.load(const Locale('tr'));

      // The fallback catalogue is merged into `_sentences`, so `choice` reads
      // the English line and then applies TURKISH's index to it. One form, so
      // segment 0, which is the honest answer: the sentence is missing, and
      // inventing an English plural rule for a Turkish screen would be worse.
      expect(Translator.instance.choice('only.english', 5), 'one');
    });
  });

  group('the facade and the helper', () {
    setUp(() async {
      MagicApp.reset();
      Magic.flush();
      Translator.reset();

      Translator.instance.setLoader(
        _MapLoader(<String, Map<String, dynamic>>{
          'en': <String, dynamic>{'apples': 'one apple|:count apples'},
        }),
      );
      await Translator.instance.load(const Locale('en'));
    });

    test('Lang.choice delegates to the translator', () {
      expect(Lang.choice('apples', 1), 'one apple');
      expect(Lang.choice('apples', 3), '3 apples');
    });

    test('transChoice is the global helper', () {
      expect(transChoice('apples', 1), 'one apple');
      expect(transChoice('apples', 3), '3 apples');
    });
  });
}
