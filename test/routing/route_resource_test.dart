import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

class _FullController with ResourceController {
  @override
  Widget index() => const SizedBox.shrink();

  @override
  Widget create() => const SizedBox.shrink();

  @override
  Widget show(String id) => SizedBox.shrink(key: ValueKey('show-$id'));

  @override
  Widget edit(String id) => SizedBox.shrink(key: ValueKey('edit-$id'));
}

class _ReadOnlyController with ResourceController {
  @override
  Set<String> get resourceMethods => const {'index', 'show'};

  @override
  Widget index() => const SizedBox.shrink();

  @override
  Widget show(String id) => const SizedBox.shrink();
}

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

  group('MagicRoute.resource', () {
    test('registers all four canonical routes by default', () {
      final routes = MagicRoute.resource('monitors', _FullController());

      expect(routes.map((r) => r.path).toList(), [
        '/monitors',
        '/monitors/create',
        '/monitors/:id',
        '/monitors/:id/edit',
      ]);
    });

    test('assigns name and title from {slug}.{method}', () {
      final routes = MagicRoute.resource('monitors', _FullController());

      final index = routes.firstWhere((r) => r.path == '/monitors');
      expect(index.routeName, 'monitors.index');
      expect(index.routeTitle, 'monitors.index');

      final show = routes.firstWhere((r) => r.path == '/monitors/:id');
      expect(show.routeName, 'monitors.show');
      expect(show.routeTitle, 'monitors.show');
    });

    test('only filters to the listed methods', () {
      final routes = MagicRoute.resource(
        'status-pages',
        _FullController(),
        only: ['index', 'create', 'show'],
      );

      expect(routes.map((r) => r.path).toList(), [
        '/status-pages',
        '/status-pages/create',
        '/status-pages/:id',
      ]);
    });

    test('except drops the listed methods', () {
      final routes = MagicRoute.resource(
        'metrics-library',
        _FullController(),
        except: ['create', 'edit'],
      );

      expect(routes.map((r) => r.path).toList(), [
        '/metrics-library',
        '/metrics-library/:id',
      ]);
    });

    test('skips methods the controller does not expose', () {
      final routes = MagicRoute.resource('docs', _ReadOnlyController());

      expect(routes.map((r) => r.path).toList(), ['/docs', '/docs/:id']);
    });

    test('strips a leading slash from the resource name', () {
      final routes = MagicRoute.resource('/teams', _FullController());

      expect(routes.first.path, '/teams');
    });

    test('normalizes trailing slash and repeated slashes', () {
      final routes = MagicRoute.resource('/teams/', _FullController());

      expect(routes.map((r) => r.path).toList(), [
        '/teams',
        '/teams/create',
        '/teams/:id',
        '/teams/:id/edit',
      ]);

      final nested = MagicRoute.resource('//admin//users//', _FullController());
      expect(nested.first.path, '/admin/users');
    });

    test('throws on unknown method in only', () {
      expect(
        () => MagicRoute.resource(
          'teams',
          _FullController(),
          only: ['index', 'destroy'],
        ),
        throwsArgumentError,
      );
    });

    test('throws on unknown method in except', () {
      expect(
        () =>
            MagicRoute.resource('teams', _FullController(), except: ['store']),
        throwsArgumentError,
      );
    });

    test('combines only and except', () {
      final routes = MagicRoute.resource(
        'posts',
        _FullController(),
        only: ['index', 'create', 'edit'],
        except: ['create'],
      );

      expect(routes.map((r) => r.path).toList(), ['/posts', '/posts/:id/edit']);
    });

    test('registers routes with the MagicRouter', () {
      MagicRoute.resource('monitors', _FullController(), only: ['index']);

      final registered = MagicRouter.instance.routes;
      expect(registered.any((r) => r.path == '/monitors'), isTrue);
    });
  });
}
