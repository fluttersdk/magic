import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    TitleManager.reset();
  });

  group('TitleManager — title resolution priority', () {
    test('override wins over routeTitle and appTitle', () {
      TitleManager.configure();
      TitleManager.instance
        ..setAppTitle('App')
        ..setRouteTitle('Route')
        ..setOverride('Override');

      expect(TitleManager.instance.currentTitle, 'Override');
    });

    test('null override falls through to routeTitle', () {
      TitleManager.configure();
      TitleManager.instance
        ..setAppTitle('App')
        ..setRouteTitle('Route')
        ..setOverride(null);

      expect(TitleManager.instance.currentTitle, 'Route');
    });

    test('null override and null routeTitle falls through to appTitle', () {
      TitleManager.configure();
      TitleManager.instance
        ..setAppTitle('App')
        ..setRouteTitle(null)
        ..setOverride(null);

      expect(TitleManager.instance.currentTitle, 'App');
    });

    test('all null returns null for currentTitle', () {
      TitleManager.configure();

      expect(TitleManager.instance.currentTitle, isNull);
    });

    test('routeTitle wins over appTitle', () {
      TitleManager.configure();
      TitleManager.instance
        ..setAppTitle('App')
        ..setRouteTitle('Route');

      expect(TitleManager.instance.currentTitle, 'Route');
    });
  });

  group('TitleManager — suffix application', () {
    test('suffix is appended as "title - suffix" when both present', () {
      TitleManager.configure();
      TitleManager.instance
        ..setAppTitle('App')
        ..setSuffix('MySite');

      expect(TitleManager.instance.effectiveTitle, 'App - MySite');
    });

    test('override title uses suffix', () {
      TitleManager.configure();
      TitleManager.instance
        ..setAppTitle('App')
        ..setRouteTitle('Route')
        ..setOverride('Override')
        ..setSuffix('Suffix');

      expect(TitleManager.instance.effectiveTitle, 'Override - Suffix');
    });

    test('suffix not applied when suffix is null', () {
      TitleManager.configure();
      TitleManager.instance
        ..setAppTitle('App')
        ..setSuffix(null);

      expect(TitleManager.instance.effectiveTitle, 'App');
    });

    test(
      'suffix not applied when raw title is null — returns empty string',
      () {
        TitleManager.configure();
        TitleManager.instance.setSuffix('Suffix');

        expect(TitleManager.instance.effectiveTitle, '');
      },
    );

    test('suffix alone does not produce " - suffix"', () {
      TitleManager.configure();
      TitleManager.instance.setSuffix('Suffix');

      expect(
        TitleManager.instance.effectiveTitle,
        isNot(contains(' - Suffix')),
      );
    });

    test('appTitle shown without suffix when no routeTitle or override', () {
      TitleManager.configure();
      TitleManager.instance.setAppTitle('App');

      expect(TitleManager.instance.effectiveTitle, 'App');
    });

    test('removing suffix reverts to plain title', () {
      TitleManager.configure();
      TitleManager.instance
        ..setAppTitle('App')
        ..setSuffix('Suffix')
        ..setSuffix(null);

      expect(TitleManager.instance.effectiveTitle, 'App');
    });
  });

  group('TitleManager — callback invocation', () {
    test('setSuffix triggers onTitleChanged', () {
      final titles = <String>[];
      TitleManager.configure(onTitleChanged: (title, _) => titles.add(title));

      TitleManager.instance.setSuffix('Suffix');

      expect(titles, hasLength(1));
    });

    test('setAppTitle triggers onTitleChanged', () {
      final titles = <String>[];
      TitleManager.configure(onTitleChanged: (title, _) => titles.add(title));

      TitleManager.instance.setAppTitle('App');

      expect(titles, hasLength(1));
      expect(titles.first, 'App');
    });

    test('setRouteTitle triggers onTitleChanged', () {
      final titles = <String>[];
      TitleManager.configure(onTitleChanged: (title, _) => titles.add(title));

      TitleManager.instance
        ..setAppTitle('App')
        ..setRouteTitle('Route');

      expect(titles, hasLength(2));
      expect(titles.last, 'Route');
    });

    test('setOverride triggers onTitleChanged', () {
      final titles = <String>[];
      TitleManager.configure(onTitleChanged: (title, _) => titles.add(title));

      TitleManager.instance
        ..setAppTitle('App')
        ..setOverride('Override');

      expect(titles, hasLength(2));
      expect(titles.last, 'Override');
    });

    test('callback receives effectiveTitle (with suffix)', () {
      final titles = <String>[];
      TitleManager.configure(onTitleChanged: (title, _) => titles.add(title));

      TitleManager.instance
        ..setSuffix('Site')
        ..setAppTitle('Home');

      // setSuffix fires first with no app title yet → empty string
      // setAppTitle fires second → 'Home - Site'
      expect(titles.last, 'Home - Site');
    });

    test('every mutation fires a separate callback call', () {
      int callCount = 0;
      TitleManager.configure(onTitleChanged: (_, _) => callCount++);

      TitleManager.instance
        ..setSuffix('S')
        ..setAppTitle('A')
        ..setRouteTitle('R')
        ..setOverride('O');

      expect(callCount, 4);
    });

    test('callback receives null color argument', () {
      int? receivedColor = 42;
      TitleManager.configure(
        onTitleChanged: (_, color) => receivedColor = color,
      );

      TitleManager.instance.setAppTitle('App');

      expect(receivedColor, isNull);
    });
  });

  group('TitleManager — reset', () {
    test('clears all state', () {
      TitleManager.configure();
      TitleManager.instance
        ..setAppTitle('App')
        ..setRouteTitle('Route')
        ..setOverride('Override')
        ..setSuffix('Suffix');

      TitleManager.reset();

      // Fresh instance — no state carried over
      expect(TitleManager.instance.currentTitle, isNull);
      expect(TitleManager.instance.effectiveTitle, '');
    });

    test('currentTitle returns null after reset', () {
      TitleManager.configure();
      TitleManager.instance.setAppTitle('App');

      TitleManager.reset();

      expect(TitleManager.instance.currentTitle, isNull);
    });

    test('effectiveTitle returns empty string after reset', () {
      TitleManager.configure();
      TitleManager.instance
        ..setAppTitle('App')
        ..setSuffix('Suffix');

      TitleManager.reset();

      expect(TitleManager.instance.effectiveTitle, '');
    });

    test('instance getter creates fresh instance after reset', () {
      TitleManager.configure();
      final first = TitleManager.instance;

      TitleManager.reset();

      final second = TitleManager.instance;
      expect(identical(first, second), isFalse);
    });

    test('previous callback is not invoked after reset', () {
      final titles = <String>[];
      TitleManager.configure(onTitleChanged: (title, _) => titles.add(title));

      TitleManager.instance.setAppTitle('Before Reset');
      TitleManager.reset();

      // Fresh instance has no callback — mutations go to SystemChrome (default).
      // Verify the old list is not touched by accessing new instance.
      final countBeforeNewMutation = titles.length;
      TitleManager.configure(); // no-op callback
      TitleManager.instance.setAppTitle('After Reset');

      expect(titles.length, countBeforeNewMutation);
    });
  });

  group('RouteDefinition.title() integration', () {
    test('.title() stores value and exposes via routeTitle getter', () {
      final route = RouteDefinition(
        path: '/projects',
        handler: () => const SizedBox(),
      );

      route.title('Projects');

      expect(route.routeTitle, 'Projects');
    });

    test('routeTitle returns null when .title() is not called', () {
      final route = RouteDefinition(
        path: '/projects',
        handler: () => const SizedBox(),
      );

      expect(route.routeTitle, isNull);
    });

    test('fluent chaining sets all properties correctly', () {
      final route = RouteDefinition(
        path: '/admin',
        handler: () => const SizedBox(),
      ).name('admin.index').title('Admin Panel').middleware(['auth', 'admin']);

      expect(route.routeName, 'admin.index');
      expect(route.routeTitle, 'Admin Panel');
      expect(route.middlewares, ['auth', 'admin']);
    });

    test('.title() returns RouteDefinition for further chaining', () {
      final route = RouteDefinition(
        path: '/home',
        handler: () => const SizedBox(),
      );

      final result = route.title('Home');

      expect(identical(result, route), isTrue);
    });

    test('title can be overwritten by calling .title() again', () {
      final route = RouteDefinition(
        path: '/page',
        handler: () => const SizedBox(),
      ).title('First').title('Second');

      expect(route.routeTitle, 'Second');
    });
  });
}
