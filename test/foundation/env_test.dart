import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

void main() {
  group('Env', () {
    setUp(() async {
      // `Env.load()` fails to find a bundled `.env` asset under the test
      // runner, which is fine: the catch branch still flips `_isLoaded` to
      // true, so `Env.get` reaches the real `dotenv` instance instead of
      // falling back to the (empty) fallback map. Repopulate `dotenv`
      // directly afterwards so the test exercises the real parser, not a
      // stub of it.
      await Env.load();
    });

    tearDown(() {
      Env.reset();
    });

    test(
      'get() treats a double-quote-only value as empty, not the default',
      () {
        dotenv.loadFromString(envString: 'KEY=""');

        expect(env('KEY', 'd'), '');
      },
    );

    test(
      'get() treats a single-quote-only value as empty, not the default',
      () {
        dotenv.loadFromString(envString: "KEY=''");

        expect(env('KEY', 'd'), '');
      },
    );

    test('get() treats a blank value as empty, not the default', () {
      dotenv.loadFromString(envString: 'KEY=');

      expect(env('KEY', 'd'), '');
    });

    test('filled() falls back to the default when the key is absent', () {
      dotenv.loadFromString(envString: 'OTHER=x');

      expect(Env.filled('KEY', 'd'), 'd');
    });

    test('filled() falls back to the default for a blank value', () {
      dotenv.loadFromString(envString: 'KEY=');

      expect(Env.filled('KEY', 'd'), 'd');
    });

    test(
      'filled() falls back to the default for a double-quote-only value',
      () {
        dotenv.loadFromString(envString: 'KEY=""');

        expect(Env.filled('KEY', 'd'), 'd');
      },
    );

    test('filled() falls back to the default for a whitespace-only value', () {
      dotenv.loadFromString(envString: 'KEY="  "');

      expect(Env.filled('KEY', 'd'), 'd');
    });

    test(
      'filled() strips one wrapping quote pair and keeps an inner apostrophe',
      () {
        dotenv.loadFromString(envString: 'K="Anıl\'s Monitor"');

        expect(Env.filled('K', 'd'), "Anıl's Monitor");
      },
    );

    test('getOrFail() throws StateError for an absent key', () {
      dotenv.loadFromString(envString: 'OTHER=x');

      expect(
        () => Env.getOrFail('MISSING'),
        throwsA(
          isA<StateError>().having(
            (StateError e) => e.message,
            'message',
            'Environment variable [MISSING] has no value.',
          ),
        ),
      );
    });

    test(
      'getOrFail() returns an empty string for a present but empty value',
      () {
        dotenv.loadFromString(envString: 'KEY=');

        expect(Env.getOrFail('KEY'), '');
      },
    );
  });
}
