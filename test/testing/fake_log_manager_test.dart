import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  tearDown(() {
    Log.unfake();
  });

  // ---------------------------------------------------------------------------
  // 1. Captures entries
  // ---------------------------------------------------------------------------

  group('captures entries', () {
    test('log() captures level and message', () {
      final fake = FakeLogManager();

      fake.driver().log('info', 'Hello world');

      expect(fake.entries, hasLength(1));
      expect(fake.entries.first.level, equals('info'));
      expect(fake.entries.first.message, equals('Hello world'));
    });

    test('info() is captured', () {
      final fake = FakeLogManager();

      fake.driver().info('Info message');

      expect(fake.entries.first.level, equals('info'));
      expect(fake.entries.first.message, equals('Info message'));
    });

    test('error() is captured', () {
      final fake = FakeLogManager();

      fake.driver().error('Error message');

      expect(fake.entries.first.level, equals('error'));
    });

    test('warning() is captured', () {
      final fake = FakeLogManager();

      fake.driver().warning('Warning message');

      expect(fake.entries.first.level, equals('warning'));
    });

    test('debug() is captured', () {
      final fake = FakeLogManager();

      fake.driver().debug('Debug message');

      expect(fake.entries.first.level, equals('debug'));
    });

    test('multiple entries accumulate', () {
      final fake = FakeLogManager();

      fake.driver().info('First');
      fake.driver().error('Second');
      fake.driver().debug('Third');

      expect(fake.entries, hasLength(3));
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Context preserved
  // ---------------------------------------------------------------------------

  group('context preserved', () {
    test('context map is recorded', () {
      final fake = FakeLogManager();

      fake.driver().info('User action', {'id': 42, 'action': 'login'});

      expect(fake.entries.first.context, isA<Map>());
      expect((fake.entries.first.context as Map)['id'], equals(42));
    });

    test('null context is recorded as null', () {
      final fake = FakeLogManager();

      fake.driver().info('No context');

      expect(fake.entries.first.context, isNull);
    });

    test('string context is recorded', () {
      final fake = FakeLogManager();

      fake.driver().error('Failed', 'some string context');

      expect(fake.entries.first.context, equals('some string context'));
    });
  });

  // ---------------------------------------------------------------------------
  // 3. All RFC 5424 levels
  // ---------------------------------------------------------------------------

  group('all RFC 5424 levels captured', () {
    test('emergency level is captured', () {
      final fake = FakeLogManager();
      fake.driver().emergency('System down');
      expect(fake.entries.first.level, equals('emergency'));
    });

    test('alert level is captured', () {
      final fake = FakeLogManager();
      fake.driver().alert('Immediate action');
      expect(fake.entries.first.level, equals('alert'));
    });

    test('critical level is captured', () {
      final fake = FakeLogManager();
      fake.driver().critical('Critical condition');
      expect(fake.entries.first.level, equals('critical'));
    });

    test('error level is captured', () {
      final fake = FakeLogManager();
      fake.driver().error('Runtime error');
      expect(fake.entries.first.level, equals('error'));
    });

    test('warning level is captured', () {
      final fake = FakeLogManager();
      fake.driver().warning('Deprecated usage');
      expect(fake.entries.first.level, equals('warning'));
    });

    test('notice level is captured', () {
      final fake = FakeLogManager();
      fake.driver().notice('Significant event');
      expect(fake.entries.first.level, equals('notice'));
    });

    test('info level is captured', () {
      final fake = FakeLogManager();
      fake.driver().info('Interesting event');
      expect(fake.entries.first.level, equals('info'));
    });

    test('debug level is captured', () {
      final fake = FakeLogManager();
      fake.driver().debug('Debug data');
      expect(fake.entries.first.level, equals('debug'));
    });
  });

  // ---------------------------------------------------------------------------
  // 4. assertLogged
  // ---------------------------------------------------------------------------

  group('assertLogged', () {
    test('passes when matching level and message exist', () {
      final fake = FakeLogManager();

      fake.driver().error('Payment failed');

      expect(
        () => fake.assertLogged('error', 'Payment failed'),
        returnsNormally,
      );
    });

    test('throws AssertionError when level does not match', () {
      final fake = FakeLogManager();

      fake.driver().info('Payment failed');

      expect(
        () => fake.assertLogged('error', 'Payment failed'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('throws AssertionError when message does not match', () {
      final fake = FakeLogManager();

      fake.driver().error('Something else');

      expect(
        () => fake.assertLogged('error', 'Payment failed'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('throws AssertionError when entries is empty', () {
      final fake = FakeLogManager();

      expect(
        () => fake.assertLogged('error', 'Any message'),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 5. assertLoggedError shorthand
  // ---------------------------------------------------------------------------

  group('assertLoggedError', () {
    test('passes when error message was logged', () {
      final fake = FakeLogManager();

      fake.driver().error('Database connection failed');

      expect(
        () => fake.assertLoggedError('Database connection failed'),
        returnsNormally,
      );
    });

    test('throws AssertionError when error message was not logged', () {
      final fake = FakeLogManager();

      fake.driver().info('Database connection failed');

      expect(
        () => fake.assertLoggedError('Database connection failed'),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 6. assertNothingLogged (no level filter)
  // ---------------------------------------------------------------------------

  group('assertNothingLogged', () {
    test('passes when no entries exist', () {
      final fake = FakeLogManager();

      expect(() => fake.assertNothingLogged(), returnsNormally);
    });

    test('throws AssertionError when entries exist', () {
      final fake = FakeLogManager();

      fake.driver().info('Something');

      expect(() => fake.assertNothingLogged(), throwsA(isA<AssertionError>()));
    });
  });

  // ---------------------------------------------------------------------------
  // 7. assertNothingLogged with level filter
  // ---------------------------------------------------------------------------

  group('assertNothingLogged with level', () {
    test('passes when no entries at specified level', () {
      final fake = FakeLogManager();

      fake.driver().info('Info message');

      expect(() => fake.assertNothingLogged('error'), returnsNormally);
    });

    test('throws AssertionError when entries exist at specified level', () {
      final fake = FakeLogManager();

      fake.driver().error('An error');

      expect(
        () => fake.assertNothingLogged('error'),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 8. assertLoggedCount
  // ---------------------------------------------------------------------------

  group('assertLoggedCount', () {
    test('passes when count matches exactly', () {
      final fake = FakeLogManager();

      fake.driver().info('One');
      fake.driver().error('Two');
      fake.driver().debug('Three');

      expect(() => fake.assertLoggedCount(3), returnsNormally);
    });

    test('throws AssertionError when count does not match', () {
      final fake = FakeLogManager();

      fake.driver().info('One');

      expect(() => fake.assertLoggedCount(2), throwsA(isA<AssertionError>()));
    });

    test('passes with zero when nothing was logged', () {
      final fake = FakeLogManager();

      expect(() => fake.assertLoggedCount(0), returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  // 9. reset()
  // ---------------------------------------------------------------------------

  group('reset()', () {
    test('clears all entries', () {
      final fake = FakeLogManager();

      fake.driver().info('Entry one');
      fake.driver().error('Entry two');
      fake.reset();

      expect(fake.entries, isEmpty);
    });

    test('after reset assertNothingLogged passes', () {
      final fake = FakeLogManager();

      fake.driver().error('Something');
      fake.reset();

      expect(() => fake.assertNothingLogged(), returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  // 10. Log.fake() — facade integration
  // ---------------------------------------------------------------------------

  group('Log.fake()', () {
    test('returns a FakeLogManager instance', () {
      final fake = Log.fake();

      expect(fake, isA<FakeLogManager>());
    });

    test('Log.info() routes through the fake', () {
      final fake = Log.fake();

      Log.info('User signed in');

      expect(fake.entries, hasLength(1));
      expect(fake.entries.first.level, equals('info'));
      expect(fake.entries.first.message, equals('User signed in'));
    });

    test('Log.error() is captured by fake', () {
      final fake = Log.fake();

      Log.error('Unhandled exception');

      fake.assertLoggedError('Unhandled exception');
    });

    test('Log.warning() is captured by fake', () {
      final fake = Log.fake();

      Log.warning('Deprecated API used');

      expect(fake.entries.first.level, equals('warning'));
    });

    test('Log.debug() is captured by fake', () {
      final fake = Log.fake();

      Log.debug('Query executed');

      expect(fake.entries.first.level, equals('debug'));
    });

    test('multiple facade calls accumulate entries', () {
      final fake = Log.fake();

      Log.info('First');
      Log.error('Second');

      fake.assertLoggedCount(2);
    });
  });

  // ---------------------------------------------------------------------------
  // 11. Log.channel()
  // ---------------------------------------------------------------------------

  group('Log.channel()', () {
    test('returns a LoggerDriver for the named channel', () {
      Log.fake();

      final driver = Log.channel('console');

      expect(driver, isA<LoggerDriver>());
    });

    test('channel driver can log messages', () {
      final fake = Log.fake();

      Log.channel('console').error('channel error');

      fake.assertLoggedError('channel error');
    });
  });

  // ---------------------------------------------------------------------------
  // 12. Log.unfake()
  // ---------------------------------------------------------------------------

  group('Log.unfake()', () {
    test('can be called without throwing', () {
      Log.fake();

      expect(() => Log.unfake(), returnsNormally);
    });

    test('can be called when not faked without throwing', () {
      expect(() => Log.unfake(), returnsNormally);
    });
  });
}
