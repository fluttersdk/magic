import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../http/kernel.dart';
import '../http/middleware/magic_middleware.dart';
import '../facades/log.dart';
import 'route_definition.dart';

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

  /// The built GoRouter instance (lazily created).
  GoRouter? _router;

  /// Current route state (for parameter access).
  GoRouterState? _currentState;

  /// Whether the router has been built.
  bool _isBuilt = false;

  /// Pending redirect from async middleware.
  String? _pendingRedirect;

  /// Saved intended URL for redirect-after-login pattern.
  String? _intendedUrl;

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
    _router ??= _buildRouter();
    _isBuilt = true;
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

  /// Build the GoRouter from registered definitions.
  GoRouter _buildRouter() {
    return GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: _initialLocation,
      routes: _buildRoutes(),
      redirect: _handleRedirect,
      onException: (context, state, router) {
        Log.warning('Route not found: ${state.uri}');
      },
    );
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
      goRoutes.add(ShellRoute(
        builder: (context, state, shellChild) => layout.builder(shellChild),
        routes: layout.children.map((child) => _buildGoRoute(child)).toList(),
      ));
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
          children: [
            ...merged[layout.id!]!.children,
            ...layout.children,
          ],
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
        // Store current state for Request.route() access
        _currentState = state;

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
    // Wrap child with opaque background to prevent overlap during transitions
    final opaqueChild = Material(
      type: MaterialType.canvas,
      child: child,
    );

    switch (route.transitionType) {
      case RouteTransition.fade:
        return CustomTransitionPage(
          key: state.pageKey,
          child: opaqueChild,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        );

      case RouteTransition.slideRight:
        return CustomTransitionPage(
          key: state.pageKey,
          child: opaqueChild,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Incoming page slides from right
            final slideIn = Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));

            // Outgoing page slides to left
            final slideOut = Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.3, 0),
            ).animate(CurvedAnimation(
              parent: secondaryAnimation,
              curve: Curves.easeOutCubic,
            ));

            return SlideTransition(
              position: slideOut,
              child: SlideTransition(
                position: slideIn,
                child: child,
              ),
            );
          },
        );

      case RouteTransition.slideUp:
        return CustomTransitionPage(
          key: state.pageKey,
          child: opaqueChild,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
        );

      case RouteTransition.scale:
        return CustomTransitionPage(
          key: state.pageKey,
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
          child: opaqueChild,
        );
    }
  }

  /// Handle global redirects (sync only).
  String? _handleRedirect(BuildContext context, GoRouterState state) {
    // Check for pending redirect from middleware
    if (_pendingRedirect != null) {
      final redirect = _pendingRedirect;
      _pendingRedirect = null;
      return redirect;
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
  void to(String path, {Map<String, String>? queryParameters}) {
    if (_router == null) {
      throw StateError(
        'Router not initialized. Make sure to use routerConfig with MaterialApp.router first.',
      );
    }

    if (queryParameters != null && queryParameters.isNotEmpty) {
      final uri = Uri(path: path, queryParameters: queryParameters);
      _router!.go(uri.toString());
    } else {
      _router!.go(path);
    }
  }

  /// Navigate to a named route.
  ///
  /// ```dart
  /// Route.toNamed('users.show', params: {'id': '42'});
  /// ```
  void toNamed(
    String name, {
    Map<String, String> pathParameters = const {},
    Map<String, String> queryParameters = const {},
  }) {
    _router!.goNamed(
      name,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
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
  /// ```dart
  /// Route.back();
  /// ```
  void back() {
    if (navigatorKey.currentState?.canPop() ?? false) {
      navigatorKey.currentState!.pop();
    }
  }

  /// Replace the current route.
  ///
  /// ```dart
  /// Route.replace('/home');
  /// ```
  void replace(String path) {
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
  // Reset (Testing)
  // ---------------------------------------------------------------------------

  /// Reset the router (useful for testing).
  static void reset() {
    _instance?._routes.clear();
    _instance?._layouts.clear();
    _instance?._router = null;
    _instance?._isBuilt = false;
    _instance?._intendedUrl = null;
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

  const _MiddlewareGuard({
    required this.route,
    required this.pathParameters,
  });

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

    // Add route-specific middleware
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
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Middleware blocked - show nothing (redirect should handle)
    if (!_isAllowed) {
      return const SizedBox.shrink();
    }

    // Middleware passed - show the actual page
    return widget.route.buildWidget(widget.pathParameters);
  }
}
