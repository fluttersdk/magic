import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../http/kernel.dart';
import '../http/middleware/magic_middleware.dart';
import '../facades/auth.dart';
import '../facades/log.dart';
import 'browser_history_stub.dart'
    if (dart.library.js_interop) 'browser_history_web.dart'
    as browser_history;
import 'magic_overlay_page.dart';
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

  /// Debug only: the shell that first built each layout widget type.
  ///
  /// The shell's slot in [_mergeLayouts] and its layout id; see
  /// [_checkDuplicateShell].
  final Map<Type, ({int slot, String? id})> _shellSlotByWidgetType = {};

  /// Debug only: the widget types already reported as built by two shells.
  final Set<Type> _reportedDuplicateShells = {};

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

  /// An overlay location reached cold, pushed over its base once that builds.
  ///
  /// Set by [_handleRedirect], consumed by [_pushPendingOverlay].
  String? _pendingOverlay;

  /// The concrete base location [_pendingOverlay] waits to land on.
  String? _pendingBase;

  /// The go_router routes built for overlay definitions.
  final Set<GoRoute> _overlayGoRoutes = {};

  /// The dismiss guard of every route that has one, by its go_router route.
  ///
  /// These are the only routes with a go_router `onExit`, on every platform.
  final Map<GoRoute, bool Function()> _exitGuards = {};

  /// Page keys whose exit the guard granted in the current event.
  ///
  /// go_router finishes a guarded pop in a microtask, so two pops in one
  /// handler both reach the same page; the second is refused here instead
  /// of completing the page's result a second time.
  final Set<LocalKey> _grantedExits = {};

  /// Steps the browser history back one entry; null off the web.
  ///
  /// On the web a close magic itself drives (`back()`, a sheet's scrim or
  /// drag) of a page this router pushed goes through the browser's own Back
  /// rather than a new history entry. A test that stands in for the browser
  /// sets it before the router builds.
  @visibleForTesting
  void Function()? browserBack = browser_history.browserHistoryBack;

  /// Pushed pages whose push the browser recorded as an entry of its own,
  /// directly after the entry of the stack beneath them.
  ///
  /// Insertion ordered and bounded by [_maxOwnEntries]; a key can come back
  /// through browser Forward, so it is not dropped when its page closes.
  final Set<LocalKey> _ownEntries = <LocalKey>{};

  /// How many page keys [_ownEntries] keeps, oldest dropped first.
  static const int _maxOwnEntries = 50;

  /// The key [_pushRecordingEntry] recorded last, dropped again when the
  /// next push finds it was never reported on its own.
  LocalKey? _lastOwnedPush;

  /// The browser entry a step back left, while the browser has not answered.
  RouteInformation? _stepFrom;

  /// Navigations asked for while a step back was in flight, run once the
  /// browser has answered so the restored stack does not replace them.
  final List<VoidCallback> _afterStep = [];

  /// Runs when a step back is given up, set by the close that started it.
  VoidCallback? _onStepGivenUp;

  /// Fires [_giveUpStep] when the browser does not answer a step back.
  Timer? _stepTimer;

  /// How long a step back waits for the browser before giving up on it.
  static const Duration _stepTimeout = Duration(seconds: 1);

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

  /// Every registered route, including those declared inside a layout group.
  ///
  /// [routes] holds the top-level table only; a route registered through
  /// `MagicRoute.group(layout: ...)` lives under its layout and appears here.
  List<RouteDefinition> get allRoutes => List.unmodifiable(_allRoutes());

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
      if (browserBack != null) {
        _router!.routeInformationProvider.addListener(_onRouteInformation);
      }
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
    var offending = 0;

    for (final route in _allRoutes()) {
      if (!seen.add(route)) continue;

      final entries = Kernel.unresolvable(route.middlewares);
      if (entries.isEmpty) continue;

      // Counted per route rather than per problem: one route naming two
      // unregistered aliases is one route with two lines under it, and a
      // header saying "2 routes" over a single path is the same miscount the
      // identity set removes from the other direction.
      offending++;

      for (final entry in entries) {
        // `fullPath`, not `path`: a route inside `MagicRoute.group(prefix:)`
        // carries the bare `/users` in `path` while the app answers at
        // `/admin/users`. The error exists to be searched for, so it has to
        // name the address that exists.
        problems.add('${route.fullPath}: ${Kernel.unresolvableMessage(entry)}');
      }
    }

    if (problems.isEmpty) return;

    throw StateError(
      'Unresolvable route middleware on $offending '
      'route${offending == 1 ? '' : 's'}:\n  ${problems.join('\n  ')}',
    );
  }

  /// Every overlay's base names a registered page, checked when the router
  /// builds.
  ///
  /// A base that matches nothing would only surface on a cold entry, as a
  /// `Route not found` for the base rather than for the declaration that
  /// named it, so it stops the app at bootstrap instead. A base that is
  /// itself an overlay is refused too: the cold entry would chain to its base
  /// and drop the first sheet.
  void _assertOverlayBasesRegistered() {
    final problems = <String>[];

    for (final route in _allRoutes()) {
      final String? base = route.overlayBase;
      if (base == null) continue;

      final RouteDefinition? target = _findRoute(base);
      if (target == null) {
        problems.add('${route.fullPath}: base $base is not a registered route');
      } else if (target.isOverlay) {
        problems.add('${route.fullPath}: base $base is itself an overlay');
      }

      // A cold entry fills the base's parameters from the overlay's own
      // location, so the overlay has to carry every one of them.
      final Set<String> own = _parameterNames(route.fullPath).toSet();
      for (final name in _parameterNames(base)) {
        if (!own.contains(name)) {
          problems.add(
            '${route.fullPath}: base $base needs :$name, which the overlay '
            'path does not declare',
          );
        }
      }
    }

    if (problems.isEmpty) return;

    throw StateError(
      'Invalid overlay base:\n  ${problems.toSet().join('\n  ')}',
    );
  }

  /// Build the GoRouter from registered definitions.
  GoRouter _buildRouter() {
    _assertMiddlewareResolvable();
    _assertOverlayBasesRegistered();

    // A `.stacked()` route is PUSHED by `to()`, and go_router reports a push to
    // the engine under the address of the page beneath it unless this is on.
    // On the web that is the address bar: a detail screen kept the list's URL
    // and could not be copied, shared or reloaded. go_router discourages the
    // flag because a pushed page's URL is not always deep-linkable; here every
    // route is a full path the router matches on its own, stacked or not, so
    // the reported address always matches a route. It covers every push, not
    // only `to()` on a stacked route: `MagicRoute.push()`, `replace()` over a
    // pushed page and a raw go_router `push` report their own address too.
    // Global to go_router and read on every platform, but only the web shows
    // it, as the address; set where the one router is built.
    GoRouter.optionURLReflectsImperativeAPIs = true;

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
    for (var slot = 0; slot < mergedLayouts.length; slot++) {
      final layout = mergedLayouts[slot];

      // An overlay declared in a layout group keeps the group's prefix and
      // middleware but is lifted out of the shell: it opens on the root
      // navigator, and go_router refuses a shell child that names the root
      // key. `MagicRoute.layout(routes:)` also lands its routes in `_routes`,
      // so one already added above is not added twice.
      final pages = <RouteDefinition>[];
      for (final child in layout.children) {
        if (!child.isOverlay) {
          pages.add(child);
        } else if (!_routes.contains(child)) {
          goRoutes.add(_buildGoRoute(child));
        }
      }
      if (pages.isEmpty) continue;

      goRoutes.add(
        ShellRoute(
          builder: (context, state, shellChild) {
            final shell = layout.builder(shellChild);
            if (kDebugMode) _checkDuplicateShell(slot, layout.id, shell);
            return shell;
          },
          routes: pages.map((child) => _buildGoRoute(child)).toList(),
        ),
      );
    }

    return goRoutes;
  }

  /// Debug only: say so when two distinct shells build the same widget type.
  ///
  /// A host that gives two groups different (or no) `layoutId` while their
  /// layouts build the same widget gets two ShellRoutes, and every crossing
  /// between them tears the shell down and rebuilds it. Two different explicit
  /// ids are the documented way to keep two shells apart on purpose (an
  /// immersive route beside the app shell), so only a pair where one side has
  /// no id is reported. Recorded lazily at build, because a layout builder
  /// must not run at router build time, and reported once per type.
  /// `debugPrint`, not the Log facade, for the reason given in
  /// [_resolveAuthRefreshListenable].
  void _checkDuplicateShell(int slot, String? id, Widget shell) {
    final type = shell.runtimeType;
    final first = _shellSlotByWidgetType.putIfAbsent(
      type,
      () => (slot: slot, id: id),
    );
    if (first.slot == slot) return;
    if (first.id != null && id != null) return;
    if (!_reportedDuplicateShells.add(type)) return;

    debugPrint(
      'MagicRouter: two groups build $type as separate shells; give them the '
      'same layoutId to share one shell, or a unique id to keep them separate '
      'on purpose.',
    );
  }

  /// Merge layouts sharing the same [LayoutDefinition.id].
  ///
  /// Shells come out in first-registration order, anonymous ones where they
  /// were registered: go_router matches ShellRoutes top to bottom, so a named
  /// shell holding a catch-all must not jump ahead of a guest shell that was
  /// registered before it. A named group joins the slot of its id's first
  /// registration. Layouts without an ID remain separate ShellRoutes. When
  /// multiple layouts share an ID, children are concatenated in registration
  /// order and the first builder wins.
  List<LayoutDefinition> _mergeLayouts() {
    final slots = <LayoutDefinition>[];
    final slotById = <String, int>{};

    for (final layout in _layouts) {
      final id = layout.id;
      if (id == null) {
        slots.add(layout);
        continue;
      }

      final slot = slotById[id];
      if (slot == null) {
        slotById[id] = slots.length;
        slots.add(layout);
        continue;
      }

      slots[slot] = LayoutDefinition(
        id: id,
        builder: slots[slot].builder,
        children: [...slots[slot].children, ...layout.children],
      );
    }

    return slots;
  }

  /// Merged layout definitions. Exposed for testing layout merging behavior.
  @visibleForTesting
  List<LayoutDefinition> get mergedLayouts => _mergeLayouts();

  /// Build a single GoRoute from a RouteDefinition.
  GoRoute _buildGoRoute(RouteDefinition route) {
    final bool Function()? canDismiss = route.overlayCanDismiss;

    late final GoRoute goRoute;
    goRoute = GoRoute(
      path: route.fullPath,
      name: route.routeName,
      // An overlay belongs above every shell: inside a layout's navigator the
      // sheet and its scrim would cover only the content area.
      parentNavigatorKey: route.isOverlay ? navigatorKey : null,
      // go_router asks this before a pop it runs (a drag, a scrim tap, the
      // system back, `back()`) and before a new location replaces the page
      // (browser Back, a `to()` that replaces the stack). A push over the
      // sheet is not an exit and asks nothing. Only a guarded route takes
      // one: go_router then answers every pop of the page false and finishes
      // it in a microtask, which a `popUntil` over the page cannot get past.
      onExit: canDismiss == null
          ? null
          : (context, state) => _allowExit(state.pageKey, canDismiss),
      pageBuilder: (context, state) {
        // Store current state and route for Request.route() / title access.
        //
        // Skipped for a page under an open overlay. The root navigator builds
        // the sheet first and a layout's nested navigator builds the page
        // beneath it after, so the page would otherwise overwrite the sheet:
        // the title, `currentPath` and the same-path check in `to()` would
        // all answer for the page, and a second `to()` would stack a second
        // sheet. Only an overlay on top is special-cased; a page pushed over
        // another shell keeps the documented last-built answer.
        if (route.isOverlay || !_isOverlayOnTop()) {
          _currentState = state;
          _currentRoute = route;

          // Push the route-level title to TitleManager immediately.
          TitleManager.instance.setRouteTitle(route.routeTitle);
        }

        // Wrap widget with middleware guard
        final widget = _MiddlewareGuard(
          route: route,
          pathParameters: state.pathParameters,
        );
        return _buildPage(widget, route, state);
      },
    );
    if (route.isOverlay) _overlayGoRoutes.add(goRoute);
    if (canDismiss != null) _exitGuards[goRoute] = canDismiss;

    return goRoute;
  }

  /// The location of the top page in the delegate's stack, or null before
  /// anything is mounted.
  ///
  /// A pushed page's location lives on its [ImperativeRouteMatch]; the list's
  /// own `uri` stays the one the stack was built from.
  String? _topLocation() {
    final RouteMatchList stack = _router!.routerDelegate.currentConfiguration;
    final RouteMatch? top = stack.lastOrNull;
    if (top == null) return null;
    if (top is ImperativeRouteMatch) return top.matches.uri.toString();

    return stack.uri.toString();
  }

  /// Whether the top of the page stack the router is building is an overlay.
  bool _isOverlayOnTop() {
    final RouteMatch? top =
        _router?.routerDelegate.currentConfiguration.lastOrNull;

    return top != null && _overlayGoRoutes.contains(top.route);
  }

  /// Build the page with appropriate transition.
  Page<dynamic> _buildPage(
    Widget child,
    RouteDefinition route,
    GoRouterState state,
  ) {
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

    // A sheet is a frame over the page below, so it takes neither the opaque
    // background nor a page transition.
    if (route.isOverlay) {
      return MagicOverlayPage<dynamic>(
        key: state.pageKey,
        name: pageName,
        canDismiss: route.overlayCanDismiss,
        closesThroughBrowser: browserBack == null
            ? null
            : () => _ownsCurrentEntry(state.pageKey),
        stepBrowserBack: _stepBrowserBack,
        child: child,
      );
    }

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

    // After the guards, so a guard that sends the reader elsewhere wins
    // over building a base they may not see either.
    final String? base = route?.overlayBase;
    if (base != null && _isReplacingNavigation()) {
      return _deferOverlay(
        _fillPattern(base, state.pathParameters),
        state.uri.toString(),
      );
    }

    return null;
  }

  /// Whether the location being parsed replaces the whole page list.
  ///
  /// A `go()`, the initial location, a URL the platform reports without
  /// state (a reload, a typed address, a deep link) are all a `go`. A push,
  /// a replace, and browser Back or Forward, which come back as a `restore`
  /// of a stack the router already reported, are not. go_router hands the
  /// redirect no navigation type, but the provider's value is the very
  /// information the `Router` widget is parsing.
  bool _isReplacingNavigation() {
    final Object? info = _router?.routeInformationProvider.value.state;

    return info is RouteInformationState && info.type == NavigatingType.go;
  }

  /// Land a cold overlay entry on [base] and push [overlay] once it builds.
  ///
  /// go_router turns one location into one page unless the path nests, and
  /// an overlay's path need not extend its base's. So the replacing
  /// navigation is redirected to [base] and the overlay is pushed in the
  /// frame after, which is the stack a `to()` from the base would have
  /// built: closing the sheet leaves a real page underneath.
  String _deferOverlay(String base, String overlay) {
    final bool scheduled = _pendingOverlay != null;
    _pendingOverlay = overlay;
    _pendingBase = base;

    if (!scheduled) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _pushPendingOverlay(),
      );
    }

    return base;
  }

  /// Push the overlay [_deferOverlay] held back, once the navigation landed
  /// on its base.
  ///
  /// Anywhere else it is dropped: a guard on the base sent the reader to
  /// another page, or an open sheet refused to exit and the redirect to the
  /// base never applied. Pushing there would put the sheet over the wrong
  /// page, or stack a second sheet on the first.
  ///
  /// On the web it first waits, up to [_maxReportWaitFrames] frames, for the
  /// base to be reported to the browser. The `Router` reports in a post-frame
  /// callback registered after this one, and go_router's provider replaces
  /// the current entry on its first report. Pushing before it would make the
  /// sheet that first report, the only entry, and the first browser Back
  /// would leave the app instead of closing the sheet.
  void _pushPendingOverlay([int framesWaited = 0]) {
    final String? overlay = _pendingOverlay;
    final String? base = _pendingBase;
    if (overlay == null || _router == null) return;

    if (browserBack != null &&
        !_isReportedStack() &&
        framesWaited < _maxReportWaitFrames) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _pushPendingOverlay(framesWaited + 1),
      );
      WidgetsBinding.instance.scheduleFrame();
      return;
    }

    _pendingOverlay = null;
    _pendingBase = null;

    final RouteMatch? top =
        _router!.routerDelegate.currentConfiguration.lastOrNull;
    if (top == null || top.matchedLocation != base) return;

    _pushRecordingEntry(overlay);
  }

  /// How long a cold overlay entry waits for its base to reach the browser.
  ///
  /// The report lands in the first frame after the base builds; the bound
  /// only keeps a report that never comes from holding the sheet back.
  static const int _maxReportWaitFrames = 5;

  /// Whether the browser's current entry holds exactly the stack the router
  /// holds now.
  ///
  /// go_router's provider takes the information the router reported, or the
  /// one the browser restored, as its value; a navigation not reported yet
  /// carries a [RouteInformationState] instead. The entry's state is the
  /// encoded stack, page keys included, so two entries for the same address
  /// (a push of the location already shown) are told apart.
  bool _isReportedStack() {
    final RouteInformation value = _router!.routeInformationProvider.value;
    if (value.state is RouteInformationState) return false;

    final RouteInformation? stack = _router!.routeInformationParser
        .restoreRouteInformation(_router!.routerDelegate.currentConfiguration);

    return stack != null &&
        stack.uri.toString() == value.uri.toString() &&
        jsonEncode(stack.state) == jsonEncode(value.state);
  }

  /// Push [location], noting it on the web when it gets an entry of its own.
  ///
  /// It does when the browser's current entry holds the stack underneath:
  /// the router then reports the push as a new entry right after it, so
  /// stepping back from it lands on the page underneath. A push that finds
  /// the previous one not reported yet shares one entry with it, so the
  /// previous one loses its claim too.
  void _pushRecordingEntry(String location) {
    final bool ownEntry = browserBack != null && _isReportedStack();
    if (!ownEntry && _lastOwnedPush != null) {
      _ownEntries.remove(_lastOwnedPush);
      _lastOwnedPush = null;
    }

    _router!.push(location);
    if (!ownEntry) return;

    final RouteMatch? top =
        _router!.routerDelegate.currentConfiguration.lastOrNull;
    if (top is! ImperativeRouteMatch) return;

    _ownEntries.add(top.pageKey);
    _lastOwnedPush = top.pageKey;
    while (_ownEntries.length > _maxOwnEntries) {
      _ownEntries.remove(_ownEntries.first);
    }
  }

  /// The guarded route's `onExit` answer.
  ///
  /// A page already granted its exit in this event, or already gone from the
  /// stack, is refused: go_router would otherwise complete it twice.
  bool _allowExit(LocalKey key, bool Function() canDismiss) {
    if (_grantedExits.contains(key) || !_isInStack(key)) return false;
    if (!canDismiss()) return false;

    _grantedExits.add(key);
    Timer.run(() => _grantedExits.remove(key));

    return true;
  }

  /// Whether a page with [key] is in the stack the router holds.
  bool _isInStack(LocalKey key) {
    return _containsPage(
      _router!.routerDelegate.currentConfiguration.matches,
      key,
    );
  }

  /// Whether [matches], or a shell or push nested in them, holds [key].
  static bool _containsPage(List<RouteMatchBase> matches, LocalKey key) {
    for (final RouteMatchBase match in matches) {
      if (match.pageKey == key) return true;
      if (match is ShellRouteMatch && _containsPage(match.matches, key)) {
        return true;
      }
      if (match is ImperativeRouteMatch &&
          _containsPage(match.matches.matches, key)) {
        return true;
      }
    }

    return false;
  }

  /// Whether closing the top page, keyed [key], should step the browser back.
  ///
  /// True on the web for a page [_pushRecordingEntry] saw get an entry of its
  /// own, while the browser's current entry is still exactly that one and no
  /// step back is already under way. Anything else closes in the app, which
  /// adds an entry the old way rather than stepping into one the router
  /// cannot vouch for.
  bool _ownsCurrentEntry(LocalKey key) {
    if (browserBack == null || _isStepInFlight) return false;

    final RouteMatch? top =
        _router!.routerDelegate.currentConfiguration.lastOrNull;
    if (top is! ImperativeRouteMatch || top.pageKey != key) return false;

    return _ownEntries.contains(key) && _isReportedStack();
  }

  /// Whether a step back left an entry the browser has not answered for.
  bool get _isStepInFlight =>
      _stepFrom != null &&
      identical(_router?.routeInformationProvider.value, _stepFrom);

  /// Close the top page through the browser's Back instead of in the app.
  ///
  /// The browser answers with the entry before, which already holds the
  /// stack beneath, and go_router restores it exactly as for its own Back
  /// button, so no entry is added and Forward reopens the page.
  ///
  /// When no answer comes within [_stepTimeout] the step is given up and
  /// [onGivenUp] runs (a sheet a drag slid shut slides back up). Nothing
  /// closes in the app then: an in-app close would add an entry, and an
  /// answer the browser sends late would step back past it and reopen the
  /// page. A late answer is the browser's own restore of the entry before,
  /// applied like any browser Back.
  void _stepBrowserBack([VoidCallback? onGivenUp]) {
    final RouteInformation from = _router!.routeInformationProvider.value;
    _stepFrom = from;
    _onStepGivenUp = onGivenUp;
    _stepTimer?.cancel();
    _stepTimer = Timer(_stepTimeout, () => _giveUpStep(from));

    browserBack!();
  }

  /// Stop waiting for the answer to a step back from [from].
  ///
  /// Settles whenever that step is still the current one, including when
  /// the provider's value moved without a notification (go_router updates
  /// it silently when the router reports, after an in-app pop); only a step
  /// the browser really left unanswered runs its give-up callback.
  void _giveUpStep(RouteInformation from) {
    if (!identical(_stepFrom, from)) return;

    final VoidCallback? onGivenUp = _isStepInFlight ? _onStepGivenUp : null;
    _settleStep();
    onGivenUp?.call();
  }

  /// Provider listener on the web: a value other than the one a step back
  /// left is the browser's answer (or a navigation that overtook it).
  void _onRouteInformation() {
    if (_stepFrom == null || _isStepInFlight) return;

    _settleStep();
  }

  /// End a step back and run what waited for it, after the restored stack
  /// has been applied.
  void _settleStep() {
    _stepFrom = null;
    _onStepGivenUp = null;
    _stepTimer?.cancel();
    _stepTimer = null;
    if (_afterStep.isEmpty) return;

    final List<VoidCallback> pending = List.of(_afterStep);
    _afterStep.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final VoidCallback navigate in pending) {
        navigate();
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  /// Run [navigate] once nothing that closes the top page is still pending.
  ///
  /// A step back is answered by the browser later, and the stack it restores
  /// would replace a page pushed meanwhile, so the navigation waits for it.
  /// A guarded page's exit finishes in a microtask, and go_router then drops
  /// every page above the closed one, so ANY navigation asked for while a
  /// guarded page is on top runs in the next event, after any pop issued
  /// just before it, and still waits for a step back started meanwhile.
  ///
  /// A navigation that runs late does nothing once [reset] has dropped the
  /// router it was asked of.
  void _whenSettled(VoidCallback navigate) {
    void run() {
      if (_router == null) return;
      navigate();
    }

    if (_isStepInFlight) {
      _afterStep.add(run);
      return;
    }

    final RouteMatch? top =
        _router?.routerDelegate.currentConfiguration.lastOrNull;
    if (top != null && _exitGuards.containsKey(top.route)) {
      Timer.run(() => _isStepInFlight ? _afterStep.add(run) : run());
      return;
    }

    navigate();
  }

  /// Give up the top page's claim to its own browser entry.
  ///
  /// A replace keeps the page key, and the router reports the new stack as
  /// a NEW entry, so the entry before is the replaced page rather than the
  /// page beneath: stepping back from it would reopen the replaced page.
  void _disownTop() {
    final RouteMatch? top =
        _router!.routerDelegate.currentConfiguration.lastOrNull;
    if (top != null) _ownEntries.remove(top.pageKey);
    _lastOwnedPush = null;
  }

  /// Matches a `:name` path parameter, with go_router's optional `(regex)`.
  static final RegExp _parameterPattern = RegExp(
    r':(\w+)(\((?:\\.|[^\\()])+\))?',
  );

  /// The parameter names [pattern] declares, in order.
  static Iterable<String> _parameterNames(String pattern) {
    return _parameterPattern.allMatches(pattern).map((m) => m.group(1)!);
  }

  /// [pattern] with every parameter replaced by its value in [parameters].
  ///
  /// [_assertOverlayBasesRegistered] guarantees an overlay's path declares
  /// every parameter its base does, so each one has a value here.
  static String _fillPattern(String pattern, Map<String, String> parameters) {
    return pattern.replaceAllMapped(
      _parameterPattern,
      (m) => Uri.encodeComponent(parameters[m.group(1)!]!),
    );
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
  ///   Magic, so read the query in `build` (through [queryParameterOf] where
  ///   a [BuildContext] is at hand) and never in `initState`.
  void to(String path, {Map<String, String>? queryParameters}) {
    if (_router == null) {
      throw StateError(
        'Router not initialized. Make sure to use routerConfig with MaterialApp.router first.',
      );
    }

    _whenSettled(() => _to(path, queryParameters));
  }

  /// [to], once nothing that closes the top page is still pending.
  void _to(String path, Map<String, String>? queryParameters) {
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
      // Compared with the top of the stack the delegate holds, not with
      // `currentLocation`. That one names the page whose builder ran last,
      // which over a layout is the page BENEATH (the shell builds after the
      // pushed page), so a query swap pushed a second copy of the screen;
      // it also moves only when a page builds, so a second `to()` in the
      // same frame (a double click) stacked a second sheet. go_router
      // applies a push synchronously, so the delegate's top is right the
      // moment the first call returns.
      final String? onTop = _topLocation();

      // Same screen, and what to do turns on the QUERY rather than the path.
      // `currentLocation` always carries one; the target carries one only
      // when the caller passed `queryParameters`.
      if (onTop != null && Uri.parse(onTop).path == Uri.parse(target).path) {
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
        _disownTop();
        _router!.replace(target);
        return;
      }

      // NOTHING IS MOUNTED YET, so there is nothing to push ONTO, and pushing
      // anyway poisons every later match. go_router pushes onto
      // `routerDelegate.currentConfiguration`, and before the `Router` widget
      // has parsed a location that is `RouteMatchList.empty`, whose `uri` is a
      // bare `Uri()` with an EMPTY path. `RouteMatchList.copyWith` keeps it, so
      // the delegate reports `location: ''` back to Flutter.
      //
      // go_router guards its other two verbs against exactly this and not this
      // one: `pushReplacement` and `replace` both open with
      // `if (baseRouteMatchList.isEmpty) return newMatchList;`. `push` is the
      // single verb with no such bail-out, which is why this guard belongs at
      // the caller.
      //
      // WHAT THE EMPTY URI COSTS DEPENDS ON THE go_router VERSION, so no line
      // numbers here: this package allows `>=17.1.0 <19.0.0`.
      //
      //   - On 17.3.0 the decode path calls `findMatch` WITHOUT
      //     `RouteConfiguration.normalizeUri`, so the matcher runs
      //     `''.substring(1)` and throws a `RangeError`. In a release build
      //     that replaces the whole `Router` subtree with an `ErrorWidget`: a
      //     flat grey page with no layout. MEASURED on an iPhone on 2026-09-18
      //     from a tapped push notification on a cold start. Debug never gets
      //     there, because an assert one line earlier fires first, which is why
      //     no test and no simulator run had ever seen it.
      //   - On 18.0.1 that path normalises an empty uri to `/` first, so there
      //     is no crash. The empty `currentConfiguration.uri` is still real and
      //     still wrong: `currentLocation`, `pathParameter` and
      //     `queryParameter` all read it.
      //
      // `go()` rather than `push()`, and it costs nothing a reader can feel: a
      // push this early has nothing underneath it to pop back to, and a link
      // arriving from outside the app is where the reader arrives rather than
      // somewhere they stepped to.
      if (_router!.routerDelegate.currentConfiguration.isEmpty) {
        _router!.go(target);
        return;
      }

      // No history entry, deliberately. The push IS the record: `back()`
      // prefers the native pop, which consumes the page and would leave a
      // string behind naming the location it just landed on, so the next
      // press would `go()` there and look like a press that did nothing.
      // The imperative `push()` records nothing for the same reason.
      _pushRecordingEntry(target);
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
  ///
  /// An overlay always pushes: replacing the stack would take away the page
  /// it is meant to sit on.
  bool _shouldStack(String path) {
    final RouteDefinition? route = _findRoute(path);
    if (route == null) return defaultStacked;
    if (route.isOverlay) return true;

    return route.isStacked ?? defaultStacked;
  }

  /// The first registered route whose pattern [path] is an instance of.
  RouteDefinition? _findRoute(String path) {
    for (final route in _allRoutes()) {
      if (_pathMatchesPattern(path, route.fullPath)) return route;
    }

    return null;
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
    // The four sibling verbs all open with this and `push` did not, so a call
    // before `routerConfig` was ever read died on the `_router!` below with a
    // null-check message naming nothing. Review flagged it as pre-existing and
    // it is; it is fixed here because this method is being given a cold-start
    // guard in the same change, and the two states it can be in at cold start
    // should not report differently.
    if (_router == null) {
      throw StateError(
        'Router not initialized. Make sure to use routerConfig with MaterialApp.router first.',
      );
    }

    // The same empty-base hazard `to()` guards against, through the public
    // door. A cold-start deeplink routed through `MagicRoute.push` instead of
    // `MagicRoute.to` lands in the identical state, and this verb's whole
    // promise is to preserve a stack that does not exist yet.
    if (_router!.routerDelegate.currentConfiguration.isEmpty) {
      _router!.go(path);

      return;
    }

    _whenSettled(() => _pushRecordingEntry(path));
  }

  /// Go back to the previous route.
  ///
  /// Tries native pop first. When `canPop()` is false (e.g. after a
  /// cross-shell `go()` navigation), falls back to the internal history
  /// stack. If history is also empty, navigates to [fallback] when
  /// provided, otherwise does nothing.
  ///
  /// On the web, closing a page that `to()` or `push()` pushed over a page
  /// the browser already held an entry for steps the browser history back
  /// instead, so the browser adds no entry and its Back does not reopen the
  /// page. A second call before the browser has answered does nothing.
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

    // 1. On the web, close through the browser when the top page owns its
    //    entry, and not twice while it has not answered. The guard is asked
    //    first, so a refusal never moves the browser.
    if (_isStepInFlight) return;
    final RouteMatch? top =
        _router!.routerDelegate.currentConfiguration.lastOrNull;
    if (top != null &&
        _ownsCurrentEntry(top.pageKey) &&
        (_exitGuards[top.route]?.call() ?? true)) {
      _stepBrowserBack();
      return;
    }

    // 2. Prefer GoRouter pop when available (syncs state + preserves
    //    custom page transitions on reverse animation).
    if (_router!.canPop()) {
      _router!.pop();
      return;
    }

    // 3. Fall back to history stack.
    if (_history.isNotEmpty) {
      final previous = _history.removeLast();
      _router!.go(previous);
      return;
    }

    // 4. Use explicit fallback if provided.
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

    _whenSettled(() {
      _disownTop();
      _router!.replace(path);
    });
  }

  // ---------------------------------------------------------------------------
  // Parameter Access
  // ---------------------------------------------------------------------------

  /// Get a path parameter from the current route.
  ///
  /// Reads the state of the page whose builder ran last, which is not always
  /// the page on screen: across layout shells a pushed page is built before the
  /// shell underneath, so this answers with the page UNDER it. Code that has a
  /// [BuildContext] should use [pathParameterOf]; this stays for code that has
  /// none (a controller, a middleware).
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
  /// Shares [pathParameter]'s limit: it answers for the page built last. Use
  /// [queryParameterOf] where a [BuildContext] is at hand.
  ///
  /// ```dart
  /// // For '/search?q=flutter':
  /// final query = MagicRouter.instance.queryParameter('q'); // 'flutter'
  /// ```
  String? queryParameter(String key) {
    return _currentState?.uri.queryParameters[key];
  }

  /// Get a path parameter from the route page that [context] sits in.
  ///
  /// Unlike [pathParameter], this answers for the page the widget belongs to,
  /// not the page whose builder ran last. A page pushed across layout shells is
  /// built before the shell underneath is rebuilt, so the static reader hands
  /// the pushed page the parameters of the page under it.
  ///
  /// ```dart
  /// @override
  /// void didChangeDependencies() {
  ///   super.didChangeDependencies();
  ///   _id = MagicRouter.instance.pathParameterOf(context, 'id');
  /// }
  /// ```
  ///
  /// Call it from `didChangeDependencies` or `build`, never `initState`: it
  /// subscribes [context] to the router, which a context that is still being
  /// created cannot do.
  ///
  /// Throws a [GoError] when no router page sits above [context] (a widget
  /// pumped on its own). There is no fallback to [pathParameter]: that is the
  /// wrong page's value, and a caller that has no [BuildContext] should use
  /// [pathParameter] on purpose.
  String? pathParameterOf(BuildContext context, String key) {
    return GoRouterState.of(context).pathParameters[key];
  }

  /// Get a query parameter from the route page that [context] sits in.
  ///
  /// The query counterpart of [pathParameterOf], with the same contract: call
  /// it from `didChangeDependencies` or `build`, and it throws a [GoError]
  /// outside a router page rather than reading [queryParameter].
  String? queryParameterOf(BuildContext context, String key) {
    return GoRouterState.of(context).uri.queryParameters[key];
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

    // A stack the browser's entry does not hold, while that entry is one
    // already reported, is a change the app made without a push: a pop in
    // the app, or a redirect. It is reported as a NEW entry after the old
    // one, so the entry before no longer holds the stack beneath any page,
    // and no page may step back into it.
    if (browserBack != null &&
        _router!.routeInformationProvider.value.state
            is! RouteInformationState &&
        !_isReportedStack()) {
      _ownEntries.clear();
      _lastOwnedPush = null;
    }
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
    _instance?._shellSlotByWidgetType.clear();
    _instance?._reportedDuplicateShells.clear();
    _instance?._observers.clear();
    _instance?._router = null;
    _instance?._currentRoute = null;
    _instance?._isBuilt = false;
    _instance?._intendedUrl = null;
    _instance?._history.clear();
    _instance?._pendingOverlay = null;
    _instance?._pendingBase = null;
    _instance?._overlayGoRoutes.clear();
    _instance?._exitGuards.clear();
    _instance?._stepTimer?.cancel();
    // Set by `_buildRouter` on a static, so it outlives the instance; back to
    // go_router's default with the rest of the router's state.
    GoRouter.optionURLReflectsImperativeAPIs = false;
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
