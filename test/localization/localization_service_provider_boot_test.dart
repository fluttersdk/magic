import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/facades/config.dart';
import 'package:magic/src/foundation/application.dart';
import 'package:magic/src/foundation/magic.dart';
import 'package:magic/src/localization/localization_service_provider.dart';
import 'package:magic/src/localization/translator.dart';
import 'package:magic/src/support/date_manager.dart';
import 'package:magic/src/testing/magic_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalizationServiceProvider boots the date runtime', () {
    tearDown(() {
      Magic.flush();
      MagicApp.reset();
      Translator.reset();
      DateManager.reset();
    });

    /// Bring up a container with the log service bound (the provider logs), then
    /// hand back a fresh, unbooted DateManager so this test controls the
    /// pre-state rather than inheriting whatever init left behind.
    Future<LocalizationServiceProvider> arrange(String timezone) async {
      await MagicTest.boot(configs: const []);
      DateManager.reset();
      Translator.reset();

      Config.set('localization.auto_detect_timezone', false);
      Config.set('localization.timezone', timezone);
      Config.set('localization.auto_detect_locale', false);
      Config.set('localization.locale', 'en');

      final LocalizationServiceProvider provider =
          LocalizationServiceProvider(MagicApp.instance);
      provider.register();

      return provider;
    }

    test('DateManager is booted so the X-Timezone header has a real value',
        () async {
      // Nothing in the framework used to boot DateManager, so the IANA database
      // stayed uninitialized, `localization.timezone` had no effect, and the
      // LocalizationInterceptor's X-Timezone header reported the unbooted
      // default. Every consumer had to call DateManager.boot() by hand.
      final LocalizationServiceProvider provider =
          await arrange('Asia/Tokyo');
      expect(DateManager.instance.isBooted, isFalse);

      await provider.boot();

      expect(DateManager.instance.isBooted, isTrue);
      expect(DateManager.instance.timezoneName, 'Asia/Tokyo');
    });

    test('boot() survives an unresolvable configured timezone', () async {
      // Booting must not be able to fail application startup: an unresolvable
      // zone degrades to UTC rather than throwing out of the provider.
      final LocalizationServiceProvider provider =
          await arrange('Nowhere/Imaginary');

      await expectLater(provider.boot(), completes);

      expect(DateManager.instance.timezoneName, 'UTC');
    });
  });
}
