import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../http/kernel.dart';
import '../http/middleware/magic_middleware.dart';
import '../facades/auth.dart';
import '../facades/log.dart';
import 'magic_platform_page.dart';
import 'route_definition.dart';
import 'title_manager.dart';

/// The Magic Router.
///
/// This is the central routing service that wraps `GoRouter` with a
/// Laravel-style API. It manages all route definitions and provides
/// context-free navigation methods.
///
/// ## Registration
///
/// Routes are registered using the `Route` facade:
///
/// ```dart
/// Route.get('/', () => HomePage());
/// Route.get('/users/:id', (id) => UserPage(id: id));
/// ```
///
/// ## Navigation (Context-Free!)
///
/// Navigate from anywhere - controllers, services, or pure Dart classes:
///
/// ```dart
/// Route.to('/dashboard');
/// Route.back();
/// Route.replace('/home');
/// ```
///
/// ## Setup
///
/// Use `routerConfig` with `MaterialApp.router`:
///
/// ```dart
/// MaterialApp.router(
///   routerConfig: MagicRouter.instance.routerConfig,
/// )
/// ```
class MagicRouter {
  // ---------------------------------------------------------------------------
  // Singleton Pattern
  // ---------------------------------------------------------------------------

  MagicRouter._();

  static MagicRouter? _instance;

  /// Access the global router instance.
  static MagicRouter get instance {
    _instance ??= MagicRouter._();
    return _instance!;
  }

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  /// The global navigator key for context-free navigation.
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Registered route definitions.
  final List<RouteDefinition> _routes = [];

  /// Registered layout definitions.
  final List<LayoutDefinition> _layouts = [];

  /// Registered navigator observers.
  final List<NavigatorObserver> _observers = [];

  /// The built GoRouter instance (lazily created).
  GoRouter? _router;

  /// Current route state (for parameter access).
  GoRouterState? _currentState;

  /// Current route definition (for title resolution).
  RouteDefinition? _currentRoute;

  /// Whether the router has been built.
  bool _isBuilt = false;

  /// Saved intended URL for redirect-after-login pattern.
  String? _intendedUrl;

  /// Navigation history for back() fallback when canPop() is false.
  ///
  /// Populated by [to] and [toNamed] before each `go()` call.
  /// Consumed by [back] when native pop is unavailable.
  final List<String> _history = [];

  /// Maximum number of entries retained in the navigation history.
  static const int _maxHistorySize = 50;

  /// The transition a route takes when it does not name one.
  ///
  /// Set once in a service provider rather than on every route:
  ///
  /// ```dart
  /// MagicRouter.instance.defaultTransition = RouteTransition.platform;
  /// ```
  ///
  /// Left at [RouteTransition.none] so nothing changes for an app that does
  /// not ask. A route's own `.transition()` always wins.
  RouteTransition defaultTransition = RouteTransition.none;

  /// Whether [to] pushes rather than replaces, for a route that does not say.
  ///
  /// Off by default, and worth leaving off on web: `go()` already produces a
  /// working browser Back, and pushing adds Navigator pages on top of that.
  /// A route's own `.stacked()` always wins, which is the way to opt in a
  /// drill-down without opting in the tabs around it.
  bool defaultStacked = false;

  /// active route collector stack for group layouts.
  final List<List<RouteDefinition>> _collectionStack = [];

  /// Start collecting routes for a layout group.
  void startCollection() {
    _collectionStack.add([]);
  }

  /// Stop collecting routes and return them.
  List<RouteDefinition> stopCollection() {
    if (_collectionStack.isEmpty) return [];
    return _collectionStack.removeLast();
  }

  // ---------------------------------------------------------------------------
  // Route Registration
  // ---------------------------------------------------------------------------

  /// Add a route definition.
  ///
  /// Usually called via `Route.get()` or `Route.post()`.
  void addRoute(RouteDefinition route) {
    if (_isBuilt) {
      throw StateError(
        'Cannot add routes after the router has been built. '
        'Register all routes before accessing routerConfig.',
      );
    }

    if (_collectionStack.isNotEmpty) {
      _collectionStack.last.add(route);
    } else {
      _routes.add(route);
    }
  }

  /// Add a layout (shell) definition.
  ///
  /// Usually called via `Route.layout()`.
  void addLayout(LayoutDefinition layout) {
    if (_isBuilt) {
      throw StateError(
        'Cannot add layouts after the router has been built. '
        'Register all routes before accessing routerConfig.',
      );
    }
    _layouts.add(layout);
  }

