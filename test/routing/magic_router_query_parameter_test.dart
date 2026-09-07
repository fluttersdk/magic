import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// Tests for [MagicRouter.queryParameter] and [MagicRouter.queryParameters].
///
/// Written to settle a report rather than to add coverage. A consumer put a
/// query parameter on a route, read it back through `queryParameter`, got
/// null, and filed it against this package. The evidence turned out to be a
/// misreading: the value they were looking at came from `dusk:get_routes`,
/// whose `location` is `route.settings.name` off the Navigator (the declared
/// path pattern) rather than anything this router exposes.
///
/// So these pin what the router actually promises, both ways a caller can put
/// a query on a location: the `queryParameters` argument, and inline in the
/// path string, which is the shape `MagicRoute.to('/?scale=5000')` produces
/// and the one the report used.
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

  group('MagicRouter.queryParameter', () {
    testWidgets('reads a parameter passed through queryParameters', (
      tester,
    ) async {
      MagicRoute.page('/', () => const SizedBox()).name('home');

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      MagicRouter.instance.to('/', queryParameters: {'scale': '5000'});
      await tester.pumpAndSettle();

      expect(MagicRouter.instance.queryParameter('scale'), '5000');
    });

    testWidgets('reads a parameter written inline in the path', (tester) async {
      MagicRoute.page('/', () => const SizedBox()).name('home');

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      MagicRouter.instance.to('/?scale=5000');
      await tester.pumpAndSettle();

      expect(MagicRouter.instance.queryParameter('scale'), '5000');
    });

    testWidgets('is null for a key the location does not carry', (
      tester,
    ) async {
      MagicRoute.page('/', () => const SizedBox()).name('home');

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      MagicRouter.instance.to('/?scale=5000');
      await tester.pumpAndSettle();

      expect(MagicRouter.instance.queryParameter('missing'), isNull);
    });

    testWidgets('clears when a later navigation carries no query', (
      tester,
    ) async {
      MagicRoute.page('/', () => const SizedBox()).name('home');
      MagicRoute.page('/profile', () => const SizedBox()).name('profile');

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      MagicRouter.instance.to('/?scale=5000');
      await tester.pumpAndSettle();
      expect(MagicRouter.instance.queryParameter('scale'), '5000');

      // The query belongs to the LOCATION, not to the session: navigating
      // somewhere without one has to clear it rather than leave a stale value
      // a caller would read as still current.
      MagicRouter.instance.to('/profile');
      await tester.pumpAndSettle();
      expect(MagicRouter.instance.queryParameter('scale'), isNull);
    });
  });

  group('MagicRouter.queryParameters', () {
    testWidgets('exposes every parameter on the location', (tester) async {
      MagicRoute.page('/', () => const SizedBox()).name('home');

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      MagicRouter.instance.to('/?scale=5000&width=1440');
      await tester.pumpAndSettle();

      expect(MagicRouter.instance.queryParameters, {
        'scale': '5000',
        'width': '1440',
      });
    });

    test('is empty rather than null before any route resolves', () {
      expect(MagicRouter.instance.queryParameters, isEmpty);
    });
  });

  group('Request, which is how a consumer reaches these', () {
    testWidgets('query and queryParams delegate to the router', (tester) async {
      MagicRoute.page('/', () => const SizedBox()).name('home');

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      MagicRouter.instance.to('/?scale=5000&width=1440');
      await tester.pumpAndSettle();

      // One line each (`request.dart:72` and `:83`), so this is not really
      // testing logic. It is testing that the facade an app reads through is
      // wired to the accessor above, which is the pairing the original report
      // was about and the one nothing covered.
      expect(Request.query('scale'), '5000');
      expect(Request.queryParams, {'scale': '5000', 'width': '1440'});
    });
  });
}
