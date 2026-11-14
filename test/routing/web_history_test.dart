import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// What the router tells the browser about its history, on the web.
///
/// The VM has no browser, so [MagicRouter.browserBack] is replaced with a
/// counter and every report the router sends the engine is recorded off
/// `SystemChannels.navigation`. A report with `replace: false` is a NEW
/// browser history entry; `replace: true` overwrites the current one. A real
/// browser answers `history.back()` with the previous entry, which a test
/// plays back through [browserBackTo].
void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  late int backs;
  late List<Map<Object?, Object?>> reports;

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    TitleManager.reset();
    MagicRouter.reset();
    Kernel.flush();
    Log.fake();
    backs = 0;
    reports = <Map<Object?, Object?>>[];
  });

  void recordReports(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.navigation,
      (MethodCall call) async {
        if (call.method == 'routeInformationUpdated') {
          reports.add(call.arguments as Map<Object?, Object?>);
        }
        return null;
      },
    );
  }

  /// Boots the router as the web build does, with a counting back hook.
  Future<void> pumpWebRouter(WidgetTester tester) async {
    MagicRouter.instance.browserBack = () => backs++;
    recordReports(tester);
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

  Future<void> browserBackTo(
    WidgetTester tester,
    RouteInformation entry,
  ) async {
    await MagicRouter.instance.routerConfig.routeInformationProvider
        .didPushRouteInformation(entry);
    await tester.pumpAndSettle();
  }

  void register({bool Function()? canDismiss}) {
    MagicRoute.page('/', () => const Text('home'));
    MagicRoute.page('/stock', () => const Text('stock'));
    MagicRoute.page(
      '/stock/sheet',
      () => const SizedBox(
        width: double.infinity,
        height: 200,
        child: Text('sheet'),
      ),
    ).overlay(base: '/stock', canDismiss: canDismiss);
    MagicRoute.page('/detail/:id', (id) => Text('detail $id')).stacked();
    MagicRoute.page('/plain', () => const Text('plain'));
  }

  NavigatorState rootNavigator() =>
      MagicRouter.instance.navigatorKey.currentState!;

  /// `popUntil` that fails instead of spinning when a pop never advances.
  void popToFirst() {
    var calls = 0;
    rootNavigator().popUntil((route) {
      calls++;
      if (calls > 20) throw StateError('popUntil did not advance');

      return route.isFirst;
    });
  }

  /// Opens the sheet over `/stock` and returns the browser entry of `/stock`.
  Future<RouteInformation> openSheet(WidgetTester tester) async {
    MagicRouter.instance.setInitialLocation('/stock');
    await pumpWebRouter(tester);
    final RouteInformation stockEntry = reportedInformation();

    MagicRoute.to('/stock/sheet');
    await tester.pumpAndSettle();
    expect(find.text('sheet'), findsOneWidget);
    expect(reports.last['uri'], '/stock/sheet');
    expect(reports.last['replace'], isFalse);
    reports.clear();

    return stockEntry;
  }

  test('off the web there is no browser history to step', () {
    expect(MagicRouter.instance.browserBack, isNull);
  });

  group('an in-app close of a page the router pushed', () {
    Future<void> expectSteppedBack(
      WidgetTester tester,
      RouteInformation stockEntry,
    ) async {
      expect(backs, 1);
      expect(
        reports,
        isEmpty,
        reason: 'a new entry for /stock would put the sheet behind Back',
      );

      // The browser answers with the entry before, as a popstate.
      await browserBackTo(tester, stockEntry);

      expect(find.text('sheet'), findsNothing);
      expect(find.text('stock'), findsOneWidget);
      expect(backs, 1);
      expect(reports, isEmpty);
    }

    testWidgets('back() steps the browser back once', (tester) async {
      register();
      final RouteInformation stockEntry = await openSheet(tester);

      MagicRoute.back();
      await tester.pumpAndSettle();

      await expectSteppedBack(tester, stockEntry);
    });

    testWidgets('a scrim tap steps the browser back once', (tester) async {
      register();
      final RouteInformation stockEntry = await openSheet(tester);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await expectSteppedBack(tester, stockEntry);
    });

    testWidgets('a scrim tap on a dialog steps the browser back once', (
      tester,
    ) async {
      MagicRoute.page('/', () => const Text('home'));
      MagicRoute.page('/stock', () => const Text('stock'));
      MagicRoute.page(
        '/stock/sheet',
        () => const Center(
          child: SizedBox(width: 300, height: 200, child: Text('sheet')),
        ),
      ).overlay(base: '/stock');
      MagicRoute.useOverlayPresentation(
        (context) => MagicOverlayPresentation.dialog,
      );
      final RouteInformation stockEntry = await openSheet(tester);
      expect(
        ModalRoute.of(tester.element(find.text('sheet'))),
        isA<RawDialogRoute<dynamic>>(),
      );

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(
        find.text('sheet'),
        findsOneWidget,
        reason: 'the browser closes it, not an in-app pop',
      );

      await expectSteppedBack(tester, stockEntry);
    });

    testWidgets('a drag down steps the browser back once', (tester) async {
      register();
      final RouteInformation stockEntry = await openSheet(tester);

      await tester.fling(find.text('sheet'), const Offset(0, 300), 2000);
      await tester.pumpAndSettle();

      await expectSteppedBack(tester, stockEntry);
    });

    testWidgets('a stacked page steps the browser back once', (tester) async {
      register();
      MagicRouter.instance.setInitialLocation('/stock');
      await pumpWebRouter(tester);
      final RouteInformation stockEntry = reportedInformation();
      MagicRoute.to('/detail/1');
      await tester.pumpAndSettle();
      reports.clear();

      MagicRoute.back();
      await tester.pumpAndSettle();

      await expectSteppedBack(tester, stockEntry);
      expect(find.text('detail 1'), findsNothing);
    });
  });

  group('the browser history is left alone', () {
    testWidgets('when the close came from the browser', (tester) async {
      register();
      final RouteInformation stockEntry = await openSheet(tester);

      await browserBackTo(tester, stockEntry);

      expect(find.text('sheet'), findsNothing);
      expect(backs, 0);
      expect(reports, isEmpty);
    });

    testWidgets('when the guard refuses the close', (tester) async {
      register(canDismiss: () => false);
      await openSheet(tester);

      MagicRoute.back();
      await tester.pumpAndSettle();

      expect(find.text('sheet'), findsOneWidget);
      expect(backs, 0);
    });

    testWidgets('when the page underneath was never reported', (tester) async {
      // Both moves land in one frame, so `/stock` never got an entry of its
      // own and the entry before the detail page is not the page beneath it.
      register();
      await pumpWebRouter(tester);
      MagicRoute.to('/stock');
      MagicRoute.to('/detail/1');
      await tester.pumpAndSettle();

      MagicRoute.back();
      await tester.pumpAndSettle();

      expect(backs, 0);
      expect(find.text('detail 1'), findsNothing);
    });
  });

  group('a pop the app drives keeps go_router\'s synchronous contract', () {
    testWidgets('popUntil over a pushed page terminates', (tester) async {
      register();
      MagicRouter.instance.setInitialLocation('/stock');
      await pumpWebRouter(tester);
      MagicRoute.push('/plain');
      await tester.pumpAndSettle();

      popToFirst();
      await tester.pumpAndSettle();

      expect(find.text('stock'), findsOneWidget);
      expect(find.text('plain'), findsNothing);
    });

    testWidgets('popUntil over a stacked page terminates', (tester) async {
      register();
      MagicRouter.instance.setInitialLocation('/stock');
      await pumpWebRouter(tester);
      MagicRoute.to('/detail/1');
      await tester.pumpAndSettle();

      popToFirst();
      await tester.pumpAndSettle();

      expect(find.text('stock'), findsOneWidget);
    });

    testWidgets('popUntil over an unguarded sheet terminates', (tester) async {
      register();
      await openSheet(tester);

      popToFirst();
      await tester.pumpAndSettle();

      expect(find.text('sheet'), findsNothing);
      expect(find.text('stock'), findsOneWidget);
    });
  });

  group('two closes in one frame', () {
    testWidgets('back() twice steps the browser back once', (tester) async {
      register();
      final RouteInformation stockEntry = await openSheet(tester);

      MagicRoute.back();
      MagicRoute.back();
      await tester.pumpAndSettle();

      expect(backs, 1);
      await browserBackTo(tester, stockEntry);
      expect(find.text('stock'), findsOneWidget);
      expect(backs, 1);
    });

    testWidgets('a scrim tap and back() step the browser back once', (
      tester,
    ) async {
      register();
      final RouteInformation stockEntry = await openSheet(tester);

      await tester.tapAt(const Offset(10, 10));
      MagicRoute.back();
      await tester.pumpAndSettle();

      expect(backs, 1);
      await browserBackTo(tester, stockEntry);
      expect(find.text('stock'), findsOneWidget);
    });

    testWidgets('back() twice closes a guarded sheet once', (tester) async {
      // Native: the guard's exit runs in a microtask, so both pops reach the
      // same page before either has removed it.
      register(canDismiss: () => true);
      MagicRouter.instance.setInitialLocation('/stock');
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();
      MagicRoute.to('/stock/sheet');
      await tester.pumpAndSettle();

      MagicRoute.back();
      MagicRoute.back();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('sheet'), findsNothing);
      expect(find.text('stock'), findsOneWidget);
    });
  });

  group('a pop followed by a navigation in the same handler', () {
    Future<void> openGuardedSheet(WidgetTester tester, {bool web = false}) {
      register(canDismiss: () => true);
      MagicRouter.instance.setInitialLocation('/stock');
      if (web) return openSheet(tester);

      return () async {
        await tester.pumpWidget(
          MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
        );
        await tester.pumpAndSettle();
        MagicRoute.to('/stock/sheet');
        await tester.pumpAndSettle();
      }();
    }

    testWidgets('keeps a stacked page pushed after a guarded sheet', (
      tester,
    ) async {
      await openGuardedSheet(tester);

      rootNavigator().pop();
      MagicRoute.to('/detail/5');
      await tester.pumpAndSettle();

      expect(find.text('sheet'), findsNothing);
      expect(find.text('detail 5'), findsOneWidget);
    });

    testWidgets('keeps a page reached by to() after a guarded sheet', (
      tester,
    ) async {
      await openGuardedSheet(tester);

      rootNavigator().pop();
      MagicRoute.to('/plain');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('plain'), findsOneWidget);
    });

    testWidgets('keeps a page reached after back() steps the browser', (
      tester,
    ) async {
      register();
      final RouteInformation stockEntry = await openSheet(tester);

      MagicRoute.back();
      MagicRoute.to('/detail/5');
      await tester.pumpAndSettle();
      await browserBackTo(tester, stockEntry);

      expect(backs, 1);
      expect(find.text('detail 5'), findsOneWidget);
    });
  });

  testWidgets('two pushes in one frame own no entry', (tester) async {
    // One report carries both, so the entry before the top is not the page
    // beneath it, for either of them.
    register();
    MagicRouter.instance.setInitialLocation('/stock');
    await pumpWebRouter(tester);
    MagicRoute.to('/detail/1');
    MagicRoute.to('/detail/2');
    await tester.pumpAndSettle();

    MagicRoute.back();
    await tester.pumpAndSettle();
    MagicRoute.back();
    await tester.pumpAndSettle();

    expect(backs, 0);
    expect(find.text('stock'), findsOneWidget);
  });

  testWidgets('browser Back from a push of the same location goes through', (
    tester,
  ) async {
    register();
    MagicRouter.instance.setInitialLocation('/stock');
    await pumpWebRouter(tester);
    final RouteInformation stockEntry = reportedInformation();
    MagicRoute.push('/stock');
    await tester.pumpAndSettle();

    await browserBackTo(tester, stockEntry);
    await browserBackTo(tester, stockEntry);

    expect(backs, 0);
    expect(
      MagicRouter
          .instance
          .routerConfig
          .routerDelegate
          .currentConfiguration
          .matches,
      hasLength(1),
    );
  });

  testWidgets('a cold entry reports the base, then the sheet as a new entry', (
    tester,
  ) async {
    register();
    MagicRouter.instance.setInitialLocation('/stock/sheet');
    await pumpWebRouter(tester);

    expect(find.text('sheet'), findsOneWidget);
    expect(
      reports.map((r) => (r['uri'], r['replace'])).toList(),
      <(Object?, Object?)>[('/stock', true), ('/stock/sheet', false)],
    );

    MagicRoute.back();
    await tester.pumpAndSettle();
    expect(backs, 1);

    await browserBackTo(
      tester,
      RouteInformation(uri: Uri.parse('/stock'), state: reports.first['state']),
    );
    expect(find.text('sheet'), findsNothing);
    expect(find.text('stock'), findsOneWidget);
  });

  group('on a fake browser history', () {
    late _FakeBrowser browser;

    /// Boots the router against [browser], which keeps its own entries, so
    /// a step back lands where a browser would put it rather than where the
    /// router assumes it does.
    Future<void> pumpBrowser(WidgetTester tester, {String? initial}) async {
      browser = _FakeBrowser();
      MagicRouter.instance.browserBack = browser.back;
      if (initial != null) MagicRouter.instance.setInitialLocation(initial);
      final GoRouter router = MagicRouter.instance.routerConfig;
      browser.provider = router.routeInformationProvider;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.navigation,
        (MethodCall call) async {
          if (call.method == 'routeInformationUpdated') {
            browser.report(call.arguments as Map<Object?, Object?>);
          }
          return null;
        },
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
    }

    testWidgets('back() from a stacked page lands on the page beneath', (
      tester,
    ) async {
      register();
      await pumpBrowser(tester, initial: '/stock');
      MagicRoute.to('/detail/1');
      await tester.pumpAndSettle();

      MagicRoute.back();
      await tester.pumpAndSettle();

      expect(browser.paths, ['/stock', '/detail/1']);
      expect(browser.index, 0);
      expect(find.text('stock'), findsOneWidget);
      expect(find.text('detail 1'), findsNothing);
    });

    testWidgets('closing a sheet lands on the page beneath', (tester) async {
      register();
      await pumpBrowser(tester, initial: '/stock');
      MagicRoute.to('/stock/sheet');
      await tester.pumpAndSettle();

      MagicRoute.back();
      await tester.pumpAndSettle();

      expect(browser.paths, ['/stock', '/stock/sheet']);
      expect(browser.index, 0);
      expect(find.text('sheet'), findsNothing);
    });

    testWidgets('a cold entry leaves the base before the sheet', (
      tester,
    ) async {
      register();
      await pumpBrowser(tester, initial: '/stock/sheet');

      expect(browser.paths, ['/stock', '/stock/sheet']);
      expect(browser.index, 1);

      await browser.pressBack(tester);

      expect(find.text('sheet'), findsNothing);
      expect(find.text('stock'), findsOneWidget);
    });

    testWidgets('a query swap on a stacked page gives up its entry', (
      tester,
    ) async {
      // The swap is a replace, which keeps the page key and is reported as a
      // new entry, so the entry before is the page on its old tab.
      register();
      await pumpBrowser(tester, initial: '/stock');
      MagicRoute.to('/detail/1');
      await tester.pumpAndSettle();
      MagicRoute.to('/detail/1', query: {'tab': 'b'});
      await tester.pumpAndSettle();

      MagicRoute.back();
      await tester.pumpAndSettle();

      expect(browser.backs, 0);
      expect(find.text('detail 1'), findsNothing);
      expect(find.text('stock'), findsOneWidget);
    });

    testWidgets('a query swap over a layout page swaps instead of pushing', (
      tester,
    ) async {
      // The page beneath lives in a layout, whose shell builds after the
      // pushed page, so the last-built location names the page beneath.
      MagicRoute.group(
        layout: (child) => KeyedSubtree(child: child),
        routes: () => MagicRoute.page('/stock', () => const Text('stock')),
      );
      MagicRoute.page('/detail/:id', (id) => Text('detail $id')).stacked();
      await pumpBrowser(tester, initial: '/stock');
      MagicRoute.to('/detail/1');
      await tester.pumpAndSettle();
      MagicRoute.to('/detail/1', query: {'tab': 'b'});
      await tester.pumpAndSettle();

      expect(
        MagicRouter
            .instance
            .routerConfig
            .routerDelegate
            .currentConfiguration
            .matches,
        hasLength(2),
        reason: 'the swap replaces the top page; it does not push a second',
      );

      MagicRoute.back();
      await tester.pumpAndSettle();

      expect(find.text('detail 1'), findsNothing);
      expect(find.text('stock'), findsOneWidget);
    });

    testWidgets('replace() over a pushed page gives up its entry', (
      tester,
    ) async {
      register();
      await pumpBrowser(tester, initial: '/stock');
      MagicRoute.to('/detail/1');
      await tester.pumpAndSettle();
      MagicRoute.replace('/plain');
      await tester.pumpAndSettle();

      MagicRoute.back();
      await tester.pumpAndSettle();

      expect(browser.backs, 0);
      expect(find.text('detail 1'), findsNothing);
      expect(find.text('plain'), findsNothing);
      expect(find.text('stock'), findsOneWidget);
    });

    testWidgets('a navigation deferred over a guarded sheet waits for the '
        'step back it raced', (tester) async {
      register(canDismiss: () => true);
      await pumpBrowser(tester, initial: '/stock');
      MagicRoute.to('/stock/sheet');
      await tester.pumpAndSettle();

      MagicRoute.to('/detail/5');
      MagicRoute.back();
      await tester.pumpAndSettle();

      expect(browser.backs, 1);
      expect(find.text('sheet'), findsNothing);
      expect(find.text('detail 5'), findsOneWidget);
    });

    testWidgets('a step given up leaves the page; a late answer closes it', (
      tester,
    ) async {
      register();
      await pumpBrowser(tester, initial: '/stock');
      MagicRoute.to('/stock/sheet');
      await tester.pumpAndSettle();
      browser.answerAfter = const Duration(seconds: 2);

      MagicRoute.back();
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump();

      // Given up: nothing closed in the app, so no entry was added that the
      // late answer could step back past.
      expect(find.text('sheet'), findsOneWidget);
      expect(browser.paths, ['/stock', '/stock/sheet']);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('sheet'), findsNothing);
      expect(find.text('stock'), findsOneWidget);
      expect(browser.paths, ['/stock', '/stock/sheet']);
      expect(browser.index, 0);
    });

    testWidgets('a drag whose step is given up slides the sheet back up', (
      tester,
    ) async {
      register();
      await pumpBrowser(tester, initial: '/stock');
      MagicRoute.to('/stock/sheet');
      await tester.pumpAndSettle();
      browser.answerAfter = const Duration(seconds: 5);

      await tester.fling(find.text('sheet'), const Offset(0, 300), 2000);
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();

      expect(browser.backs, 1);
      final ModalRoute<dynamic> sheet = ModalRoute.of(
        tester.element(find.text('sheet')),
      )!;
      expect(sheet.isCurrent, isTrue);
      expect(sheet.animation!.value, 1.0);

      // Let the late answer land so no timer outlives the test.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('sheet'), findsNothing);
    });

    testWidgets('a panel that blocks the pop keeps the scrim off the browser', (
      tester,
    ) async {
      var invoked = 0;
      MagicRoute.page('/stock', () => const Text('stock'));
      MagicRoute.page(
        '/stock/form',
        () => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) => invoked++,
          child: const SizedBox(
            width: double.infinity,
            height: 200,
            child: Text('form'),
          ),
        ),
      ).overlay(base: '/stock');
      await pumpBrowser(tester, initial: '/stock');
      MagicRoute.to('/stock/form');
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(browser.backs, 0);
      expect(invoked, 1);
      expect(find.text('form'), findsOneWidget);
      expect(browser.index, 1);
    });
  });

  testWidgets('a navigation deferred over a guarded sheet does nothing after '
      'the router was reset', (tester) async {
    register(canDismiss: () => true);
    MagicRouter.instance.setInitialLocation('/stock');
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
    );
    await tester.pumpAndSettle();
    MagicRoute.to('/stock/sheet');
    await tester.pumpAndSettle();

    MagicRoute.to('/detail/5');
    MagicRouter.reset();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));

    expect(tester.takeException(), isNull);
  });
}

