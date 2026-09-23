import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// A stacked route owns the address it is shown at.
///
/// `.stacked()` makes `to()` PUSH, and go_router reports a pushed page to the
/// engine under the address of the page BELOW it unless
/// `GoRouter.optionURLReflectsImperativeAPIs` is on. On the web that is the
/// browser's address bar: opening a detail screen left it reading the list's
/// URL, so the page could not be copied, shared or reloaded.
///
/// What the router hands the engine is `restoreRouteInformation` over the
/// delegate's current configuration, so that is what these read, rather than
/// the flag: a test that only asserted the flag would pass on a router that
/// was built before it was set.
void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    TitleManager.reset();
    MagicRouter.reset();
    // Start from go_router's own default, so a pass is the router's doing.
    GoRouter.optionURLReflectsImperativeAPIs = false;
  });

  Future<void> pumpRouter(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
    );
    await tester.pumpAndSettle();
  }

  String reportedPath() {
    final GoRouter router = MagicRouter.instance.routerConfig;
    final RouteInformation? information = router.routeInformationParser
        .restoreRouteInformation(router.routerDelegate.currentConfiguration);

    return information!.uri.path;
  }

  testWidgets('a pushed stacked route reports its own address', (tester) async {
    MagicRoute.page('/', () => const SizedBox());
    MagicRoute.page('/monitors', () => const SizedBox());
    MagicRoute.page('/monitors/:id', (id) => const SizedBox()).stacked();
    await pumpRouter(tester);

    MagicRoute.to('/monitors');
    await tester.pumpAndSettle();
    MagicRoute.to('/monitors/42');
    await tester.pumpAndSettle();

    expect(reportedPath(), '/monitors/42');
  });

  testWidgets('a stacked route inside a layout reports its own address', (
    tester,
  ) async {
    // A layout is a shell, and go_router has to drill through it to find the
    // push: the case its own drill-down exists for.
    MagicRoute.page('/', () => const SizedBox());
    MagicRoute.layout(
      builder: (Widget child) => child,
      routes: [
        MagicRoute.page('/incidents', () => const SizedBox()),
        MagicRoute.page('/incidents/:id', (id) => const SizedBox()).stacked(),
      ],
    );
    await pumpRouter(tester);

    MagicRoute.to('/incidents');
    await tester.pumpAndSettle();
    MagicRoute.to('/incidents/7');
    await tester.pumpAndSettle();

    expect(reportedPath(), '/incidents/7');
  });

  testWidgets('back reports the page underneath again', (tester) async {
    MagicRoute.page('/', () => const SizedBox());
    MagicRoute.page('/monitors', () => const SizedBox());
    MagicRoute.page('/monitors/:id', (id) => const SizedBox()).stacked();
    await pumpRouter(tester);

    MagicRoute.to('/monitors');
    await tester.pumpAndSettle();
    MagicRoute.to('/monitors/42');
    await tester.pumpAndSettle();
    MagicRoute.back();
    await tester.pumpAndSettle();

    expect(reportedPath(), '/monitors');
  });
}
