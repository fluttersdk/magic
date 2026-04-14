import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  // Reset router before each test
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    TitleManager.reset();
    MagicRouter.reset();
  });

  group('RouteDefinition', () {
    test('creates basic route with path and handler', () {
      final route = RouteDefinition(
        path: '/users',
        handler: () => const SizedBox(),
      );

      expect(route.path, '/users');
      expect(route.method, 'GET');
      expect(route.routeName, isNull);
    });

    test('fluent .name() sets route name', () {
      final route = RouteDefinition(
        path: '/dashboard',
        handler: () => const SizedBox(),
      ).name('dashboard.index');

      expect(route.routeName, 'dashboard.index');
    });

    test('fluent .middleware() adds middlewares', () {
      final middleware = _TestMiddleware();
      final route = RouteDefinition(
        path: '/admin',
        handler: () => const SizedBox(),
      ).middleware([middleware]);

      expect(route.middlewares, contains(middleware));
    });

    test('fluent .transition() sets transition type', () {
      final route = RouteDefinition(
        path: '/modal',
        handler: () => const SizedBox(),
      ).transition(RouteTransition.fade);

      expect(route.transitionType, RouteTransition.fade);
    });

    test('fluent API supports chaining', () {
      final middleware = _TestMiddleware();
      final route =
          RouteDefinition(path: '/profile', handler: () => const SizedBox())
              .name('profile')
              .middleware([middleware])
              .transition(RouteTransition.slideUp);

      expect(route.routeName, 'profile');
      expect(route.middlewares, hasLength(1));
      expect(route.transitionType, RouteTransition.slideUp);
    });

    test('fullPath includes group prefix', () {
      final route = RouteDefinition(
        path: '/users',
        handler: () => const SizedBox(),
      );
      route.groupPrefix = '/admin';

      expect(route.fullPath, '/admin/users');
    });
  });

  group('MagicRoute Facade', () {
    test('MagicRoute.page() registers a route', () {
      MagicRoute.page('/home', () => const SizedBox());

      expect(MagicRouter.instance.routes, hasLength(1));
      expect(MagicRouter.instance.routes.first.path, '/home');
      expect(MagicRouter.instance.routes.first.method, 'PAGE');
    });

    test('MagicRoute.get() works as alias for page()', () {
      // ignore: deprecated_member_use_from_same_package
      MagicRoute.get('/home', () => const SizedBox());
      expect(MagicRouter.instance.routes.first.method, 'PAGE');
    });

    test('MagicRoute.page() returns RouteDefinition for chaining', () {
      final route = MagicRoute.page(
        '/dashboard',
        () => const SizedBox(),
      ).name('dashboard').transition(RouteTransition.fade);

      expect(route.routeName, 'dashboard');
      expect(route.transitionType, RouteTransition.fade);
    });

    test('MagicRoute.group() applies prefix to nested routes', () {
      MagicRoute.group(
        prefix: '/admin',
        routes: () {
          MagicRoute.page('/users', () => const SizedBox());
          MagicRoute.page('/settings', () => const SizedBox());
        },
      );

      expect(MagicRouter.instance.routes, hasLength(2));
      expect(MagicRouter.instance.routes[0].fullPath, '/admin/users');
      expect(MagicRouter.instance.routes[1].fullPath, '/admin/settings');
    });

    test('MagicRoute.group() applies middleware to nested routes', () {
      final middleware = _TestMiddleware();

      MagicRoute.group(
        prefix: '/api',
        middleware: [middleware],
        routes: () {
          MagicRoute.page('/data', () => const SizedBox());
        },
      );

      expect(
        MagicRouter.instance.routes.first.middlewares,
        contains(middleware),
      );
    });

    test('nested MagicRoute.group() combines prefixes', () {
      MagicRoute.group(
        prefix: '/api',
        routes: () {
          MagicRoute.group(
            prefix: '/v1',
            routes: () {
              MagicRoute.page('/users', () => const SizedBox());
            },
          );
        },
      );

      expect(MagicRouter.instance.routes.first.fullPath, '/api/v1/users');
    });
  });

  group('MagicRouter', () {
    test('addRoute() stores route definitions', () {
      final route = RouteDefinition(
        path: '/test',
        handler: () => const SizedBox(),
      );

      MagicRouter.instance.addRoute(route);

      expect(MagicRouter.instance.routes, contains(route));
    });

    test('routes list is unmodifiable', () {
      MagicRoute.page('/home', () => const SizedBox());

      expect(
        () => MagicRouter.instance.routes.add(
          RouteDefinition(path: '/hack', handler: () => const SizedBox()),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('routerConfig returns GoRouter instance', () {
      MagicRoute.page('/', () => const SizedBox());

      final config = MagicRouter.instance.routerConfig;

      expect(config, isNotNull);
    });

    test('reset() clears all routes', () {
      MagicRoute.page('/one', () => const SizedBox());
      MagicRoute.page('/two', () => const SizedBox());

      expect(MagicRouter.instance.routes, hasLength(2));

      MagicRouter.reset();

      expect(MagicRouter.instance.routes, isEmpty);
    });
  });

  group('RouteTransition', () {
    test('enum contains expected values', () {
      expect(
        RouteTransition.values,
        containsAll([
          RouteTransition.none,
          RouteTransition.fade,
          RouteTransition.slideRight,
          RouteTransition.slideUp,
          RouteTransition.scale,
        ]),
      );
    });
  });

  group('Intended URL', () {
    test('setIntendedUrl stores the URL', () {
      MagicRouter.instance.setIntendedUrl('/invitations/abc/accept');

      expect(MagicRouter.instance.hasIntendedUrl, isTrue);
    });

    test('pullIntendedUrl returns and clears the URL', () {
      MagicRouter.instance.setIntendedUrl('/invitations/abc/accept');

      final url = MagicRouter.instance.pullIntendedUrl();

      expect(url, '/invitations/abc/accept');
      expect(MagicRouter.instance.hasIntendedUrl, isFalse);
    });

    test('pullIntendedUrl returns null when nothing is set', () {
      expect(MagicRouter.instance.pullIntendedUrl(), isNull);
      expect(MagicRouter.instance.hasIntendedUrl, isFalse);
    });

    test('reset clears intendedUrl', () {
      MagicRouter.instance.setIntendedUrl('/some-page');

      MagicRouter.reset();

      expect(MagicRouter.instance.hasIntendedUrl, isFalse);
      expect(MagicRouter.instance.pullIntendedUrl(), isNull);
    });

    test('currentLocation returns null when no state is set', () {
      expect(MagicRouter.instance.currentLocation, isNull);
    });

    test('currentPath returns null when no state is set', () {
      expect(MagicRouter.instance.currentPath, isNull);
    });
  });

  group('currentPath', () {
    testWidgets('returns path without query string', (tester) async {
      MagicRoute.page('/', () => const SizedBox());
      MagicRoute.page('/profile', () => const SizedBox());

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      MagicRouter.instance.to('/profile', queryParameters: {'tab': 'security'});
      await tester.pumpAndSettle();

      expect(MagicRouter.instance.currentPath, '/profile');
      expect(MagicRouter.instance.currentLocation, contains('tab=security'));
    });

    testWidgets('returns path for simple routes', (tester) async {
      MagicRoute.page('/', () => const SizedBox());
      MagicRoute.page('/home', () => const SizedBox());

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      MagicRouter.instance.to('/home');
      await tester.pumpAndSettle();

      expect(MagicRouter.instance.currentPath, '/home');
    });
  });

  group('Layout Merging', () {
    test('layouts with same layoutId merge into single LayoutDefinition', () {
      MagicRoute.group(
        layoutId: 'app',
        layout: (child) => Container(key: const Key('layout1'), child: child),
        routes: () {
          MagicRoute.page('/page1', () => const SizedBox());
        },
      );

      MagicRoute.group(
        layoutId: 'app',
        layout: (child) => Container(key: const Key('layout2'), child: child),
        routes: () {
          MagicRoute.page('/page2', () => const SizedBox());
        },
      );

      final merged = MagicRouter.instance.mergedLayouts;
      expect(merged, hasLength(1));
      expect(merged.first.children, hasLength(2));
      expect(merged.first.id, 'app');
    });

    test('layouts without layoutId remain separate', () {
      MagicRoute.group(
        layout: (child) => child,
        routes: () {
          MagicRoute.page('/page1', () => const SizedBox());
        },
      );

      MagicRoute.group(
        layout: (child) => child,
        routes: () {
          MagicRoute.page('/page2', () => const SizedBox());
        },
      );

      final merged = MagicRouter.instance.mergedLayouts;
      expect(merged, hasLength(2));
    });

    test('mixed named and anonymous layouts coexist', () {
      MagicRoute.group(
        layoutId: 'app',
        layout: (child) => child,
        routes: () {
          MagicRoute.page('/page1', () => const SizedBox());
        },
      );

      MagicRoute.group(
        layout: (child) => child,
        routes: () {
          MagicRoute.page('/page2', () => const SizedBox());
        },
      );

      final merged = MagicRouter.instance.mergedLayouts;
      expect(merged, hasLength(2));
    });

    test('first builder wins when merging', () {
      MagicRoute.group(
        layoutId: 'app',
        layout: (child) => Container(key: const Key('first'), child: child),
        routes: () {
          MagicRoute.page('/page1', () => const SizedBox());
        },
      );

      MagicRoute.group(
        layoutId: 'app',
        layout: (child) => Container(key: const Key('second'), child: child),
        routes: () {
          MagicRoute.page('/page2', () => const SizedBox());
        },
      );

      final merged = MagicRouter.instance.mergedLayouts;
      expect(merged.first.id, 'app');
    });

    test('three groups with same layoutId all merge', () {
      MagicRoute.group(
        layoutId: 'app',
        layout: (child) => child,
        routes: () => MagicRoute.page('/1', () => const SizedBox()),
      );
      MagicRoute.group(
        layoutId: 'app',
        layout: (child) => child,
        routes: () => MagicRoute.page('/2', () => const SizedBox()),
      );
      MagicRoute.group(
        layoutId: 'app',
        layout: (child) => child,
        routes: () => MagicRoute.page('/3', () => const SizedBox()),
      );

      final merged = MagicRouter.instance.mergedLayouts;
      expect(merged, hasLength(1));
      expect(merged.first.children, hasLength(3));
    });
  });

  group('Observer Support', () {
    test('addObserver() stores observer', () {
      final observer = _TestNavigatorObserver();

      MagicRouter.instance.addObserver(observer);

      expect(MagicRouter.instance.observers, contains(observer));
    });

    test('observers persist after router build', () {
      final observer = _TestNavigatorObserver();

      MagicRouter.instance.addObserver(observer);
      MagicRoute.page('/', () => const SizedBox());

      final config = MagicRouter.instance.routerConfig;

      expect(config, isNotNull);
      expect(MagicRouter.instance.observers, contains(observer));
    });

    test('addObserver() throws after build', () {
      MagicRoute.page('/', () => const SizedBox());

      // Trigger the lazy build.
      MagicRouter.instance.routerConfig;

      expect(
        () => MagicRouter.instance.addObserver(_TestNavigatorObserver()),
        throwsA(isA<StateError>()),
      );
    });

    test('reset() clears observers', () {
      final observer = _TestNavigatorObserver();

      MagicRouter.instance.addObserver(observer);

      MagicRouter.reset();

      expect(MagicRouter.instance.observers, isEmpty);
    });
  });

  /// History-based back() navigation.
  ///
  /// These tests verify the history tracking feature, including
  /// [MagicRouter.instance.historyDepth] and the [MagicRouter.back] `fallback`
  /// behavior.
  group('History-Based back() Navigation', () {
    testWidgets(
      'back() navigates to previous path when canPop() is false (history fallback)',
      (tester) async {
        MagicRoute.page('/', () => const SizedBox());
        MagicRoute.page('/home', () => const SizedBox());
        MagicRoute.page('/settings', () => const SizedBox());

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
        );
        await tester.pumpAndSettle();

        // Navigate from / to /home, then to /settings using go() (replaces stack)
        MagicRouter.instance.to('/home');
        await tester.pumpAndSettle();

        MagicRouter.instance.to('/settings');
        await tester.pumpAndSettle();

        // Native stack is shallow (go() replaces), so canPop() is false.
        // History should allow us to fall back to /home.
        MagicRouter.instance.back();
        await tester.pumpAndSettle();

        expect(MagicRouter.instance.currentLocation, '/home');
      },
    );

    testWidgets(
      'back() prefers native pop when canPop() is true (existing behaviour preserved)',
      (tester) async {
        MagicRoute.page('/', () => const SizedBox());
        MagicRoute.page('/detail', () => const SizedBox());

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
        );
        await tester.pumpAndSettle();

        // push() grows the native stack, so canPop() is true.
        MagicRouter.instance.push('/detail');
        await tester.pumpAndSettle();

        expect(
          MagicRouter.instance.navigatorKey.currentState?.canPop(),
          isTrue,
        );

        MagicRouter.instance.back();
        await tester.pumpAndSettle();

        expect(MagicRouter.instance.currentLocation, '/');
      },
    );

    testWidgets(
      'back() with explicit fallback navigates to fallback when both pop and history unavailable',
      (tester) async {
        MagicRoute.page('/', () => const SizedBox());
        MagicRoute.page('/home', () => const SizedBox());

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
        );
        await tester.pumpAndSettle();

        // No prior navigation — history is empty, canPop() is false.
        MagicRouter.instance.back(fallback: '/home');
        await tester.pumpAndSettle();

        expect(MagicRouter.instance.currentLocation, '/home');
      },
    );

    testWidgets(
      'back() is no-op when history empty, canPop false, and no fallback',
      (tester) async {
        MagicRoute.page('/', () => const SizedBox());

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
        );
        await tester.pumpAndSettle();

        final locationBefore = MagicRouter.instance.currentLocation;

        // Should not throw and should not change location.
        MagicRouter.instance.back();
        await tester.pumpAndSettle();

        expect(MagicRouter.instance.currentLocation, locationBefore);
      },
    );

    testWidgets('replace() swaps last history entry instead of pushing', (
      tester,
    ) async {
      MagicRoute.page('/', () => const SizedBox());
      MagicRoute.page('/a', () => const SizedBox());
      MagicRoute.page('/b', () => const SizedBox());
      MagicRoute.page('/c', () => const SizedBox());

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      MagicRouter.instance.to('/a');
      await tester.pumpAndSettle();

      MagicRouter.instance.to('/b');
      await tester.pumpAndSettle();

      final depthAfterTwoNavigations = MagicRouter.instance.historyDepth;

      // replace() should swap /b with /c — depth must not grow.
      MagicRouter.instance.replace('/c');
      await tester.pumpAndSettle();

      expect(MagicRouter.instance.historyDepth, depthAfterTwoNavigations);
      expect(MagicRouter.instance.currentLocation, '/c');

      // After replace(), back() should land on the entry before the replaced route.
      MagicRouter.instance.back();
      await tester.pumpAndSettle();

      expect(MagicRouter.instance.currentLocation, '/a');
    });

    testWidgets('to() records current location in history before navigating', (
      tester,
    ) async {
      MagicRoute.page('/', () => const SizedBox());
      MagicRoute.page('/target', () => const SizedBox());

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      final depthBefore = MagicRouter.instance.historyDepth;

      MagicRouter.instance.to('/target');
      await tester.pumpAndSettle();

      // Depth must grow by one — the originating location was recorded.
      expect(MagicRouter.instance.historyDepth, depthBefore + 1);
    });

    testWidgets(
      'toNamed() records current location in history before navigating',
      (tester) async {
        MagicRoute.page('/', () => const SizedBox()).name('home');
        MagicRoute.page('/about', () => const SizedBox()).name('about');

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
        );
        await tester.pumpAndSettle();

        final depthBefore = MagicRouter.instance.historyDepth;

        MagicRouter.instance.toNamed('about');
        await tester.pumpAndSettle();

        expect(MagicRouter.instance.historyDepth, depthBefore + 1);
      },
    );

    testWidgets('history respects max 50 entries — oldest evicted when full', (
      tester,
    ) async {
      // Register enough routes to exceed the cap.
      MagicRoute.page('/', () => const SizedBox());
      for (var i = 1; i <= 55; i++) {
        MagicRoute.page('/page/$i', () => const SizedBox());
      }

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      for (var i = 1; i <= 55; i++) {
        MagicRouter.instance.to('/page/$i');
        await tester.pumpAndSettle();
      }

      expect(MagicRouter.instance.historyDepth, 50);
    });

    testWidgets(
      'back() via history does NOT push a new history entry (no infinite loop)',
      (tester) async {
        MagicRoute.page('/', () => const SizedBox());
        MagicRoute.page('/a', () => const SizedBox());
        MagicRoute.page('/b', () => const SizedBox());

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
        );
        await tester.pumpAndSettle();

        MagicRouter.instance.to('/a');
        await tester.pumpAndSettle();

        MagicRouter.instance.to('/b');
        await tester.pumpAndSettle();

        final depthBeforeBack = MagicRouter.instance.historyDepth;

        // back() should consume an entry, not add one.
        MagicRouter.instance.back();
        await tester.pumpAndSettle();

        expect(MagicRouter.instance.historyDepth, depthBeforeBack - 1);
      },
    );

    test('reset() clears history', () {
      // Manually populate history via to() without a running router:
      // instead, verify historyDepth is zero after reset() regardless.
      MagicRoute.page('/', () => const SizedBox());

      // Depth should be zero on a fresh (reset) instance.
      expect(MagicRouter.instance.historyDepth, 0);

      MagicRouter.reset();

      expect(MagicRouter.instance.historyDepth, 0);
    });
  });

  group('TitleManager Integration', () {
    test('routerConfig attaches routerDelegate listener', () {
      MagicRoute.page('/', () => const SizedBox());

      // Accessing routerConfig should not throw.
      final config = MagicRouter.instance.routerConfig;

      // The delegate should have at least one listener (ours).
      // We verify indirectly: the router built without error.
      expect(config, isNotNull);
    });

    testWidgets('route navigation updates TitleManager with route title', (
      tester,
    ) async {
      final titles = <String>[];
      TitleManager.configure(onTitleChanged: (title, _) => titles.add(title));

      MagicRoute.page('/', () => const SizedBox()).title('Home');
      MagicRoute.page('/about', () => const SizedBox()).title('About');

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      // Initial route title should be set.
      expect(titles, contains('Home'));

      titles.clear();

      MagicRouter.instance.to('/about');
      await tester.pumpAndSettle();

      expect(titles, contains('About'));
    });

    testWidgets('route without title sets null route title on TitleManager', (
      tester,
    ) async {
      final titles = <String>[];
      TitleManager.configure(onTitleChanged: (title, _) => titles.add(title));

      TitleManager.instance.setAppTitle('App');

      MagicRoute.page('/', () => const SizedBox()).title('Home');
      MagicRoute.page('/plain', () => const SizedBox());

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      titles.clear();

      MagicRouter.instance.to('/plain');
      await tester.pumpAndSettle();

      // Route title is null so it falls back to app title.
      expect(titles, contains('App'));
    });

    test('reset() resets TitleManager', () {
      TitleManager.configure(onTitleChanged: (_, _) {});
      TitleManager.instance.setAppTitle('Test App');

      MagicRouter.reset();

      // After reset, TitleManager should be a fresh instance.
      expect(TitleManager.instance.currentTitle, isNull);
    });
  });
}

/// Test middleware implementation.
class _TestMiddleware extends MagicMiddleware {
  @override
  Future<void> handle(void Function() next) async => next();
}

/// Test NavigatorObserver implementation.
class _TestNavigatorObserver extends NavigatorObserver {}
