import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// Tests for [MagicRouter.currentRoute] — the public read-only accessor
/// that exposes the [RouteDefinition] resolved for the active location.
///
/// Contract (Plan Step 17, sub-change a):
/// 1. Returns null when no route has been resolved yet.
/// 2. Returns the [RouteDefinition] matched by the current location after navigation.
/// 3. Reactive across navigation — value updates as the active route changes.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    TitleManager.reset();
    MagicRouter.reset();
  });

  group('MagicRouter.currentRoute', () {
    test('returns null when no route has been resolved yet', () {
      // Fresh router, no widget tree pumped — _currentRoute is null.
      expect(MagicRouter.instance.currentRoute, isNull);
    });

    testWidgets('returns the RouteDefinition for the navigated location', (
      tester,
    ) async {
      final home = MagicRoute.page('/', () => const SizedBox()).name('home');
      final profile = MagicRoute.page(
        '/profile',
        () => const SizedBox(),
      ).name('profile');

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      // After initial route resolution, currentRoute is the '/' definition.
      expect(MagicRouter.instance.currentRoute, same(home));

      MagicRouter.instance.to('/profile');
      await tester.pumpAndSettle();

      // currentRoute now reflects the navigated definition.
      expect(MagicRouter.instance.currentRoute, same(profile));
    });

    testWidgets('updates reactively across multiple navigations', (
      tester,
    ) async {
      final home = MagicRoute.page('/', () => const SizedBox()).name('home');
      final about = MagicRoute.page('/about', () => const SizedBox());
      final contact = MagicRoute.page('/contact', () => const SizedBox());

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      expect(MagicRouter.instance.currentRoute, same(home));

      MagicRouter.instance.to('/about');
      await tester.pumpAndSettle();
      expect(MagicRouter.instance.currentRoute, same(about));

      MagicRouter.instance.to('/contact');
      await tester.pumpAndSettle();
      expect(MagicRouter.instance.currentRoute, same(contact));

      MagicRouter.instance.to('/about');
      await tester.pumpAndSettle();
      expect(MagicRouter.instance.currentRoute, same(about));
    });

    testWidgets('reset() clears currentRoute back to null', (tester) async {
      MagicRoute.page('/', () => const SizedBox());

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      expect(MagicRouter.instance.currentRoute, isNotNull);

      MagicRouter.reset();

      expect(MagicRouter.instance.currentRoute, isNull);
    });
  });
}
