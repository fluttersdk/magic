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
  });

  /// Pump a [MagicApplication] and let its async initializer settle.
  ///
  /// Registers a single `/` route by default so the underlying
  /// `MaterialApp.router` can build a valid GoRouter configuration.
  Future<void> pumpApp(
    WidgetTester tester, {
    String title = 'App',
    String? titleSuffix,
    String? titleSeparator,
    void Function()? onInit,
  }) async {
    await tester.pumpWidget(
      MagicApplication(
        title: title,
        titleSuffix: titleSuffix,
        titleSeparator: titleSeparator,
        onInit: onInit ?? () => MagicRoute.page('/', () => const SizedBox()),
      ),
    );

    // The initializer is async (loads theme preference, wires the title) and
    // the route guard schedules a zero-duration timer before revealing the
    // page; settle so no timers stay pending past the test body.
    await tester.pumpAndSettle();
  }

  group('MagicApplication — titleSeparator wiring', () {
    testWidgets('titleSeparator flows through to TitleManager', (tester) async {
      final titles = <String>[];
      TitleManager.configure(onTitleChanged: (title, _) => titles.add(title));

      await pumpApp(
        tester,
        title: 'App',
        titleSuffix: 'Site',
        titleSeparator: ' | ',
      );

      TitleManager.instance.setRouteTitle('Home');

      expect(TitleManager.instance.effectiveTitle, 'Home | Site');
    });

    testWidgets('separator falls back to " - " when param and config absent', (
      tester,
    ) async {
      final titles = <String>[];
      TitleManager.configure(onTitleChanged: (title, _) => titles.add(title));

      await pumpApp(tester, title: 'App', titleSuffix: 'Site');

      TitleManager.instance.setRouteTitle('Home');

      expect(TitleManager.instance.effectiveTitle, 'Home - Site');
    });

    testWidgets('separator falls back to config app.title_separator', (
      tester,
    ) async {
      Config.set('app.title_separator', ' :: ');
      final titles = <String>[];
      TitleManager.configure(onTitleChanged: (title, _) => titles.add(title));

      await pumpApp(tester, title: 'App', titleSuffix: 'Site');

      TitleManager.instance.setRouteTitle('Home');

      expect(TitleManager.instance.effectiveTitle, 'Home :: Site');
    });
  });

  group('MagicApplication — suffix config fallback', () {
    testWidgets('suffix falls back to config app.name when param is null', (
      tester,
    ) async {
      Config.set('app.name', 'ConfigApp');
      final titles = <String>[];
      TitleManager.configure(onTitleChanged: (title, _) => titles.add(title));

      await pumpApp(tester, title: 'App');

      TitleManager.instance.setRouteTitle('Home');

      expect(TitleManager.instance.effectiveTitle, 'Home - ConfigApp');
    });

    testWidgets('explicit titleSuffix wins over config app.name', (
      tester,
    ) async {
      Config.set('app.name', 'ConfigApp');
      final titles = <String>[];
      TitleManager.configure(onTitleChanged: (title, _) => titles.add(title));

      await pumpApp(tester, title: 'App', titleSuffix: 'ExplicitSuffix');

      TitleManager.instance.setRouteTitle('Home');

      expect(TitleManager.instance.effectiveTitle, 'Home - ExplicitSuffix');
    });
  });

  group('MagicApplication — locale change re-apply', () {
    testWidgets('a fired locale change re-applies the title', (tester) async {
      // The translator must be bound for the listener to attach.
      MagicApp.instance.singleton('translator', () => Translator.instance);
      Translator.instance.setLoader(const _FakeTranslationLoader({}));

      final titles = <String>[];
      TitleManager.configure(onTitleChanged: (title, _) => titles.add(title));

      await pumpApp(tester, title: 'App', titleSuffix: 'Site');
      TitleManager.instance.setRouteTitle('Home');
      titles.clear();

      await Lang.setLocale(const Locale('tr'), reload: false);

      expect(titles, isNotEmpty);
      expect(titles.last, 'Home - Site');
    });

    testWidgets('listener is removed on dispose (no leak)', (tester) async {
      MagicApp.instance.singleton('translator', () => Translator.instance);
      Translator.instance.setLoader(const _FakeTranslationLoader({}));

      final titles = <String>[];
      TitleManager.configure(onTitleChanged: (title, _) => titles.add(title));

      await pumpApp(tester, title: 'App', titleSuffix: 'Site');
      TitleManager.instance.setRouteTitle('Home');

      // Tear down MagicApplication — triggers _MagicApplicationState.dispose.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      titles.clear();

      // Firing a locale change now must NOT re-apply the title.
      await Lang.setLocale(const Locale('de'), reload: false);

      expect(titles, isEmpty);
    });

    testWidgets('listener does not attach when translator is unbound', (
      tester,
    ) async {
      // No translator binding registered.
      Translator.instance.setLoader(const _FakeTranslationLoader({}));

      final titles = <String>[];
      TitleManager.configure(onTitleChanged: (title, _) => titles.add(title));

      await pumpApp(tester, title: 'App', titleSuffix: 'Site');
      TitleManager.instance.setRouteTitle('Home');
      titles.clear();

      await Lang.setLocale(const Locale('tr'), reload: false);

      expect(titles, isEmpty);
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
