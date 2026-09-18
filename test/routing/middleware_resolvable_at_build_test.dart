import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

class _Allow extends MagicMiddleware {
  @override
  Future<void> handle(void Function() next) async => next();
}

/// Where an unresolvable middleware alias actually reaches a developer.
///
/// `Kernel.resolveAll` throws at navigation as well, and
/// `test/http/kernel_resolve_test.dart` covers that directly. But that throw
/// happens inside GoRouter's `redirect` callback, which routes it to
/// `onException`: measured against a real `MaterialApp.router`, the page
/// rendered nothing, the log said `Route not found: /`, and `takeException`
/// returned null. One silent failure traded for another, with a misleading
/// message.
///
/// So the router validates the whole route table when it builds, which puts
/// the throw inside `Magic.init` where nothing catches it.
void main() {
  MagicTest.init();

  setUp(() {
    // `Magic.init` binds this (`lib/src/foundation/magic.dart:87`) and these
    // tests do not run it.
    Magic.singleton('log', LogManager.new);
    Kernel.flush();
    TitleManager.reset();
    MagicRouter.reset();
    Auth.fake();
  });

  tearDown(() {
    Auth.unfake();
    Kernel.flush();
  });

  group('the router refuses to build on an unresolvable alias', () {
    test('names the route and the alias', () {
      MagicRoute.page(
        '/admin',
        () => const SizedBox(),
      ).middleware(['nobody-registered-this']);

      expect(
        () => MagicRouter.instance.routerConfig,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('/admin'), contains('nobody-registered-this')),
          ),
        ),
      );
    });

    test('reports every offending route, not only the first', () {
      Kernel.register('auth', _Allow.new);

      MagicRoute.page('/one', () => const SizedBox()).middleware(['auth']);
      MagicRoute.page('/two', () => const SizedBox()).middleware(['missing-a']);
      MagicRoute.page(
        '/three',
        () => const SizedBox(),
      ).middleware(['auth', 'missing-b']);

      expect(
        () => MagicRouter.instance.routerConfig,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('2 routes'),
              contains('/two'),
              contains('missing-a'),
              contains('/three'),
              contains('missing-b'),
              isNot(contains('/one')),
            ),
          ),
        ),
      );
    });

    test('builds normally once every alias is registered', () {
      Kernel.register('auth', _Allow.new);

      MagicRoute.page('/admin', () => const SizedBox()).middleware(['auth']);

      expect(() => MagicRouter.instance.routerConfig, returnsNormally);
    });

    test('a factory and an instance need no registry entry', () {
      MagicRoute.page('/one', () => const SizedBox()).middleware([_Allow.new]);
      MagicRoute.page('/two', () => const SizedBox()).middleware([_Allow()]);

      expect(() => MagicRouter.instance.routerConfig, returnsNormally);
    });

    test('a route declared inside a layout group is checked too', () {
      // `MagicRoute.group(layout: ...)` collects its routes into
      // `_layouts[].children` rather than `_routes`, so a check that walks
      // `_routes` alone leaves a whole class of routes ungated: at navigation
      // `_resolveRoute` DOES find them, so `Kernel.resolveAll` throws inside
      // GoRouter's `redirect` and `onException` swallows it. Tab and shell
      // layouts are where gated screens usually live.
      MagicRoute.group(
        layout: (Widget child) => child,
        routes: () {
          MagicRoute.page(
            '/admin',
            () => const SizedBox(),
          ).middleware(['nobody-registered-this']);
        },
      );

      expect(
        () => MagicRouter.instance.routerConfig,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('/admin'), contains('nobody-registered-this')),
          ),
        ),
      );
    });

    test('and one declared through MagicRoute.layout, reported once', () {
      // The other door onto the same list, and the reason the check dedupes
      // by identity. `MagicRoute.layout(routes: [...])` builds its list by
      // calling `MagicRoute.page` with no collection open, so each route
      // lands in `_routes` AND in the layout's children. Walking both lists
      // without the set would name this route twice and count two.
      MagicRoute.layout(
        builder: (Widget child) => child,
        routes: [
          MagicRoute.page(
            '/reports',
            () => const SizedBox(),
          ).middleware(['nobody-registered-this']),
        ],
      );

      expect(
        () => MagicRouter.instance.routerConfig,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('/reports'),
              contains('nobody-registered-this'),
              contains('1 route:'),
            ),
          ),
        ),
      );
    });

    test('two bad aliases on one route are one route, listed twice', () {
      // The header counts routes, the list counts problems. Counting the list
      // reported `2 routes` over a single path, which is the same miscount the
      // identity set removes from the other direction.
      MagicRoute.page(
        '/admin',
        () => const SizedBox(),
      ).middleware(['missing-a', 'missing-b']);

      expect(
        () => MagicRouter.instance.routerConfig,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('1 route:'),
              contains('missing-a'),
              contains('missing-b'),
            ),
          ),
        ),
      );
    });

    test('a prefixed route is named by the address the app answers at', () {
      // `path` is the bare `/users` inside a group; the app answers at
      // `/admin/users`. The error exists to be searched for.
      MagicRoute.group(
        prefix: '/admin',
        routes: () {
          MagicRoute.page(
            '/users',
            () => const SizedBox(),
          ).middleware(['nobody-registered-this']);
        },
      );

      expect(
        () => MagicRouter.instance.routerConfig,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('/admin/users'),
          ),
        ),
      );
    });

    test('the check constructs nothing, so a factory does not fire', () {
      // A factory with a side effect would otherwise run once per route at
      // bootstrap, which is why `Kernel.unresolvable` reads the registry
      // rather than calling `resolve`.
      var built = 0;

      Kernel.register('auth', () {
        built++;

        return _Allow();
      });

      MagicRoute.page('/admin', () => const SizedBox()).middleware(['auth']);

      MagicRouter.instance.routerConfig;

      expect(built, 0);
    });
  });
}
