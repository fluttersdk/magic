import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart' show MagicApp, Magic;
import 'package:magic/src/localization/contracts/translation_loader.dart';
import 'package:magic/src/localization/translator.dart';
import 'package:magic/src/support/carbon.dart';

/// A loader that returns exactly the flat, already-dotted keys it is given,
/// so a test can seed the translator without going through JSON nesting.
class _FlatLoader implements TranslationLoader {
  const _FlatLoader(this._locales);

  final Map<String, Map<String, String>> _locales;

  @override
  Future<Map<String, dynamic>> load(Locale locale) async {
    return Map<String, dynamic>.from(_locales[locale.languageCode] ?? {});
  }
}

void main() {
  group('Carbon.shortDiffForHumans', () {
    setUp(() {
      MagicApp.reset();
      Magic.flush();
      Translator.reset();
    });

    tearDown(() {
      Carbon.setTestNow();
      Translator.reset();
    });

    test('T-14 min reads "14m ago" with no catalogue loaded', () {
      final t = Carbon.create(year: 2024, month: 3, day: 15, hour: 10);
      Carbon.setTestNow(t);

      final event = t.subMinutes(14);
      expect(event.shortDiffForHumans(), '14m ago');
    });

    test('T-2 h reads "2h ago"', () {
      final t = Carbon.create(year: 2024, month: 3, day: 15, hour: 10);
      Carbon.setTestNow(t);

      final event = t.subHours(2);
      expect(event.shortDiffForHumans(), '2h ago');
    });

    test('T-45 d reads "1mo ago" (30-day months, truncated)', () {
      final t = Carbon.create(year: 2024, month: 3, day: 15, hour: 10);
      Carbon.setTestNow(t);

      final event = t.subDays(45);
      expect(event.shortDiffForHumans(), '1mo ago');
    });

    test('T+5 min reads "5m from now"', () {
      final t = Carbon.create(year: 2024, month: 3, day: 15, hour: 10);
      Carbon.setTestNow(t);

      final event = t.addMinutes(5);
      expect(event.shortDiffForHumans(), '5m from now');
    });

    test('T-0.5 s reads "Just now"', () {
      final t = Carbon.create(year: 2024, month: 3, day: 15, hour: 10);
      Carbon.setTestNow(t);

      final event = t.subtract(const Duration(milliseconds: 500));
      expect(event.shortDiffForHumans(), 'Just now');
    });

    test('T-10 d reads "1w ago"', () {
      final t = Carbon.create(year: 2024, month: 3, day: 15, hour: 10);
      Carbon.setTestNow(t);

      final event = t.subDays(10);
      expect(event.shortDiffForHumans(), '1w ago');
    });

    test('measures against an explicit other rather than the clock', () {
      // No frozen clock at all; the reference is the explicit `other`.
      final reference = Carbon.create(year: 2024, month: 3, day: 15, hour: 10);
      final event = reference.subMinutes(14);

      expect(event.shortDiffForHumans(reference), '14m ago');
    });

    test(
      'a Turkish catalogue localizes both the unit and the wrapper',
      () async {
        Translator.instance.setLoader(
          const _FlatLoader({
            'tr': {
              'time.units_short.minute': ':count dk',
              'time.ago': ':time önce',
            },
          }),
        );
        Translator.instance.setFallbackLocale(const Locale('en'));
        await Translator.instance.load(const Locale('tr'));

        final t = Carbon.create(year: 2024, month: 3, day: 15, hour: 10);
        Carbon.setTestNow(t);

        final event = t.subMinutes(14);
        expect(event.shortDiffForHumans(), '14 dk önce');
      },
    );
  });
}