/// A browser's session history: entries, the current index, and Back.
///
/// A report with `replace: false` drops every entry after the current one
/// and appends; `replace: true` overwrites the current one. `history.back()`
/// moves the index back once [answerAfter] has passed, relative to the
/// index at that moment as a browser does, and hands the entry it lands on
/// to the router as platform route information.
class _FakeBrowser {
  final List<RouteInformation> entries = [RouteInformation(uri: Uri())];
  int index = 0;
  int backs = 0;
  Duration answerAfter = Duration.zero;
  late GoRouteInformationProvider provider;

  List<String> get paths => [for (final entry in entries) entry.uri.path];

  void report(Map<Object?, Object?> arguments) {
    final RouteInformation entry = RouteInformation(
      uri: Uri.parse(arguments['uri']! as String),
      state: arguments['state'],
    );
    if (arguments['replace'] == true) {
      entries[index] = entry;
      return;
    }

    entries.removeRange(index + 1, entries.length);
    entries.add(entry);
    index++;
  }

  void back() {
    backs++;
    Timer(answerAfter, _traverseBack);
  }

  /// The browser's own Back button.
  Future<void> pressBack(WidgetTester tester) async {
    _traverseBack();
    await tester.pumpAndSettle();
  }

  void _traverseBack() {
    if (index == 0) return;
    index--;
    provider.didPushRouteInformation(entries[index]);
  }
}
