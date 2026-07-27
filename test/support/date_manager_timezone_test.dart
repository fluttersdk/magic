import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/facades/config.dart';
import 'package:magic/src/foundation/application.dart';
import 'package:magic/src/support/date_manager.dart';
import 'package:timezone/data/latest.dart' as tz;

/// The channel `flutter_timezone` talks to; faking it keeps these tests off a
/// real platform implementation while still exercising the plugin's own decode
/// path (a bare String is decoded into a `TimezoneInfo`).
const MethodChannel _timezoneChannel = MethodChannel('flutter_timezone');

/// Make the platform answer `getLocalTimezone` with [identifier].
void _mockPlatformTimezone(Object? identifier) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        _timezoneChannel,
        (MethodCall call) async => identifier,
      );
}

/// Remove the fake so the channel behaves as if the plugin were not
/// registered (the platform channel throws `MissingPluginException`).
void _clearPlatformTimezone() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_timezoneChannel, null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // detectPlatformTimezone() validates against the IANA database, which the
    // framework normally initializes in DateManager.boot().
    tz.initializeTimeZones();
  });

  setUp(() {
    DateManager.reset();
  });

  tearDown(() {
    _clearPlatformTimezone();
    DateManager.reset();
    MagicApp.reset();
  });

  group('DateManager.detectPlatformTimezone', () {
    test('returns the IANA identifier reported by the platform', () async {
      _mockPlatformTimezone('Pacific/Auckland');

      final String? detected =
          await DateManager.instance.detectPlatformTimezone();

      expect(detected, 'Pacific/Auckland');
      expect(DateManager.instance.detectTimezone(), 'Pacific/Auckland');
    });

    test('returns null for an identifier outside the IANA database', () async {
      _mockPlatformTimezone('Mars/Olympus_Mons');

      final String? detected =
          await DateManager.instance.detectPlatformTimezone();

      expect(detected, isNull);
    });

    test('returns null when the platform reports a blank identifier', () async {
      _mockPlatformTimezone('   ');

      expect(await DateManager.instance.detectPlatformTimezone(), isNull);
    });

    test('returns null when the platform channel is unavailable', () async {
      _clearPlatformTimezone();

      expect(await DateManager.instance.detectPlatformTimezone(), isNull);
    });
  });

  group('DateManager.detectTimezone', () {
    test('never guesses a zone from the UTC offset', () async {
      _mockPlatformTimezone('Mars/Olympus_Mons');
      await DateManager.instance.detectPlatformTimezone();

      final String? detected = DateManager.instance.detectTimezone();

      // Only two answers are legitimate: nothing, or the host's own zone name
      // when it happens to be a real identifier. Any city sharing the host's
      // current offset would be a guess.
      expect(
        detected,
        anyOf(isNull, equals(DateTime.now().timeZoneName)),
        reason:
            'detectTimezone() must not resolve an unknown platform zone to a '
            'plausible city; got "$detected"',
      );
    });
  });

  group('DateManager.boot with auto_detect_timezone', () {
    test('applies the platform identifier', () async {
      Config.set('localization.auto_detect_timezone', true);
      Config.set('localization.timezone', 'UTC');
      _mockPlatformTimezone('Pacific/Auckland');

      await DateManager.instance.boot();

      expect(DateManager.instance.timezoneName, 'Pacific/Auckland');
    });

    test('keeps the configured timezone when detection fails', () async {
      Config.set('localization.auto_detect_timezone', true);
      Config.set('localization.timezone', 'Asia/Tokyo');
      _mockPlatformTimezone('Mars/Olympus_Mons');

      await DateManager.instance.boot();

      // Booting must still complete: an undetectable device falls back to the
      // configured default, it does not fail initialization.
      expect(DateManager.instance.isBooted, isTrue);
      expect(
        DateManager.instance.timezoneName,
        anyOf('Asia/Tokyo', DateTime.now().timeZoneName),
        reason:
            'expected the configured default, got '
            '"${DateManager.instance.timezoneName}"',
      );
    });

    test('is ignored when auto-detection is disabled', () async {
      Config.set('localization.auto_detect_timezone', false);
      Config.set('localization.timezone', 'Asia/Tokyo');
      _mockPlatformTimezone('Pacific/Auckland');

      await DateManager.instance.boot();

      expect(DateManager.instance.timezoneName, 'Asia/Tokyo');
    });
  });

  group('DateManager UTC resolution', () {
    test('boot() does not throw when detection fails and the default is UTC',
        () async {
      // The regression: `timezone/data/latest.dart` has no database entry named
      // "UTC" (it ships `Etc/UTC`), so the UTC fallback inside
      // _setTimezoneInternal threw and escaped boot(). Detection now correctly
      // returns null when no platform answers, which makes that fallback the
      // path every such app takes, so a failed detection took application
      // startup down with it.
      _clearPlatformTimezone();
      Config.set('localization.auto_detect_timezone', true);
      Config.set('localization.timezone', 'UTC');

      await expectLater(DateManager.instance.boot(), completes);
      expect(DateManager.instance.timezoneName, 'UTC');
    });

    test('UTC is accepted as a valid timezone', () async {
      _clearPlatformTimezone();
      Config.set('localization.auto_detect_timezone', false);
      Config.set('localization.timezone', 'UTC');
      await DateManager.instance.boot();

      expect(DateManager.instance.timezoneName, 'UTC');

      // Setting it again must resolve rather than fall through the
      // "Invalid timezone" degradation path.
      DateManager.instance.setTimezone('UTC');

      expect(DateManager.instance.timezoneName, 'UTC');
    });

    test('an unresolvable zone degrades to UTC instead of throwing', () async {
      _clearPlatformTimezone();
      Config.set('localization.auto_detect_timezone', false);
      Config.set('localization.timezone', 'Nowhere/Imaginary');

      await expectLater(DateManager.instance.boot(), completes);
      expect(DateManager.instance.timezoneName, 'UTC');
    });
  });
}
