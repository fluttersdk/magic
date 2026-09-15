import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// Records the query at mount time and at every build.
///
/// The two lists answer different questions and the difference is the
/// contract. A query change REBUILDS the screen and does not remount it, in
/// every navigation verb this framework has, so `mounted` stays put while
/// `built` grows. A screen that reads its query in `initState` therefore
/// renders a stale one; the routing doc says to read it where a rebuild can
/// see it, and this is what pins that.
class _QueryReadingPage extends StatefulWidget {
  const _QueryReadingPage({required this.id});

  final String id;

  static final List<String?> mounted = <String?>[];
  static final List<String?> built = <String?>[];

  static void reset() {
    mounted.clear();
    built.clear();
  }

  @override
  State<_QueryReadingPage> createState() => _QueryReadingPageState();
}

class _QueryReadingPageState extends State<_QueryReadingPage> {
  @override
  void initState() {
    super.initState();
    _QueryReadingPage.mounted.add(MagicRouter.instance.queryParameter('tab'));
  }

  @override
  Widget build(BuildContext context) {
    _QueryReadingPage.built.add(MagicRouter.instance.queryParameter('tab'));
    return const SizedBox();
  }
}

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    TitleManager.reset();
    MagicRouter.reset();
  });

  /// What the app last told the engine about whether IT handles back.
  ///
  /// This is the whole Android story in one value. Flutter forwards it as
  /// `SystemNavigator.setFrameworkHandlesBack`, and on `false` the embedder
  /// unregisters its `OnBackInvokedCallback`, so the system back button leaves
  /// the app rather than reaching the Navigator. Nothing in the widget tree
  /// shows it, which is why an app can ship without the back button working
  /// at all and no test notice.
  List<Object?> watchFrameworkHandlesBack(WidgetTester tester) {
    final List<Object?> calls = <Object?>[];

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
          calls.add(call.arguments);
        }
        return null;
      },
    );

    return calls;
  }

  Future<void> pumpRouter(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
    );
    // `WidgetsApp` refuses to talk to the engine until the app is not
    // detached, so a test that never sets a lifecycle measures silence and
    // reads it as success.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  }

  group('MagicRouter stacking', () {
    testWidgets('an unstacked route leaves Android back to the system', (
      tester,
    ) async {
      // The behaviour being kept, pinned so a later default change is loud.
      MagicRoute.page('/', () => const SizedBox());
      MagicRoute.page('/home', () => const SizedBox());

      final calls = watchFrameworkHandlesBack(tester);
      await pumpRouter(tester);

      MagicRouter.instance.to('/home');
      await tester.pumpAndSettle();

      expect(
        calls.last,
        false,
        reason: 'go() replaces the page list, so there is nothing to pop',
      );
    });

    testWidgets('a stacked route takes back away from the system', (
      tester,
    ) async {
      MagicRoute.page('/', () => const SizedBox());
      MagicRoute.page('/monitors/:id', (id) => const SizedBox()).stacked();

      final calls = watchFrameworkHandlesBack(tester);
      await pumpRouter(tester);

      MagicRouter.instance.to('/monitors/42');
      await tester.pumpAndSettle();

      expect(
        calls.last,
        true,
        reason: 'the app now has a page to pop, so it owns the back button',
      );
    });

    testWidgets('the pattern matches, not the literal path', (tester) async {
      // `.stacked()` is declared on `/monitors/:id` and `to()` is handed
      // `/monitors/42`. A literal lookup finds nothing and silently falls back
      // to the default, which is the shape that would make this feature work
      // only for static routes.
      MagicRoute.page('/', () => const SizedBox());
      MagicRoute.page('/monitors/:id', (id) => const SizedBox()).stacked();

      await pumpRouter(tester);

      MagicRouter.instance.to('/monitors/42?tab=checks');
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(SizedBox).last);
      expect(Navigator.of(ctx).canPop(), isTrue);
    });

    testWidgets('a stacked route still resolves through back()', (
      tester,
    ) async {
      MagicRoute.page('/', () => const SizedBox());
      MagicRoute.page('/monitors', () => const SizedBox());
      MagicRoute.page('/monitors/:id', (id) => const SizedBox()).stacked();

      await pumpRouter(tester);

      MagicRouter.instance.to('/monitors');
      await tester.pumpAndSettle();
      MagicRouter.instance.to('/monitors/42');
      await tester.pumpAndSettle();

      MagicRouter.instance.back();
      await tester.pumpAndSettle();

      expect(MagicRouter.instance.currentLocation, '/monitors');
    });

    testWidgets('a second back() after a stacked pop is not a dead press', (
      tester,
    ) async {
      // The push branch must not also record history, or the same step is
      // recorded twice: once as a Navigator page and once as a string. The
      // native pop consumes the page and leaves the string, so the NEXT back
      // finds `canPop()` false, pops the entry naming the location it is
      // already on, and goes there. To the reader that is a back press that
      // did nothing.
      MagicRoute.page('/', () => const SizedBox());
      MagicRoute.page('/monitors', () => const SizedBox());
      MagicRoute.page('/monitors/:id', (id) => const SizedBox()).stacked();

      await pumpRouter(tester);

      MagicRouter.instance.to('/monitors');
      await tester.pumpAndSettle();
      MagicRouter.instance.to('/monitors/42');
      await tester.pumpAndSettle();

      MagicRouter.instance.back();
      await tester.pumpAndSettle();
      expect(MagicRouter.instance.currentLocation, '/monitors');

      MagicRouter.instance.back();
      await tester.pumpAndSettle();
      expect(
        MagicRouter.instance.currentLocation,
        '/',
        reason: 'the second press has to move, not re-enter where it is',
      );
    });

    testWidgets('the same-target guard ignores the query string', (
      tester,
    ) async {
      // `currentLocation` carries the query and a bare `to('/monitors/42')`
      // does not, so comparing them whole makes a re-tap look like a move and
      // pushes a second copy of the screen already on screen.
      MagicRoute.page('/', () => const SizedBox());
      MagicRoute.page('/monitors/:id', (id) => const SizedBox()).stacked();

      await pumpRouter(tester);

      MagicRouter.instance.to('/monitors/42?tab=checks');
      await tester.pumpAndSettle();
      MagicRouter.instance.to('/monitors/42');
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(SizedBox).last);
      Navigator.of(ctx).pop();
      await tester.pumpAndSettle();

      expect(
        MagicRouter.instance.currentLocation,
        '/',
        reason: 'one push happened, not two',
      );
    });

    testWidgets('changing only the query on a stacked route still moves', (
      tester,
    ) async {
      // The other direction, and the one a path-only comparison swallows.
      // Switching a tab on the page you are on is a real navigation, not a
      // re-tap of the destination that got you there.
      MagicRoute.page('/', () => const SizedBox());
      MagicRoute.page('/monitors', () => const SizedBox());
      MagicRoute.page('/monitors/:id', (id) => const SizedBox()).stacked();

      await pumpRouter(tester);

      MagicRouter.instance.to('/monitors');
      await tester.pumpAndSettle();
      MagicRouter.instance.to('/monitors/42');
      await tester.pumpAndSettle();

      MagicRouter.instance.to(
        '/monitors/42',
        queryParameters: {'tab': 'checks'},
      );
      await tester.pumpAndSettle();

      expect(
        MagicRouter.instance.currentLocation,
        '/monitors/42?tab=checks',
        reason: 'the tab has to change',
      );

      // Replaced rather than pushed: the reader is on one screen, so back
      // leaves it rather than stepping through the tabs they visited.
      MagicRouter.instance.back();
      await tester.pumpAndSettle();

      expect(MagicRouter.instance.currentLocation, '/monitors');
    });

    testWidgets('a query change rebuilds the screen rather than remounting', (
      tester,
    ) async {
      // The contract, and it is the same one every other navigation in this
      // framework already has: go_router keys a declarative page on the
      // matched PATH and not the query, so a query change rebuilds and never
      // remounts. Measured for an unstacked `go()` too, which behaves
      // identically; a stacked route deliberately does not diverge from it.
      _QueryReadingPage.reset();

      MagicRoute.page('/', () => const SizedBox());
      MagicRoute.page(
        '/monitors/:id',
        // Not const: a const widget is the SAME instance every time, so the
        // element never updates and nothing rebuilds. A real page takes its
        // path parameter and is never const.
        (id) => _QueryReadingPage(id: id),
      ).stacked();

      await pumpRouter(tester);

      MagicRouter.instance.to(
        '/monitors/42',
        queryParameters: {'tab': 'overview'},
      );
      await tester.pumpAndSettle();

      MagicRouter.instance.to(
        '/monitors/42',
        queryParameters: {'tab': 'checks'},
      );
      await tester.pumpAndSettle();

      expect(
        _QueryReadingPage.built.last,
        'checks',
        reason: 'a build after the change has to see the new tab',
      );
      expect(_QueryReadingPage.mounted, [
        'overview',
      ], reason: 'and the screen keeps its state rather than being rebuilt');

      // Still one page: the swap kept the stack underneath.
      final ctx = tester.element(find.byType(SizedBox).last);
      Navigator.of(ctx).pop();
      await tester.pumpAndSettle();

      expect(MagicRouter.instance.currentLocation, '/');
    });

    testWidgets('the same holds when the screen is the whole stack', (
      tester,
    ) async {
      // A cold-start deep link: go_router synthesises no parent page under a
      // detail route, so the detail route IS the stack and the imperative
      // verbs fall back to the declarative match list. One verb behaving two
      // ways by stack depth would be worse than every verb behaving one way,
      // so this pins that it does not.
      _QueryReadingPage.reset();

      MagicRoute.page('/', () => const SizedBox());
      MagicRoute.page(
        '/monitors/:id',
        // Not const: a const widget is the SAME instance every time, so the
        // element never updates and nothing rebuilds. A real page takes its
        // path parameter and is never const.
        (id) => _QueryReadingPage(id: id),
      ).stacked();

      MagicRouter.instance.setInitialLocation('/monitors/42?tab=overview');

      await pumpRouter(tester);

      MagicRouter.instance.to(
        '/monitors/42',
        queryParameters: {'tab': 'checks'},
      );
      await tester.pumpAndSettle();

      expect(_QueryReadingPage.built.last, 'checks');
      expect(_QueryReadingPage.mounted, ['overview']);
      expect(MagicRouter.instance.currentLocation, '/monitors/42?tab=checks');
    });

    testWidgets('a bare target after a query change is still a re-tap', (
      tester,
    ) async {
      // The direction that separates "asking for this screen" from "asking to
      // clear its tab". Both compare equal on the path, and only the query
      // tells them apart.
      MagicRoute.page('/', () => const SizedBox());
      MagicRoute.page('/monitors/:id', (id) => const SizedBox()).stacked();

      await pumpRouter(tester);

      MagicRouter.instance.to('/monitors/42');
      await tester.pumpAndSettle();
      MagicRouter.instance.to(
        '/monitors/42',
        queryParameters: {'tab': 'checks'},
      );
      await tester.pumpAndSettle();

      MagicRouter.instance.to('/monitors/42');
      await tester.pumpAndSettle();

      expect(
        MagicRouter.instance.currentLocation,
        '/monitors/42?tab=checks',
        reason: 'a bare target is the destination, not an empty query',
      );

      // All of it one page: the replace swapped the top rather than stacking,
      // so a single pop reaches the root.
      final ctx = tester.element(find.byType(SizedBox).last);
      Navigator.of(ctx).pop();
      await tester.pumpAndSettle();

      expect(MagicRouter.instance.currentLocation, '/');
    });

    testWidgets('navigating to where you already are does not stack', (
      tester,
    ) async {
      // A nav destination re-tapped, which is the cheapest way to grow a stack
      // without bound.
      MagicRoute.page('/', () => const SizedBox());
      MagicRoute.page('/monitors/:id', (id) => const SizedBox()).stacked();

      await pumpRouter(tester);

      for (var i = 0; i < 4; i++) {
        MagicRouter.instance.to('/monitors/42');
        await tester.pumpAndSettle();
      }

      final ctx = tester.element(find.byType(SizedBox).last);
      expect(
        Navigator.of(ctx).canPop(),
        isTrue,
        reason: 'the one real push is still there',
      );

      // One push off the root, not four: popping it lands back at the root
      // rather than on another copy of the same screen.
      Navigator.of(ctx).pop();
      await tester.pumpAndSettle();

      expect(MagicRouter.instance.currentLocation, '/');
    });

    testWidgets('defaultStacked covers a route that says nothing', (
      tester,
    ) async {
      MagicRoute.page('/', () => const SizedBox());
      MagicRoute.page('/home', () => const SizedBox());

      MagicRouter.instance.defaultStacked = true;

      await pumpRouter(tester);

      MagicRouter.instance.to('/home');
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(SizedBox).last);
      expect(Navigator.of(ctx).canPop(), isTrue);
    });

    testWidgets('a route opting out beats the router default', (tester) async {
      MagicRoute.page('/', () => const SizedBox());
      MagicRoute.page('/home', () => const SizedBox()).stacked(false);

      MagicRouter.instance.defaultStacked = true;

      await pumpRouter(tester);

      MagicRouter.instance.to('/home');
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(SizedBox).last);
      expect(Navigator.of(ctx).canPop(), isFalse);
    });
  });

  group('RouteTransition.platform', () {
    testWidgets('builds a route Flutter will install a back gesture on', (
      tester,
    ) async {
      // The gesture lives inside `CupertinoPageTransition`, which a bare
      // `PageRoute` never reaches. What makes it reachable is the transition
      // mixin, so that is what this asserts: the route consults the theme and
      // answers `popGestureEnabled`, which `_CupertinoBackGestureDetector`
      // calls to decide whether to enter the gesture arena.
      MagicRoute.page('/', () => const SizedBox());
      MagicRoute.page(
        '/monitors/:id',
        (id) => const SizedBox(),
      ).stacked().transition(RouteTransition.platform);

      await pumpRouter(tester);

      MagicRouter.instance.to('/monitors/42');
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(SizedBox).last);
      final route = ModalRoute.of(ctx)! as PageRoute<dynamic>;

      expect(route, isA<MaterialRouteTransitionMixin<dynamic>>());
      expect(route.popGestureEnabled, isTrue);
    });

    testWidgets('swipeBack(false) refuses the gesture and nothing else', (
      tester,
    ) async {
      MagicRoute.page('/', () => const SizedBox());
      MagicRoute.page(
        '/checkout/pay',
        () => const SizedBox(),
      ).stacked().transition(RouteTransition.platform).swipeBack(false);

      await pumpRouter(tester);

      MagicRouter.instance.to('/checkout/pay');
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(SizedBox).last);
      final route = ModalRoute.of(ctx)! as PageRoute<dynamic>;

      expect(route.popGestureEnabled, isFalse);
      // The route is still poppable by every other means, which is the whole
      // difference between this and `PopScope(canPop: false)`.
      expect(Navigator.of(ctx).canPop(), isTrue);
    });

    testWidgets('the root route has no gesture, whatever it asks for', (
      tester,
    ) async {
      // Why a drawer and this gesture do not fight over the left edge: on a
      // route with nothing under it the detector is never armed, so the
      // drawer's own edge drag is uncontested. Flutter decides this, not us.
      MagicRoute.page(
        '/',
        () => const SizedBox(),
      ).transition(RouteTransition.platform);

      await pumpRouter(tester);

      final ctx = tester.element(find.byType(SizedBox).last);
      final route = ModalRoute.of(ctx)! as PageRoute<dynamic>;

      expect(route.popGestureEnabled, isFalse);
    });

    testWidgets('defaultTransition covers a route that says nothing', (
      tester,
    ) async {
      MagicRoute.page('/', () => const SizedBox());
      MagicRoute.page('/home', () => const SizedBox()).stacked();

      MagicRouter.instance.defaultTransition = RouteTransition.platform;

      await pumpRouter(tester);

      MagicRouter.instance.to('/home');
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(SizedBox).last);
      expect(ModalRoute.of(ctx), isA<MaterialRouteTransitionMixin<dynamic>>());
    });

    testWidgets('a route naming its own transition beats the default', (
      tester,
    ) async {
      MagicRoute.page('/', () => const SizedBox());
      MagicRoute.page(
        '/home',
        () => const SizedBox(),
      ).stacked().transition(RouteTransition.fade);

      MagicRouter.instance.defaultTransition = RouteTransition.platform;

      await pumpRouter(tester);

      MagicRouter.instance.to('/home');
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(SizedBox).last);
      expect(
        ModalRoute.of(ctx),
        isNot(isA<MaterialRouteTransitionMixin<dynamic>>()),
      );
    });

    testWidgets('asking for none explicitly beats the default too', (
      tester,
    ) async {
      // The case a sentinel default cannot express. If "unset" and "none" are
      // the same value, a route that deliberately asks for no animation is
      // indistinguishable from one that said nothing, and an app-wide default
      // silently overrides the one route that opted out of it.
      MagicRoute.page('/', () => const SizedBox());
      MagicRoute.page(
        '/home',
        () => const SizedBox(),
      ).stacked().transition(RouteTransition.none);

      MagicRouter.instance.defaultTransition = RouteTransition.platform;

      await pumpRouter(tester);

      MagicRouter.instance.to('/home');
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(SizedBox).last);
      expect(
        ModalRoute.of(ctx),
        isNot(isA<MaterialRouteTransitionMixin<dynamic>>()),
      );
    });
  });
}
