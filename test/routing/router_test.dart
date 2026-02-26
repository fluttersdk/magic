import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

void main() {
  // Reset router before each test
  setUp(() {
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
      final route = RouteDefinition(
        path: '/profile',
        handler: () => const SizedBox(),
      )
          .name('profile')
          .middleware([middleware]).transition(RouteTransition.slideUp);

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
      final route = MagicRoute.page('/dashboard', () => const SizedBox())
          .name('dashboard')
          .transition(RouteTransition.fade);

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
          MagicRouter.instance.routes.first.middlewares, contains(middleware));
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
          ]));
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
}

/// Test middleware implementation.
class _TestMiddleware extends MagicMiddleware {
  @override
  Future<void> handle(void Function() next) async => next();
}
