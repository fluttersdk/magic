import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../routing/magic_router.dart';
import '../routing/route_definition.dart';

/// The Magic Route Facade.
///
/// This is your Laravel-style routing API. Define routes with a clean,
/// expressive syntax and navigate anywhere without needing BuildContext.
///
/// ## Defining Routes
///
/// ```dart
/// // Simple route
/// MagicRoute.get('/', () => HomePage());
///
/// // With path parameters (Laravel's {id} → Magic's :id)
/// MagicRoute.get('/users/:id', (id) => UserPage(id: id));
///
/// // Fluent API
/// MagicRoute.get('/dashboard', DashboardController.index)
///     .name('dashboard')
///     .middleware([AuthMiddleware()])
///     .transition(RouteTransition.fade);
/// ```
///
/// ## Route Groups
///
/// ```dart
/// MagicRoute.group(
///   prefix: '/admin',
///   middleware: [AdminMiddleware()],
///   routes: () {
///     MagicRoute.get('/users', AdminUsersPage.new);
///     MagicRoute.get('/settings', AdminSettingsPage.new);
///   },
/// );
/// ```
///
/// ## Navigation (Context-Free!)
///
/// ```dart
/// // From anywhere - controllers, services, callbacks
/// MagicRoute.to('/dashboard');
/// MagicRoute.to('/users/42');
/// MagicRoute.back();
/// MagicRoute.replace('/home');
/// ```
class MagicRoute {
  // Prevent instantiation
  MagicRoute._();

  /// Current group context (for nested groups).
  static RouteGroup? _currentGroup;

  // ---------------------------------------------------------------------------
  // Route Registration
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Route Registration
  // ---------------------------------------------------------------------------

  /// Register a page route.
  ///
  /// This is the primary way to define navigation routes.
  ///
  /// ```dart
  /// // Simple route
  /// MagicRoute.page('/home', () => HomePage());
  ///
  /// // With parameters
  /// MagicRoute.page('/users/:id', (id) => UserPage(id: id));
  ///
  /// // Fluent chaining
  /// MagicRoute.page('/profile', ProfilePage.new)
  ///     .name('profile')
  ///     .transition(RouteTransition.slideRight);
  /// ```
  static RouteDefinition page(String path, Function handler) {
    final route = RouteDefinition(
      path: path,
      handler: handler,
      method: 'PAGE',
    );

    // Apply group context if inside a group
    if (_currentGroup != null) {
      route.groupPrefix = _currentGroup!.prefix;
      if (_currentGroup!.middleware.isNotEmpty) {
        route.middleware(_currentGroup!.middleware);
      }
    }

    MagicRouter.instance.addRoute(route);
    return route;
  }

  /// DEPRECATED: Use [page] instead.
  /// Kept for basic compatibility during refactor.
  @Deprecated('Use MagicRoute.page() instead')
  static RouteDefinition get(String path, Function handler) =>
      page(path, handler);

  /// Define a group of routes with shared options.
  ///
  /// Routes inside the callback inherit the group's prefix and middleware.
  ///
  /// ```dart
  /// Route.group(
  ///   prefix: '/api/v1',
  ///   middleware: [ApiAuthMiddleware()],
  ///   routes: () {
  ///     Route.get('/users', ApiUsersController.index);
  ///     Route.get('/posts', ApiPostsController.index);
  ///   },
  /// );
  /// ```
  ///
  /// Groups can be nested:
  ///
  /// ```dart
  /// Route.group(prefix: '/admin', routes: () {
  ///   Route.group(prefix: '/users', routes: () {
  ///     Route.get('/', AdminUsersController.index);     // /admin/users
  ///     Route.get('/:id', AdminUsersController.show);   // /admin/users/:id
  ///   });
  /// });
  /// ```
  static void group({
    String? prefix,
    List<dynamic> middleware = const [],
    String? as,
    Widget Function(Widget child)? layout,
    required void Function() routes,
  }) {
    // If layout is provided, start collecting routes
    if (layout != null) {
      MagicRouter.instance.startCollection();
    }

    final previousGroup = _currentGroup;

    // Build new group, merging with parent if nested
    _currentGroup = RouteGroup(
      prefix: _combinePrefixes(previousGroup?.prefix, prefix),
      middleware: [
        ...?previousGroup?.middleware,
        ...middleware,
      ],
      as: as,
    );

    // Execute callback to register routes
    routes();

    // Restore previous group context
    _currentGroup = previousGroup;

    // If layout was provided, register it with collected routes
    if (layout != null) {
      final collected = MagicRouter.instance.stopCollection();
      MagicRouter.instance.addLayout(LayoutDefinition(
        builder: layout,
        children: collected,
      ));
    }
  }

  /// Define a persistent layout with nested routes.
  ///
  /// Use this for tabs, navigation rails, or any UI that should persist
  /// while child routes change.
  ///
  /// ```dart
  /// Route.layout(
  ///   builder: (child) => DashboardLayout(child: child),
  ///   routes: [
  ///     Route.get('/dashboard', DashboardHome.new),
  ///     Route.get('/settings', SettingsPage.new),
  ///   ],
  /// );
  /// ```
  ///
  /// The layout widget should include a `MagicRouterOutlet` or use
  /// the `child` parameter to render nested content.
  static void layout({
    required Widget Function(Widget child) builder,
    required List<RouteDefinition> routes,
  }) {
    final layout = LayoutDefinition(
      builder: builder,
      children: routes,
    );

    MagicRouter.instance.addLayout(layout);
  }

  /// Combine parent and child prefixes.
  static String? _combinePrefixes(String? parent, String? child) {
    if (parent == null && child == null) return null;
    if (parent == null) return child;
    if (child == null) return parent;
    return '$parent$child';
  }

  // ---------------------------------------------------------------------------
  // Navigation (Context-Free!)
  // ---------------------------------------------------------------------------

  /// Navigate to a path.
  ///
  /// Can be called from anywhere - controllers, services, callbacks.
  /// No BuildContext required!
  ///
  /// ```dart
  /// Route.to('/dashboard');
  /// Route.to('/users/42');
  /// Route.to('/search', query: {'q': 'flutter'});
  /// ```
  static void to(String path, {Map<String, String>? query}) {
    MagicRouter.instance.to(path, queryParameters: query);
  }

  /// Navigate to a named route.
  ///
  /// ```dart
  /// Route.toNamed('users.show', params: {'id': '42'});
  /// ```
  static void toNamed(
    String name, {
    Map<String, String> params = const {},
    Map<String, String> query = const {},
  }) {
    MagicRouter.instance.toNamed(
      name,
      pathParameters: params,
      queryParameters: query,
    );
  }

  /// Push a route onto the navigation stack.
  ///
  /// Unlike `to()`, this preserves the back stack.
  ///
  /// ```dart
  /// Route.push('/details');
  /// ```
  static void push(String path) {
    MagicRouter.instance.push(path);
  }

  /// Go back to the previous route.
  ///
  /// ```dart
  /// Route.back();
  /// ```
  static void back() {
    MagicRouter.instance.back();
  }

  /// Replace the current route.
  ///
  /// ```dart
  /// Route.replace('/home');
  /// ```
  static void replace(String path) {
    MagicRouter.instance.replace(path);
  }

  // ---------------------------------------------------------------------------
  // Router Access
  // ---------------------------------------------------------------------------

  /// Get the router configuration for MaterialApp.
  ///
  /// ```dart
  /// MaterialApp.router(
  ///   routerConfig: Route.config,
  /// )
  /// ```
  static GoRouter get config => MagicRouter.instance.routerConfig;
}