  /// Get all registered routes.
  List<RouteDefinition> get routes => List.unmodifiable(_routes);

  /// Get all registered navigator observers.
  List<NavigatorObserver> get observers => List.unmodifiable(_observers);

  /// Add a navigator observer.
  ///
  /// Must be called before the router is built (before [routerConfig] is accessed).
  void addObserver(NavigatorObserver observer) {
    if (_isBuilt) {
      throw StateError(
        'Cannot add observers after the router has been built. '
        'Register all observers before accessing routerConfig.',
      );
    }
    _observers.add(observer);
  }

  // ---------------------------------------------------------------------------
  // Router Configuration
  // ---------------------------------------------------------------------------

  /// Get the GoRouter configuration for MaterialApp.router.
  ///
  /// ```dart
  /// MaterialApp.router(
  ///   routerConfig: MagicRouter.instance.routerConfig,
  /// )
  /// ```
  GoRouter get routerConfig {
    if (_router == null) {
      _router = _buildRouter();
      _isBuilt = true;
      _router!.routerDelegate.addListener(_onRouteChanged);
    }
    return _router!;
  }

  /// The initial route location (default: '/').
  String _initialLocation = '/';

  /// Set the initial route location.
  ///
  /// This must be called before the router is accessed (e.g. in main.dart).
  void setInitialLocation(String location) {
    if (_isBuilt) {
      debugPrint(
        'Warning: setInitialLocation called after router was built. '
        'This will have no effect until the app is restarted.',
      );
    }
    _initialLocation = location;
  }

  /// Every registered route whose middleware list names something the
  /// [Kernel] cannot resolve, checked once when the router builds.
  ///
  /// This is where an unresolvable alias actually reaches a developer.
  /// `Kernel.resolveAll` throws at navigation too, but that throw happens
  /// inside GoRouter's `redirect` callback, which routes it to `onException`:
  /// measured, the app renders nothing and the log says `Route not found`,
  /// naming the wrong problem. Here the throw escapes `Magic.init` and stops
  /// the app at bootstrap, before a build ships with an ungated route.
  ///
  /// [Kernel.unresolvable] constructs nothing, so this costs one map lookup
  /// per declared middleware and fires no factory.
  ///
  /// It walks [_allRoutes], not `_routes`. A route declared inside
  /// `MagicRoute.group(layout: ...)` is diverted into the layout's children by
  /// [startCollection] and never reaches `_routes`, while `_resolveRoute`
  /// still finds it at navigation: so checking `_routes` alone left every
  /// route under a tab or shell layout ungated, which is where a gated screen
  /// usually lives.
  ///
  /// The identity set is not defensive. `MagicRoute.layout(routes: [...])`
  /// builds its list by calling `MagicRoute.page` with no collection open, so
  /// those routes land in `_routes` AND in the layout's children, and the same
  /// instance would otherwise be reported twice and counted twice.
  void _assertMiddlewareResolvable() {
    final problems = <String>[];
    final seen = <RouteDefinition>{};

    for (final route in _allRoutes()) {
      if (!seen.add(route)) continue;

      for (final entry in Kernel.unresolvable(route.middlewares)) {
        problems.add('${route.path}: ${Kernel.unresolvableMessage(entry)}');
      }
    }

    if (problems.isEmpty) return;

    throw StateError(
      'Unresolvable route middleware on ${problems.length} '
      'route${problems.length == 1 ? '' : 's'}:\n  ${problems.join('\n  ')}',
    );
  }

