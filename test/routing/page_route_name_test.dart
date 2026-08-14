import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// Tests that every page this router builds carries a name in its
/// [RouteSettings].
///
/// ## Why this matters beyond tidiness
///
/// A `NavigatorObserver` sees pages, not routes. `GoRoute.name` names the ROUTE
/// and never reaches `RouteSettings`, so an observer reading
/// `route.settings.name` gets null for every push unless the `Page` itself was
/// given one. Every observer that identifies screens is therefore blind:
/// analytics, breadcrumbs, and Sentry's web release health, which starts a
/// session only when it sees the name change
/// (`WebSessionHandler.startSession`). That last one fails silently and
/// completely: the transport works, events arrive, and the session count stays
/// at zero forever with nothing in any log to explain it.
///
/// ## Why the fallback is the path
///
/// `RouteDefinition.name()` is optional and most routes never call it, so
/// naming pages only when `routeName` exists would leave the common case
/// exactly as broken as before. The full path is always present, is already
/// unique per route, and is what a reader recognises in a breadcrumb trail.
/// It also happens to satisfy Sentry's first-session rule, which starts a
/// session on the very first navigation only when the name is `/`.
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

  group('page names', () {
    testWidgets('a named route names its page with the route name', (
      tester,
    ) async {
      MagicRoute.page('/', () => const SizedBox()).name('home');

      final observer = _NameRecordingObserver();
      MagicRouter.instance.addObserver(observer);

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      expect(observer.names, contains('home'));
    });

    testWidgets('an unnamed route falls back to its path', (tester) async {
      // The common case: `.name()` is optional and most routes skip it, so a
      // fix that only handled named routes would leave the majority broken.
      //
      // The path this asserts is also the one Sentry's web session tracking
      // treats specially: it starts a session on the very first navigation
      // only when the name is exactly `/`, which the fallback produces for
      // free on the root route.
      MagicRoute.page('/', () => const SizedBox());

      final observer = _NameRecordingObserver();
      MagicRouter.instance.addObserver(observer);

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      expect(observer.names, contains('/'));
    });

    testWidgets('a page name never comes back null after navigation', (
      tester,
    ) async {
      MagicRoute.page('/', () => const SizedBox()).name('home');
      MagicRoute.page('/profile', () => const SizedBox()).name('profile');

      final observer = _NameRecordingObserver();
      MagicRouter.instance.addObserver(observer);

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      MagicRoute.to('/profile');
      await tester.pumpAndSettle();

      expect(observer.names, contains('profile'));
      expect(
        observer.names.contains(null),
        isFalse,
        reason:
            'A null name is what silently disables every screen-aware observer.',
      );
    });
  });
}

/// Records the name of every route pushed or replaced, exactly as a
/// screen-aware observer reads it.
class _NameRecordingObserver extends NavigatorObserver {
  final List<String?> names = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    names.add(route.settings.name);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      names.add(newRoute.settings.name);
    }
  }
}
