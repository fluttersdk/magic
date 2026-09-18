import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// A navigation that arrives before the `Router` widget has parsed anything.
///
/// Written to settle a crash rather than to add coverage. On a real iPhone, in
/// a release build, tapping a push notification on a COLD start rendered the
/// destination and then turned the whole app into a flat grey page one second
/// later. `deeplink` breadcrumbs showed the link resolving and go_router
/// pushing `/incidents/:id`, and no `didPush` for the initial location before
/// it, which is the tell: the `Router` had not mounted yet.
///
/// The chain, all of it in go_router 17.3.0:
///
///   - `push` pushes onto `routerDelegate.currentConfiguration` (`router.dart:459`).
///   - Before the widget parses a location that is `RouteMatchList.empty`,
///     whose `uri` is a bare `Uri()` with an EMPTY path (`match.dart:531`).
///   - `RouteMatchList.copyWith` carries that uri onto the pushed list
///     (`match.dart:847`), so the delegate reports `location: ''`.
///   - The next dependency change decodes it and calls `findMatch` on the empty
///     path, where the matcher runs `''.substring(1)` and throws
///     (`match.dart:259`). Release replaces the Router subtree with an
///     `ErrorWidget`; debug asserts one line earlier, which is why no test and
///     no simulator run had ever seen it.
///
/// The assertion below is the whole chain in one line and needs no crash: with
/// a push onto an empty base the reported uri is empty, and an empty uri is
/// what every later match chokes on.
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

  testWidgets('a push before the router mounts still reports its location', (
    tester,
  ) async {
    MagicRoute.page('/', () => const SizedBox()).name('home');
    MagicRoute.page(
      '/incidents/:id',
      (String id) => const SizedBox(),
    ).name('incident').stacked();

    // Built, but never pumped: this is the state a cold start is in while the
    // app awaits its theme from the keychain, and it is exactly when a tapped
    // notification is replayed.
    final RouterConfig<Object> config = MagicRouter.instance.routerConfig;

    MagicRouter.instance.to('/incidents/inc-1');

    await tester.pumpWidget(MaterialApp.router(routerConfig: config));
    await tester.pumpAndSettle();

    // The DELEGATE's configuration, not `currentLocation`. The empty uri lives
    // on the match list; `currentLocation` reads the page state, which the pump
    // repairs, so asserting it passes without the fix. That version of this
    // test survived its own mutation, which is how a test comes to certify the
    // bug it was written for.
    final GoRouter router = config as GoRouter;

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/incidents/inc-1',
      reason:
          'a push onto an empty base keeps that empty uri, and every '
          'later match on it throws inside go_router',
    );
  });

  testWidgets('a push after the router mounts still stacks', (tester) async {
    // The other half, so the fix cannot be "always go". A stacked route
    // reached from a live router must still push, or back leaves the app.
    MagicRoute.page('/', () => const SizedBox()).name('home');
    MagicRoute.page(
      '/incidents/:id',
      (String id) => const SizedBox(),
    ).name('incident').stacked();

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
    );
    await tester.pumpAndSettle();

    MagicRouter.instance.to('/incidents/inc-1');
    await tester.pumpAndSettle();

    expect(MagicRouter.instance.currentLocation, '/incidents/inc-1');
    expect(
      GoRouter.of(tester.element(find.byType(SizedBox).last)).canPop(),
      isTrue,
      reason: 'the dashboard must still be underneath a stacked push',
    );
  });
}