  /// Build the GoRouter from registered definitions.
  GoRouter _buildRouter() {
    _assertMiddlewareResolvable();

    return GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: _initialLocation,
      observers: _observers,
      routes: _buildRoutes(),
      redirect: _handleRedirect,
      refreshListenable: _resolveAuthRefreshListenable(),
      // GoRouter sends EVERY exception here, not only a missed match: a throw
      // from the `redirect` callback above lands in this callback too. Saying
      // `Route not found` for all of them named the wrong problem, and was
      // measured doing exactly that for an unresolvable middleware alias.
      onException: (context, state, router) {
        final error = state.error;

        Log.warning(
          error == null
              ? 'Route not found: ${state.uri}'
              : 'Route ${state.uri} failed: $error',
        );
      },
    );
  }

  /// Resolve the auth guard's state notifier as the router's refresh signal.
  ///
  /// GoRouter re-runs [_handleRedirect] whenever the returned [Listenable]
  /// notifies. The default guard's `stateNotifier` bumps on every login,
  /// logout, and session restore, so a passive 401 (expired or revoked token)
  /// that triggers a logout re-evaluates the redirect chain and ejects the
  /// user from a protected screen to the login route, with no explicit
  /// navigation call.
  ///
  /// This only adds a re-evaluation trigger: it does not force any redirect.
  /// The middleware chain still decides the target, returning `null` (allow)
  /// once the user is on the correct side, so a logged-out user resting on the
  /// login route does not loop.
  ///
  /// Resolution is defensive. The router may be built before auth is fully
  /// configured (no `auth` binding in the container, missing guard config), in
  /// which case reaching the notifier throws. We then return `null` (no refresh
  /// signal) rather than crashing router construction, mirroring the tolerance
  /// in [AuthServiceProvider.boot].
  Listenable? _resolveAuthRefreshListenable() {
    try {
      return Auth.stateNotifier;
    } catch (e, stackTrace) {
      // Use debugPrint, not the Log facade: this runs at router-build time,
      // which can precede the container binding of the log service (and of
      // auth itself). Resolving Log here would throw the very "service not
      // registered" error we are guarding against, mirroring the
      // container-free warning in [setInitialLocation]. The stack trace is
      // included: a misconfiguration here (missing guard, wrong binding order)
      // is otherwise hard to trace back to its origin from the message alone.
      debugPrint(
        'MagicRouter: auth state notifier unavailable; redirects will not '
        're-run on auth-state changes ($e).\n$stackTrace',
      );
      return null;
    }
  }

  /// Convert route definitions to GoRouter routes.
  List<RouteBase> _buildRoutes() {
    final goRoutes = <RouteBase>[];

    // Add standard routes
    for (final route in _routes) {
      goRoutes.add(_buildGoRoute(route));
    }

    // Add layouts (ShellRoutes) - each layout wraps its children
    final mergedLayouts = _mergeLayouts();
    for (final layout in mergedLayouts) {
      goRoutes.add(
        ShellRoute(
          builder: (context, state, shellChild) => layout.builder(shellChild),
          routes: layout.children.map((child) => _buildGoRoute(child)).toList(),
        ),
      );
    }

    return goRoutes;
  }

  /// Merge layouts sharing the same [LayoutDefinition.id].
  ///
  /// Layouts without an ID remain separate ShellRoutes.
  /// When multiple layouts share an ID, children are concatenated
  /// in registration order and the first builder wins.
  List<LayoutDefinition> _mergeLayouts() {
    final merged = <String, LayoutDefinition>{};
    final anonymous = <LayoutDefinition>[];

    for (final layout in _layouts) {
      if (layout.id == null) {
        anonymous.add(layout);
        continue;
      }

      if (merged.containsKey(layout.id)) {
        merged[layout.id!] = LayoutDefinition(
          id: layout.id,
          builder: merged[layout.id!]!.builder,
          children: [...merged[layout.id!]!.children, ...layout.children],
        );
      } else {
        merged[layout.id!] = layout;
      }
    }

    return [...merged.values, ...anonymous];
  }

  /// Merged layout definitions. Exposed for testing layout merging behavior.
  @visibleForTesting
  List<LayoutDefinition> get mergedLayouts => _mergeLayouts();

  /// Build a single GoRoute from a RouteDefinition.
  GoRoute _buildGoRoute(RouteDefinition route) {
    return GoRoute(
      path: route.fullPath,
      name: route.routeName,
      pageBuilder: (context, state) {
        // Store current state and route for Request.route() / title access
        _currentState = state;
        _currentRoute = route;

        // Push the route-level title to TitleManager immediately.
        TitleManager.instance.setRouteTitle(route.routeTitle);

        // Wrap widget with middleware guard
        final widget = _MiddlewareGuard(
          route: route,
          pathParameters: state.pathParameters,
        );
        return _buildPage(widget, route, state);
      },
    );
  }

  /// Build the page with appropriate transition.
  Page<dynamic> _buildPage(
    Widget child,
    RouteDefinition route,
    GoRouterState state,
  ) {
    // An opaque background, so a page under a transition does not show through
    // the page on top of it.
    //
    // This used to be `Material(type: MaterialType.canvas)`, which paints
    // `Theme.canvasColor` (`material.dart:460`), and `fluttersdk_wind` sets
    // that to `Colors.transparent` on purpose (`wind_theme_data.dart:514`) so
    // a Material surface never paints over a Wind `bg-*` className. Every page
    // in every wind app was therefore transparent, and the comment on this line
    // claimed the opposite for as long as it has existed.
    //
    // Nothing showed it until routes started stacking. `to()` calls `go()`,
    // which replaces the whole page list, so there was never a second page
    // underneath to show through. A `.stacked()` route puts one there, and the
    // outgoing page is then visible THROUGH the incoming one for the length of
    // the push: on iOS it sits at the Cupertino parallax offset with the new
    // page drawn over it, and only disappears when the animation ends and the
    // Navigator offstages the route below an opaque one.
    //
    // `scaffoldBackgroundColor` rather than `canvasColor`, because it is what
    // wind fills from its `background` color and is opaque. An explicit color
    // also stops `MaterialType.canvas` reading the theme at all. A host that
    // makes this color transparent is saying its pages are transparent, which
    // is a choice rather than an accident.
    //
    // Read through a `Builder` so the theme comes from inside `MaterialApp`.
    // The `pageBuilder` context go_router hands us sits above the app's own
    // `Theme`, and reading there would find the default rather than the host's.
    final Widget opaqueChild = Builder(
      builder: (context) => Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: child,
      ),
    );

    // The name a NavigatorObserver will read off this page.
    //
    // `GoRoute.name` names the ROUTE and never reaches `RouteSettings`, so
    // without this every observer sees null and cannot tell one screen from
    // another. That silently disables anything screen-aware: analytics,
    // breadcrumb trails, and Sentry's web release health, which starts a
    // session only when it sees this value change and otherwise reports zero
    // sessions forever with nothing in any log to explain it.
    //
    // Falls back to the path because `.name()` is optional and most routes
    // skip it, so keying only on `routeName` would leave the common case as
    // broken as before. The path is always present and already unique.
    final pageName = route.routeName ?? route.fullPath;

    // Null means the route named nothing, which is the only case the default
    // covers. A route that explicitly asks for `none` is opting OUT of an
    // app-wide default rather than failing to have an opinion, and a sentinel
    // value cannot tell those two apart.
    final RouteTransition transition =
        route.declaredTransition ?? defaultTransition;

    switch (transition) {
      case RouteTransition.platform:
        return MagicPlatformPage<dynamic>(
          key: state.pageKey,
          name: pageName,
          // Only this transition installs a gesture, so it is the only one
          // where refusing it means anything.
          swipeBack: route.isSwipeBackAllowed ?? true,
          child: opaqueChild,
        );

      case RouteTransition.fade:
        return CustomTransitionPage(
          key: state.pageKey,
          name: pageName,
          child: opaqueChild,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        );

      case RouteTransition.slideRight:
        return CustomTransitionPage(
          key: state.pageKey,
          name: pageName,
          child: opaqueChild,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Incoming page slides from right
            final slideIn =
                Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                );

            // Outgoing page slides to left
            final slideOut =
                Tween<Offset>(
                  begin: Offset.zero,
                  end: const Offset(-0.3, 0),
                ).animate(
                  CurvedAnimation(
                    parent: secondaryAnimation,
                    curve: Curves.easeOutCubic,
                  ),
                );

            return SlideTransition(
              position: slideOut,
              child: SlideTransition(position: slideIn, child: child),
            );
          },
        );

      case RouteTransition.slideUp:
        return CustomTransitionPage(
          key: state.pageKey,
          name: pageName,
          child: opaqueChild,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            );
          },
        );

      case RouteTransition.scale:
        return CustomTransitionPage(
          key: state.pageKey,
          name: pageName,
          child: opaqueChild,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
        );

      case RouteTransition.none:
        // No animation - instant page switch
        return NoTransitionPage(
          key: state.pageKey,
          name: pageName,
          child: opaqueChild,
        );
    }
  }

  /// Handle global redirects (sync only).
  ///
  /// Runs before any page builds. Redirect-style guards drive it: every
  /// global + route middleware's [MagicMiddleware.redirectTarget] is
  /// evaluated for the matched location and the first non-null target wins.
  /// Resolving redirects here (pre-build) instead of imperatively from a
  /// guard widget keeps the destination view mounting exactly once.
  String? _handleRedirect(BuildContext context, GoRouterState state) {
    // Evaluate redirect-style guards synchronously, pre-build.
    final location = state.matchedLocation;
    final route = _resolveRoute(state);
    final middlewares = <MagicMiddleware>[
      ...Kernel.globalMiddleware,
      if (route != null) ...Kernel.resolveAll(route.middlewares),
    ];
    for (final middleware in middlewares) {
      final target = middleware.redirectTarget(location);
      if (target != null && target != location) {
        return target;
      }
    }
    return null;
  }

  /// Resolve the [RouteDefinition] whose pattern matches [state].
  ///
  /// Searches top-level routes and every layout's children. Matches on the
  /// configured full path pattern (`state.fullPath`), so it works for static
  /// and parameterized routes alike. Returns `null` when no route matches.
  RouteDefinition? _resolveRoute(GoRouterState state) {
    final fullPath = state.fullPath;
    if (fullPath == null) return null;
    for (final route in _routes) {
      if (route.fullPath == fullPath) return route;
    }
    for (final layout in _layouts) {
      for (final child in layout.children) {
        if (child.fullPath == fullPath) return child;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Navigation Methods (Context-Free!)
  // ---------------------------------------------------------------------------

  /// Navigate to a path.
  ///
  /// ```dart
  /// Route.to('/dashboard');
  /// Route.to('/users/42');
  /// ```
  ///
  /// Replaces the page stack, which is what a tab or a nav destination wants.
  /// A route marked [RouteDefinition.stacked] is pushed instead, so it can be
  /// popped, swiped back, and reached by the Android back button.
  ///
  /// On a stacked route, navigating to the path already showing turns on the
  /// query rather than the path:
  ///
  /// - no [queryParameters]: nothing happens. Asking for the screen you are on
  ///   is a re-tapped destination, not a request to clear its query.
  /// - [queryParameters] given: the top page is swapped, so the pages under
  ///   it survive and back leaves the screen rather than stepping through
  ///   every query the reader passed through. The screen REBUILDS rather
  ///   than remounting, which is what a query change does everywhere in
  ///   Magic, so read the query in `build` and never in `initState`.
  void to(String path, {Map<String, String>? queryParameters}) {
    if (_router == null) {
      throw StateError(
        'Router not initialized. Make sure to use routerConfig with MaterialApp.router first.',
      );
    }

    final current = currentLocation;
    final target = queryParameters != null && queryParameters.isNotEmpty
        ? Uri(path: path, queryParameters: queryParameters).toString()
        : path;

    // 1. Decide before recording anything, because one branch navigates
    //    nowhere and would otherwise leave a history entry for a move that
    //    never happened.
    //
    //    `go()` replaces the whole page list, which is why a `to()`-only app
    //    never has anything to pop: no back gesture, and Flutter reports
    //    `canHandlePop: false` to the platform, so Android's system back
    //    leaves the app instead of going back. A route marked `.stacked()`
    //    pushes instead, and `back()` still prefers the native pop, so the
    //    history fallback keeps covering every route that does not.
    if (_shouldStack(path)) {
      // Same screen, and what to do turns on the QUERY rather than the path.
      // `currentLocation` always carries one; the target carries one only
      // when the caller passed `queryParameters`.
      if (current != null &&
          Uri.parse(current).path == Uri.parse(target).path) {
        // The caller named no query, so this is a nav destination re-tapped:
        // asking for the screen you are on, not asking to clear its tab.
        // Pushing would stack the screen on itself and `go()` would replace
        // the page list and throw away the stack the reader built getting
        // here, so the honest answer is neither.
        if (Uri.parse(target).query.isEmpty) return;

        // A query the caller DID name is a move: switching a tab on the
        // page you are on. The top page is swapped rather than stacked, so
        // back leaves the screen instead of stepping through every tab the
        // reader looked at, and the pages underneath survive.
        //
        // `replace` rather than `pushReplacement`, and the reason is
        // consistency rather than preference. go_router keys a declarative
        // page on the matched PATH and not the query, so a query change
        // rebuilds the screen and never remounts it: that is what `go()` does
        // for every unstacked route in this framework today, measured.
        // `pushReplacement` would remount instead, and only when something
        // sits underneath, since it falls back to the declarative list when
        // the stack would empty. One verb behaving two ways by stack depth is
        // worse than every verb behaving one way.
        //
        // What this costs is that a screen has to read its query where a
        // rebuild can see it. `doc/basics/routing.md` says so.
        //
        // The identical query lands here too and needs no branch of its own:
        // a guard for it survived its own mutation test, which is the tell
        // that it was an optimisation wearing the clothes of a behaviour.
        _router!.replace(target);
        return;
      }

      // No history entry, deliberately. The push IS the record: `back()`
      // prefers the native pop, which consumes the page and would leave a
      // string behind naming the location it just landed on, so the next
      // press would `go()` there and look like a press that did nothing.
      // The imperative `push()` records nothing for the same reason.
      _router!.push(target);
      return;
    }

    // 2. Record current location before replacing it.
    if (current != null) {
      _recordHistory(current);
    }

    _router!.go(target);
  }

  /// Whether navigating to [path] should push rather than replace.
  ///
  /// Matches on the route's configured pattern, so `/monitors/:id` answers for
  /// `/monitors/42`. An unregistered path takes the router default, because a
  /// path with no definition has nothing better to say.
  bool _shouldStack(String path) {
    for (final route in _allRoutes()) {
      if (_pathMatchesPattern(path, route.fullPath)) {
        return route.isStacked ?? defaultStacked;
      }
    }

    return defaultStacked;
  }

  /// Every registered route, top-level and inside a layout.
  Iterable<RouteDefinition> _allRoutes() sync* {
    yield* _routes;
    for (final layout in _layouts) {
      yield* layout.children;
    }
  }

  /// Whether a concrete [path] is an instance of a route [pattern].
  ///
  /// Segment by segment, with a `:param` segment matching any single non-empty
  /// one. Query and fragment are stripped first, because `to()` is given a
  /// location and the table holds patterns.
  static bool _pathMatchesPattern(String path, String pattern) {
    final String bare = Uri.parse(path).path;
    if (bare == pattern) return true;

    final List<String> actual = bare.split('/');
    final List<String> expected = pattern.split('/');
    if (actual.length != expected.length) return false;

    for (int i = 0; i < expected.length; i++) {
      if (expected[i].startsWith(':')) {
        if (actual[i].isEmpty) return false;
        continue;
      }
      if (expected[i] != actual[i]) return false;
    }

    return true;
  }

  /// Navigate to a named route.
  ///
  /// Behaves exactly like [to] once the name is resolved, [RouteDefinition
  /// .stacked] included.
  ///
  /// ```dart
  /// MagicRouter.instance.toNamed('users.show', pathParameters: {'id': '42'});
  /// ```
  void toNamed(
    String name, {
    Map<String, String> pathParameters = const {},
    Map<String, String> queryParameters = const {},
  }) {
    if (_router == null) {
      throw StateError(
        'Router not initialized. Make sure to use routerConfig with MaterialApp.router first.',
      );
    }

    // The name is resolved to a location and handed to `to()`, so one route
    // behaves one way whichever verb reaches it. This used to call `goNamed()`
    // directly, which meant a route marked `.stacked()` pushed by path and
    // REPLACED by name: no back gesture, and Flutter reporting
    // `canHandlePop: false` so Android's system back left the app. Nothing at
    // the call site said the verb decided that.
    to(
      _router!.namedLocation(
        name,
        pathParameters: pathParameters,
        queryParameters: queryParameters,
      ),
    );
  }

  /// Push a new route onto the stack.
  ///
  /// Unlike `to()`, this preserves the navigation stack.
  ///
  /// ```dart
  /// Route.push('/details');
  /// ```
  void push(String path) {
    _router!.push(path);
  }

  /// Go back to the previous route.
  ///
  /// Tries native pop first. When `canPop()` is false (e.g. after a
  /// cross-shell `go()` navigation), falls back to the internal history
  /// stack. If history is also empty, navigates to [fallback] when
  /// provided, otherwise does nothing.
  ///
  /// ```dart
  /// Route.back();
  /// Route.back(fallback: '/home');
  /// ```
  void back({String? fallback}) {
    if (_router == null) {
      throw StateError(
        'Router not initialized. Make sure to use routerConfig with MaterialApp.router first.',
      );
    }

    // 1. Prefer GoRouter pop when available (syncs state + preserves
    //    custom page transitions on reverse animation).
    if (_router!.canPop()) {
      _router!.pop();
      return;
    }

    // 2. Fall back to history stack.
    if (_history.isNotEmpty) {
      final previous = _history.removeLast();
      _router!.go(previous);
      return;
    }

    // 3. Use explicit fallback if provided.
    if (fallback != null) {
      _router!.go(fallback);
    }
  }

  /// Replace the current route.
  ///
  /// History is left untouched — `back()` still returns to the route
  /// that was active *before* the replaced route, not the replaced route
  /// itself. This matches the "swap in place" semantic: the user never
  /// consciously visited the old route, so it shouldn't appear in history.
  ///
  /// ```dart
  /// Route.replace('/home');
  /// ```
  void replace(String path) {
    if (_router == null) {
      throw StateError(
        'Router not initialized. Make sure to use routerConfig with MaterialApp.router first.',
      );
    }

    _router!.replace(path);
  }

  // ---------------------------------------------------------------------------
  // Parameter Access
  // ---------------------------------------------------------------------------

  /// Get a path parameter from the current route.
  ///
  /// ```dart
  /// // For route '/users/:id', accessing '/users/42':
  /// final id = MagicRouter.instance.pathParameter('id'); // '42'
  /// ```
  String? pathParameter(String key) {
    return _currentState?.pathParameters[key];
  }

  /// Get a query parameter from the current route.
  ///
  /// ```dart
  /// // For '/search?q=flutter':
  /// final query = MagicRouter.instance.queryParameter('q'); // 'flutter'
  /// ```
  String? queryParameter(String key) {
    return _currentState?.uri.queryParameters[key];
  }

  /// Get the current route location (path + query string).
  ///
  /// Returns `null` if no route state is available yet.
  ///
  /// ```dart
  /// final location = MagicRouter.instance.currentLocation;
  /// // e.g. '/invitations/abc123/accept'
  /// ```
  String? get currentLocation => _currentState?.uri.toString();

  /// Get the [RouteDefinition] resolved for the current location.
  ///
  /// Returns `null` when no route has resolved yet (the router has not
  /// been built, or the initial route has not finished its first build
  /// pass). Updates reactively as navigation advances — every successful
  /// `_buildGoRoute` page builder records the active definition before
  /// rendering the page.
  ///
  /// Consumers (e.g. the dusk middleware enricher) use this to walk the
  /// active route's `middlewares` list without depending on the private
  /// router state.
  ///
  /// ```dart
  /// final route = MagicRouter.instance.currentRoute;
  /// final names = route?.middlewares ?? const [];
  /// ```
  RouteDefinition? get currentRoute => _currentRoute;

  /// Get the current route path (without query string).
  ///
  /// Returns `null` if no route state is available yet.
  ///
  /// ```dart
  /// final path = MagicRouter.instance.currentPath;
  /// // e.g. '/profile'
  /// ```
  String? get currentPath => _currentState?.uri.path;

  // ---------------------------------------------------------------------------
  // Intended URL (Redirect-After-Login)
  // ---------------------------------------------------------------------------

  /// Save an intended URL before redirecting to login.
  ///
  /// Call this in auth middleware before sending the user to the login page.
  /// After successful login, use [pullIntendedUrl] to redirect back.
  ///
  /// ```dart
  /// MagicRouter.instance.setIntendedUrl('/invitations/abc/accept');
  /// MagicRoute.to('/auth/login');
  /// ```
  void setIntendedUrl(String url) => _intendedUrl = url;

  /// Get and clear the intended URL (one-time read).
  ///
  /// Returns `null` if no intended URL was saved.
  /// The URL is cleared after reading to prevent stale redirects.
  ///
  /// ```dart
  /// final intended = MagicRouter.instance.pullIntendedUrl();
  /// MagicRoute.to(intended ?? '/');
  /// ```
  String? pullIntendedUrl() {
    final url = _intendedUrl;
    _intendedUrl = null;
    return url;
  }

  /// Whether there is a pending intended URL.
  bool get hasIntendedUrl => _intendedUrl != null;

  /// Get all path parameters.
  Map<String, String> get pathParameters {
    return _currentState?.pathParameters ?? {};
  }

  /// Get all query parameters.
  Map<String, String> get queryParameters {
    return _currentState?.uri.queryParameters ?? {};
  }

  // ---------------------------------------------------------------------------
  // History
  // ---------------------------------------------------------------------------

  /// The number of entries in the navigation history.
  ///
  /// Primarily exposed for testing purposes.
  int get historyDepth => _history.length;

  /// Record a location in the navigation history.
  ///
  /// Deduplicates consecutive identical entries and evicts the oldest
  /// entry when the history exceeds [_maxHistorySize].
  void _recordHistory(String location) {
    if (_history.isNotEmpty && _history.last == location) {
      return;
    }

    if (_history.length >= _maxHistorySize) {
      _history.removeAt(0);
    }

    _history.add(location);
  }

  // ---------------------------------------------------------------------------
  // Title Management
  // ---------------------------------------------------------------------------

  /// Called when the router delegate notifies of a route change.
  ///
  /// Reads the current [RouteDefinition]'s title and pushes it to
  /// [TitleManager]. Routes without a title clear the route-level title,
  /// allowing [TitleManager] to fall back to the app title.
  void _onRouteChanged() {
    // Title is applied in pageBuilder where the RouteDefinition is available.
    // This listener ensures the title updates even when GoRouter re-evaluates
    // routes without a full page rebuild (e.g. redirect resolution).
    TitleManager.instance.setRouteTitle(_currentRoute?.routeTitle);
  }

  // ---------------------------------------------------------------------------
  // Reset (Testing)
  // ---------------------------------------------------------------------------

  /// Reset the router (useful for testing).
  static void reset() {
    _instance?._router?.routerDelegate.removeListener(
      _instance!._onRouteChanged,
    );
    // Dispose the GoRouter so it releases its internal subscription to the
    // refreshListenable (the auth state notifier). Dropping the reference alone
    // would leak that listener on the long-lived notifier, and the orphaned
    // router would keep reacting to auth changes.
    _instance?._router?.dispose();
    _instance?._routes.clear();
    _instance?._layouts.clear();
    _instance?._observers.clear();
    _instance?._router = null;
    _instance?._currentRoute = null;
    _instance?._isBuilt = false;
    _instance?._intendedUrl = null;
    _instance?._history.clear();
    TitleManager.reset();
    _instance = null;
  }
}

// ---------------------------------------------------------------------------
// Middleware Guard Widget
// ---------------------------------------------------------------------------

/// A widget that runs middleware before showing the route content.
///
/// This handles async middleware execution and either shows the
/// page content or blocks/redirects based on middleware results.
class _MiddlewareGuard extends StatefulWidget {
  final RouteDefinition route;
  final Map<String, String> pathParameters;

  const _MiddlewareGuard({required this.route, required this.pathParameters});

  @override
  State<_MiddlewareGuard> createState() => _MiddlewareGuardState();
}

class _MiddlewareGuardState extends State<_MiddlewareGuard> {
  bool _isChecking = true;
  bool _isAllowed = false;

  @override
  void initState() {
    super.initState();
    _runMiddleware();
  }

  Future<void> _runMiddleware() async {
    // Yield execution to allow build to finish
    await Future.delayed(Duration.zero);

    // Collect middleware: global + route-specific
    final middlewares = <MagicMiddleware>[];

    // Add global middleware
    middlewares.addAll(Kernel.globalMiddleware);

    // Add route-specific middleware.
    //
    // No guard against `resolveAll` throwing here, deliberately. The router
    // validates every registered route's middleware when it builds
    // (`_assertMiddlewareResolvable`), so an unresolvable entry stops the app
    // at `Magic.init` and never reaches a navigation. A `try` here would be
    // handling a case that cannot occur, and a first version of this change
    // shipped one before the bootstrap check existed.
    //
    // "Every" is load-bearing and was briefly untrue: the check walked
    // `_routes`, and a route inside `MagicRoute.group(layout: ...)` lives in
    // the layout's children instead, so exactly the routes a shell or tab
    // layout holds could still arrive here unresolvable.
    middlewares.addAll(Kernel.resolveAll(widget.route.middlewares));

    // If no middleware, allow immediately
    if (middlewares.isEmpty) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _isAllowed = true;
        });
      }
      return;
    }

    // Execute middleware chain
    final allowed = await Kernel.execute(middlewares);

    if (mounted) {
      setState(() {
        _isChecking = false;
        _isAllowed = allowed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Still checking middleware
    if (_isChecking) {
      return const Center(child: CircularProgressIndicator());
    }

    // Middleware blocked - show nothing (redirect should handle)
    if (!_isAllowed) {
      return const SizedBox.shrink();
    }

    // Middleware passed - show the actual page
    return widget.route.buildWidget(widget.pathParameters);
  }
}
