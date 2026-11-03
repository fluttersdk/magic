import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// A route declared with `.overlay(base:)` opens as a bottom sheet over a page.
///
/// The overlay's path deliberately does not extend its base (`/items/new` over
/// `/stock`): the base is whatever the declaration names, never a path prefix
/// the router guesses.
void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    TitleManager.reset();
    MagicRouter.reset();
    Kernel.flush();
    Log.fake();
    _StockPage.mountCount = 0;
    _ProbeMiddleware.handled = 0;
    _AllowMiddleware.handled = 0;
  });

  Future<void> pumpRouter(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
    );
    await tester.pumpAndSettle();
  }

  RouteInformation reportedInformation() {
    final GoRouter router = MagicRouter.instance.routerConfig;

    return router.routeInformationParser.restoreRouteInformation(
      router.routerDelegate.currentConfiguration,
    )!;
  }

  /// What the engine hands back on a browser Back: the entry it stored.
  Future<void> browserBackTo(
    WidgetTester tester,
    RouteInformation entry,
  ) async {
    await MagicRouter.instance.routerConfig.routeInformationProvider
        .didPushRouteInformation(entry);
    await tester.pumpAndSettle();
  }

  ModalRoute<dynamic> sheetRoute(WidgetTester tester) {
    return ModalRoute.of(tester.element(find.text('sheet')))!;
  }

  ModalRoute<dynamic> stockRoute(WidgetTester tester) {
    return ModalRoute.of(
      tester.element(find.byType(_StockPage, skipOffstage: false)),
    )!;
  }

  void registerStock({bool Function()? canDismiss}) {
    MagicRoute.page('/', () => const Text('home'));
    MagicRoute.page('/stock', () => const _StockPage()).title('Stock');
    MagicRoute.page(
      '/items/new',
      () => const SizedBox(
        width: double.infinity,
        height: 200,
        child: Text('sheet'),
      ),
    ).title('New item').overlay(base: '/stock', canDismiss: canDismiss);
  }

  group('to() over a page', () {
    testWidgets('pushes the overlay and back returns to the page intact', (
      tester,
    ) async {
      registerStock();
      MagicRouter.instance.setInitialLocation('/stock');
      await pumpRouter(tester);

      await tester.tap(find.text('count 0'));
      await tester.pump();

      MagicRoute.to('/items/new');
      await tester.pumpAndSettle();

      expect(find.text('sheet'), findsOneWidget);
      expect(sheetRoute(tester).isCurrent, isTrue);
      expect(
        stockRoute(tester).isActive,
        isTrue,
        reason: 'the page stays on the stack under the overlay',
      );
      expect(reportedInformation().uri.path, '/items/new');

      MagicRoute.back();
      await tester.pumpAndSettle();

      expect(find.text('sheet'), findsNothing);
      expect(find.text('count 1'), findsOneWidget);
      expect(_StockPage.mountCount, 1);
      expect(reportedInformation().uri.path, '/stock');
    });

    testWidgets('browser back closes the overlay and keeps the page', (
      tester,
    ) async {
      registerStock();
      MagicRouter.instance.setInitialLocation('/stock');
      await pumpRouter(tester);
      await tester.tap(find.text('count 0'));
      await tester.pump();
      final RouteInformation stockEntry = reportedInformation();

      MagicRoute.to('/items/new');
      await tester.pumpAndSettle();
      await browserBackTo(tester, stockEntry);

      expect(find.text('sheet'), findsNothing);
      expect(find.text('count 1'), findsOneWidget);
      expect(_StockPage.mountCount, 1);
    });
  });

  group('cold entry', () {
    testWidgets('an initial location on the overlay builds the base first', (
      tester,
    ) async {
      registerStock();
      MagicRouter.instance.setInitialLocation('/items/new');
      await pumpRouter(tester);

      expect(find.text('sheet'), findsOneWidget);
      expect(stockRoute(tester).isActive, isTrue);
      expect(reportedInformation().uri.path, '/items/new');

      MagicRoute.back();
      await tester.pumpAndSettle();

      expect(find.text('sheet'), findsNothing);
      expect(find.text('count 0'), findsOneWidget);
      expect(MagicRouter.instance.currentPath, '/stock');
    });

    testWidgets('go() to the overlay replaces the stack with base + overlay', (
      tester,
    ) async {
      registerStock();
      await pumpRouter(tester);
      expect(find.text('home'), findsOneWidget);

      MagicRouter.instance.routerConfig.go('/items/new?sku=42');
      await tester.pumpAndSettle();

      expect(find.text('sheet'), findsOneWidget);
      expect(find.text('home', skipOffstage: false), findsNothing);
      expect(stockRoute(tester).isActive, isTrue);
      expect(reportedInformation().uri.toString(), '/items/new?sku=42');
    });

    testWidgets('a base that is not a registered route fails at boot', (
      tester,
    ) async {
      MagicRoute.page('/', () => const Text('home'));
      MagicRoute.page(
        '/items/new',
        () => const Text('sheet'),
      ).overlay(base: '/stok');

      expect(
        () => MagicRouter.instance.routerConfig,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('/items/new'), contains('/stok')),
          ),
        ),
      );
    });
  });

  group('presentation', () {
    testWidgets('a layout does not swallow the overlay', (tester) async {
      const Key shell = Key('shell');
      MagicRoute.page('/', () => const Text('home'));
      MagicRoute.group(
        layout: (child) => KeyedSubtree(key: shell, child: child),
        routes: () {
          MagicRoute.page('/stock', () => const _StockPage());
          MagicRoute.page(
            '/items/new',
            () => const Text('sheet'),
          ).overlay(base: '/stock');
        },
      );
      MagicRouter.instance.setInitialLocation('/stock');
      await pumpRouter(tester);

      MagicRoute.to('/items/new');
      await tester.pumpAndSettle();

      expect(find.text('sheet'), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(shell), matching: find.text('sheet')),
        findsNothing,
      );
      expect(
        sheetRoute(tester).navigator,
        MagicRouter.instance.navigatorKey.currentState,
      );
    });

    testWidgets('the frame is the one showModalBottomSheet builds for '
        'MSBottomSheet', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final Finder sheetSurface = find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Material),
          )
          .first;
      registerStock();
      MagicRouter.instance.setInitialLocation('/stock');
      await pumpRouter(tester);

      // The reference: the exact call `MSBottomSheet.show` makes.
      showModalBottomSheet<void>(
        context: tester.element(find.byType(_StockPage)),
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        useRootNavigator: true,
        builder: (_) => const SizedBox(
          width: double.infinity,
          height: 200,
          child: Text('reference'),
        ),
      );
      await tester.pumpAndSettle();
      final reference =
          ModalRoute.of(tester.element(find.text('reference')))!
              as ModalBottomSheetRoute<dynamic>;
      final Size referenceSize = tester.getSize(sheetSurface);
      Navigator.of(tester.element(find.text('reference'))).pop();
      await tester.pumpAndSettle();

      MagicRoute.to('/items/new');
      await tester.pumpAndSettle();

      final ModalRoute<dynamic> route = sheetRoute(tester);
      expect(route, isA<ModalBottomSheetRoute<dynamic>>());
      final sheet = route as ModalBottomSheetRoute<dynamic>;
      expect(sheet.backgroundColor, Colors.transparent);
      expect(sheet.isScrollControlled, isTrue);
      expect(sheet.useSafeArea, isFalse);
      expect(sheet.showDragHandle, isNull);
      expect(sheet.constraints, isNull);
      expect(sheet.isDismissible, reference.isDismissible);
      expect(sheet.enableDrag, reference.enableDrag);
      expect(sheet.barrierLabel, reference.barrierLabel);
      expect(sheet.barrierOnTapHint, reference.barrierOnTapHint);
      expect(sheet.modalBarrierColor, reference.modalBarrierColor);
      expect(sheet.elevation, reference.elevation);
      expect(sheet.shape, reference.shape);
      expect(sheet.clipBehavior, reference.clipBehavior);
      expect(
        sheet.scrollControlDisabledMaxHeightRatio,
        reference.scrollControlDisabledMaxHeightRatio,
      );
      // Material 3's default `maxWidth: 640`, which a `constraints` would
      // have replaced.
      expect(tester.getSize(sheetSurface).width, 640);
      expect(tester.getSize(sheetSurface), referenceSize);
    });
  });

  group('dismiss guard', () {
    late bool allowed;

    Future<void> openGuarded(WidgetTester tester) async {
      allowed = false;
      registerStock(canDismiss: () => allowed);
      MagicRouter.instance.setInitialLocation('/stock');
      await pumpRouter(tester);
      MagicRoute.to('/items/new');
      await tester.pumpAndSettle();
      expect(find.text('sheet'), findsOneWidget);
    }

    void expectStillOpen(WidgetTester tester) {
      expect(find.text('sheet'), findsOneWidget);
      expect(sheetRoute(tester), isA<ModalBottomSheetRoute<dynamic>>());
      expect(sheetRoute(tester).isCurrent, isTrue);
      expect(sheetRoute(tester).animation!.value, 1.0);
    }

    Future<void> expectClosesOnceAllowed(WidgetTester tester) async {
      allowed = true;
      MagicRoute.back();
      await tester.pumpAndSettle();
      expect(find.text('sheet'), findsNothing);
      expect(find.text('count 0'), findsOneWidget);
    }

    testWidgets('a scrim tap leaves it open', (tester) async {
      await openGuarded(tester);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expectStillOpen(tester);
      await expectClosesOnceAllowed(tester);
    });

    testWidgets('a drag down leaves it open', (tester) async {
      await openGuarded(tester);

      await tester.fling(find.text('sheet'), const Offset(0, 300), 2000);
      await tester.pumpAndSettle();

      expectStillOpen(tester);
      await expectClosesOnceAllowed(tester);
    });

    testWidgets('a drag down after the guard turned it reopens', (
      tester,
    ) async {
      // The guard answered yes when the sheet was built, so the sheet is
      // draggable; it says no by the time the drag lets go.
      allowed = true;
      registerStock(canDismiss: () => allowed);
      MagicRouter.instance.setInitialLocation('/stock');
      await pumpRouter(tester);
      MagicRoute.to('/items/new');
      await tester.pumpAndSettle();
      allowed = false;

      await tester.fling(find.text('sheet'), const Offset(0, 300), 2000);
      await tester.pumpAndSettle();

      expectStillOpen(tester);
    });

    testWidgets('MagicRoute.back() leaves it open', (tester) async {
      await openGuarded(tester);

      MagicRoute.back();
      await tester.pumpAndSettle();

      expectStillOpen(tester);
      await expectClosesOnceAllowed(tester);
    });

    testWidgets('the system back button leaves it open', (tester) async {
      await openGuarded(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expectStillOpen(tester);
      await expectClosesOnceAllowed(tester);
    });

    testWidgets('browser back leaves it open', (tester) async {
      allowed = false;
      registerStock(canDismiss: () => allowed);
      MagicRouter.instance.setInitialLocation('/stock');
      await pumpRouter(tester);
      final RouteInformation stockEntry = reportedInformation();
      MagicRoute.to('/items/new');
      await tester.pumpAndSettle();

      await browserBackTo(tester, stockEntry);

      expectStillOpen(tester);
      await expectClosesOnceAllowed(tester);
    });
  });

  group('router integration', () {
    testWidgets('the route title follows the overlay and back', (tester) async {
      registerStock();
      MagicRouter.instance.setInitialLocation('/stock');
      await pumpRouter(tester);
      expect(TitleManager.instance.currentTitle, 'Stock');

      MagicRoute.to('/items/new');
      await tester.pumpAndSettle();
      expect(sheetRoute(tester), isA<ModalBottomSheetRoute<dynamic>>());
      expect(TitleManager.instance.currentTitle, 'New item');

      MagicRoute.back();
      await tester.pumpAndSettle();
      expect(TitleManager.instance.currentTitle, 'Stock');
    });

    testWidgets('route middleware runs and can hold the content back', (
      tester,
    ) async {
      Kernel.register('probe', () => _ProbeMiddleware());
      MagicRoute.page('/stock', () => const _StockPage());
      MagicRoute.page(
        '/items/new',
        () => const Text('sheet'),
      ).middleware(['probe']).overlay(base: '/stock');
      MagicRouter.instance.setInitialLocation('/stock');
      await pumpRouter(tester);

      MagicRoute.to('/items/new');
      await tester.pumpAndSettle();

      // Held back: the frame is up, the panel is not, and the page beneath
      // is untouched.
      expect(_ProbeMiddleware.handled, 1);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('sheet'), findsNothing);
      expect(stockRoute(tester).isActive, isTrue);
    });

    testWidgets('route middleware that calls next shows the panel', (
      tester,
    ) async {
      Kernel.register('allow', () => _AllowMiddleware());
      MagicRoute.page('/stock', () => const _StockPage());
      MagicRoute.page(
        '/items/new',
        () => const Text('sheet'),
      ).middleware(['allow']).overlay(base: '/stock');
      MagicRouter.instance.setInitialLocation('/stock');
      await pumpRouter(tester);

      MagicRoute.to('/items/new');
      await tester.pumpAndSettle();

      expect(_AllowMiddleware.handled, 1);
      expect(find.text('sheet'), findsOneWidget);
    });

    testWidgets('a redirect guard on the overlay redirects a to()', (
      tester,
    ) async {
      Kernel.register('auth', () => _LoginRedirect());
      MagicRoute.page('/login', () => const Text('login'));
      MagicRoute.page('/stock', () => const _StockPage());
      MagicRoute.page(
        '/items/new',
        () => const Text('sheet'),
      ).middleware(['auth']).overlay(base: '/stock');
      MagicRouter.instance.setInitialLocation('/stock');
      await pumpRouter(tester);

      MagicRoute.to('/items/new');
      await tester.pumpAndSettle();

      expect(find.text('login'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(MagicRouter.instance.currentPath, '/login');
    });

    testWidgets('a redirect guard wins over the cold-entry base', (
      tester,
    ) async {
      Kernel.register('auth', () => _LoginRedirect());
      MagicRoute.page('/login', () => const Text('login'));
      MagicRoute.page('/stock', () => const _StockPage());
      MagicRoute.page(
        '/items/new',
        () => const Text('sheet'),
      ).middleware(['auth']).overlay(base: '/stock');
      MagicRouter.instance.setInitialLocation('/items/new');
      await pumpRouter(tester);

      expect(find.text('login'), findsOneWidget);
      expect(find.text('sheet'), findsNothing);
      expect(_StockPage.mountCount, 0);
    });

    testWidgets('a pending overlay is dropped when the base redirected away', (
      tester,
    ) async {
      Kernel.register('auth', () => _LoginRedirect());
      MagicRoute.page('/login', () => const Text('login'));
      MagicRoute.page('/stock', () => const _StockPage()).middleware(['auth']);
      MagicRoute.page(
        '/items/new',
        () => const Text('sheet'),
      ).overlay(base: '/stock');
      MagicRouter.instance.setInitialLocation('/items/new');
      await pumpRouter(tester);

      expect(find.text('login'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(MagicRouter.instance.currentPath, '/login');
    });

    testWidgets('a refused exit drops the pending overlay of a second go()', (
      tester,
    ) async {
      registerStock(canDismiss: () => false);
      MagicRouter.instance.setInitialLocation('/stock');
      await pumpRouter(tester);
      MagicRoute.to('/items/new');
      await tester.pumpAndSettle();

      MagicRouter.instance.routerConfig.go('/items/new');
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
    });
  });

  group('parametrised base', () {
    void registerItems() {
      MagicRoute.page('/', () => const Text('home'));
      MagicRoute.page('/items/:id', (id) => Text('item $id'));
      MagicRoute.page(
        '/items/:id/edit',
        (id) => Text('edit $id'),
      ).overlay(base: '/items/:id');
    }

    testWidgets('a cold entry fills the base from the overlay location', (
      tester,
    ) async {
      registerItems();
      MagicRouter.instance.setInitialLocation('/items/42/edit');
      await pumpRouter(tester);

      expect(find.text('edit 42'), findsOneWidget);
      expect(find.text('item 42', skipOffstage: false), findsOneWidget);

      MagicRoute.back();
      await tester.pumpAndSettle();

      expect(find.text('item 42'), findsOneWidget);
      expect(reportedInformation().uri.path, '/items/42');
    });

    testWidgets('a base parameter the overlay lacks fails at boot', (
      tester,
    ) async {
      MagicRoute.page('/', () => const Text('home'));
      MagicRoute.page('/items/:id', (id) => Text('item $id'));
      MagicRoute.page(
        '/items/new',
        () => const Text('sheet'),
      ).overlay(base: '/items/:id');

      expect(
        () => MagicRouter.instance.routerConfig,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('/items/new'), contains(':id')),
          ),
        ),
      );
    });
  });

  group('inside a layout group with a catch-all', () {
    /// The consumer's shape: every route in one layout, a catch-all last.
    void registerInLayout() {
      MagicRoute.group(
        layout: (child) => KeyedSubtree(child: child),
        routes: () {
          MagicRoute.page('/stock', () => const _StockPage()).title('Stock');
          MagicRoute.page(
            '/items/new',
            () => const Text('sheet'),
          ).title('New item').overlay(base: '/stock');
          MagicRoute.page(
            '/stock/:sku/move',
            (sku) => Text('move $sku'),
          ).title('Move').overlay(base: '/stock');
          MagicRoute.page('/:path(.*)', (path) => Text('missing $path'));
        },
      );
      MagicRouter.instance.setInitialLocation('/stock');
    }

    testWidgets('the overlay beats the catch-all', (tester) async {
      registerInLayout();
      await pumpRouter(tester);

      MagicRoute.to('/items/new');
      await tester.pumpAndSettle();

      expect(find.text('sheet'), findsOneWidget);
      expect(sheetRoute(tester), isA<ModalBottomSheetRoute<dynamic>>());
      expect(find.textContaining('missing'), findsNothing);
    });

    testWidgets('a cold entry beats the catch-all too', (tester) async {
      registerInLayout();
      MagicRouter.instance.setInitialLocation('/items/new');
      await pumpRouter(tester);

      expect(find.text('sheet'), findsOneWidget);
      expect(stockRoute(tester).isActive, isTrue);
    });

    testWidgets('the title follows the overlay and back', (tester) async {
      registerInLayout();
      await pumpRouter(tester);
      expect(TitleManager.instance.currentTitle, 'Stock');

      MagicRoute.to('/items/new');
      await tester.pumpAndSettle();
      expect(TitleManager.instance.currentTitle, 'New item');

      MagicRoute.back();
      await tester.pumpAndSettle();
      expect(TitleManager.instance.currentTitle, 'Stock');
    });

    testWidgets('the current route reads the overlay', (tester) async {
      registerInLayout();
      await pumpRouter(tester);

      MagicRoute.to('/stock/7/move', query: {'from': 'shelf'});
      await tester.pumpAndSettle();

      expect(find.text('move 7'), findsOneWidget);
      expect(MagicRouter.instance.currentPath, '/stock/7/move');
      expect(Request.route('sku'), '7');
      expect(MagicRouter.instance.queryParameter('from'), 'shelf');
      expect(MagicRouter.instance.currentRoute?.fullPath, '/stock/:sku/move');
    });

    testWidgets('to() twice does not stack a second sheet', (tester) async {
      registerInLayout();
      await pumpRouter(tester);

      MagicRoute.to('/items/new');
      await tester.pumpAndSettle();
      MagicRoute.to('/items/new');
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
    });

    Future<void> expectOneSheetOverStock(WidgetTester tester) async {
      expect(find.byType(BottomSheet), findsOneWidget);

      MagicRoute.back();
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('count 0'), findsOneWidget);
      expect(MagicRouter.instance.currentPath, '/stock');
    }

    testWidgets('two to() calls in one frame open one sheet', (tester) async {
      // A double click: the second call lands before the first push built.
      registerInLayout();
      await pumpRouter(tester);

      MagicRoute.to('/items/new');
      MagicRoute.to('/items/new');
      await tester.pumpAndSettle();

      await expectOneSheetOverStock(tester);
    });

    testWidgets('two to() calls a zero pump apart open one sheet', (
      tester,
    ) async {
      registerInLayout();
      await pumpRouter(tester);

      MagicRoute.to('/items/new');
      await tester.pump(Duration.zero);
      MagicRoute.to('/items/new');
      await tester.pumpAndSettle();

      await expectOneSheetOverStock(tester);
    });
  });
}

class _StockPage extends StatefulWidget {
  const _StockPage();

  static int mountCount = 0;

  @override
  State<_StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<_StockPage> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _StockPage.mountCount++;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _count++),
      child: Text('count $_count'),
    );
  }
}

/// Records that it ran and refuses the navigation.
class _ProbeMiddleware extends MagicMiddleware {
  static int handled = 0;

  @override
  Future<void> handle(void Function() next) async {
    handled++;
  }
}

/// Records that it ran and lets the navigation through.
class _AllowMiddleware extends MagicMiddleware {
  static int handled = 0;

  @override
  Future<void> handle(void Function() next) async {
    handled++;
    next();
  }
}

class _LoginRedirect extends MagicMiddleware {
  @override
  String? redirectTarget(String location) {
    return location == '/login' ? null : '/login';
  }
}
