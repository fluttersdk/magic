import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    // Resets the built GoRouter (and TitleManager) so each test can register
    // its own routes into a fresh router before build.
    MagicRouter.reset();
    Translator.reset();

    Config.set('localization.locale', 'en');
    Config.set('localization.supported_locales', ['en', 'tr', 'de']);
  });

  /// Bind the translator with a loader that never touches the asset bundle.
  ///
  /// Mirrors what `LocalizationServiceProvider.register()` does, minus the
  /// boot-time load, so a test starts with "translator bound, no runtime
  /// locale loaded yet".
  void bindTranslator() {
    MagicApp.instance.singleton('translator', () => Translator.instance);
    Translator.instance.setLoader(const _FakeTranslationLoader({}));
  }

  /// Pump a [MagicApplication] and let its async initializer settle.
  Future<void> pumpApp(WidgetTester tester, {Locale? locale}) async {
    await tester.pumpWidget(
      MagicApplication(
        title: 'App',
        locale: locale,
        onInit: () => MagicRoute.page('/', () => const SizedBox()),
      ),
    );

    // The initializer is async (loads theme preference, wires the title) and
    // the route guard schedules a zero-duration timer before revealing the
    // page; settle so no timers stay pending past the test body.
    await tester.pumpAndSettle();
  }

  /// Read the locale off the rendered [MaterialApp].
  ///
  /// Asserting on `Lang.current` instead would pass without the fix, since the
  /// translator holds the new locale either way; the whole point is whether it
  /// reaches the widget tree.
  Locale? renderedLocale(WidgetTester tester) {
    return tester.widget<MaterialApp>(find.byType(MaterialApp)).locale;
  }

  group('MagicApplication: runtime locale', () {
    testWidgets('the rendered locale follows a runtime Lang.setLocale', (
      tester,
    ) async {
      bindTranslator();

      await pumpApp(tester);
      expect(renderedLocale(tester), const Locale('en'));

      await Lang.setLocale(const Locale('tr'), reload: false);
      await tester.pumpAndSettle();

      expect(renderedLocale(tester), const Locale('tr'));
    });

    testWidgets('the runtime locale survives a later rebuild', (tester) async {
      bindTranslator();

      await pumpApp(tester);
      await Lang.setLocale(const Locale('tr'), reload: false);
      await tester.pumpAndSettle();

      // A soft restart is the widest rebuild the framework performs; the
      // locale must not revert to the static config value.
      Magic.reload();
      await tester.pumpAndSettle();

      expect(renderedLocale(tester), const Locale('tr'));
    });

    testWidgets('setLocale with reload:true also lands the locale', (
      tester,
    ) async {
      bindTranslator();

      await pumpApp(tester);
      await Lang.setLocale(const Locale('de'));
      await tester.pumpAndSettle();

      expect(renderedLocale(tester), const Locale('de'));
    });

    testWidgets('an explicit locale still wins over the runtime locale', (
      tester,
    ) async {
      bindTranslator();

      await pumpApp(tester, locale: const Locale('de'));
      expect(renderedLocale(tester), const Locale('de'));

      await Lang.setLocale(const Locale('tr'), reload: false);
      await tester.pumpAndSettle();

      expect(renderedLocale(tester), const Locale('de'));
    });

    testWidgets('falls back to the config locale while nothing is loaded', (
      tester,
    ) async {
      Config.set('localization.locale', 'de');
      bindTranslator();

      await pumpApp(tester);

      expect(renderedLocale(tester), const Locale('de'));
    });

    testWidgets('an unbound translator keeps the config locale', (
      tester,
    ) async {
      // No translator binding: the localization stack is not installed.
      Translator.instance.setLoader(const _FakeTranslationLoader({}));

      await pumpApp(tester);
      await Lang.setLocale(const Locale('tr'), reload: false);
      await tester.pumpAndSettle();

      expect(renderedLocale(tester), const Locale('en'));
    });

    testWidgets('a locale change after teardown does not throw', (
      tester,
    ) async {
      bindTranslator();

      await pumpApp(tester);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // The rebuild subscription must be gone with the tree; a surviving one
      // would setState (or notify) into a disposed element.
      await Lang.setLocale(const Locale('tr'), reload: false);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('the title still re-applies on a locale change', (
      tester,
    ) async {
      bindTranslator();

      final titles = <String>[];
      TitleManager.configure(onTitleChanged: (title, _) => titles.add(title));
      Config.set('app.name', 'Site');

      await pumpApp(tester);
      TitleManager.instance.setRouteTitle('Home');
      titles.clear();

      await Lang.setLocale(const Locale('tr'), reload: false);
      await tester.pumpAndSettle();

      expect(titles, isNotEmpty);
      expect(titles.last, 'Home - Site');
    });
  });
}

/// Test double feeding a fixed sentence map to the [Translator].
///
/// Keeps [Translator.load] from hitting the asset bundle so locale switches
/// can be exercised in isolation.
class _FakeTranslationLoader implements TranslationLoader {
  const _FakeTranslationLoader(this._sentences);

  final Map<String, dynamic> _sentences;

  @override
  Future<Map<String, dynamic>> load(Locale locale) async => _sentences;
}
