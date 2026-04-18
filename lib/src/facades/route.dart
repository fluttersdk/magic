import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../routing/magic_router.dart';
import '../routing/resource_controller.dart';
import '../routing/route_definition.dart';
import '../routing/title_manager.dart';

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
    final route = RouteDefinition(path: path, handler: handler, method: 'PAGE');

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
    String? layoutId,
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
      middleware: [...?previousGroup?.middleware, ...middleware],
      as: as,
    );

    // Execute callback to register routes
    routes();

    // Restore previous group context
    _currentGroup = previousGroup;

    // If layout was provided, register it with collected routes
    if (layout != null) {
      final collected = MagicRouter.instance.stopCollection();
      MagicRouter.instance.addLayout(
        LayoutDefinition(id: layoutId, builder: layout, children: collected),
      );
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
    String? id,
    required Widget Function(Widget child) builder,
    required List<RouteDefinition> routes,
  }) {
    final layout = LayoutDefinition(id: id, builder: builder, children: routes);

    MagicRouter.instance.addLayout(layout);
  }

  /// Register Laravel-style resource routes for a controller.
  ///
  /// Wires up to four canonical routes, scoped under `/{name}`:
  ///
  /// | Path                 | Method        |
  /// | -------------------- | ------------- |
  /// | `/{name}`            | `index()`     |
  /// | `/{name}/create`     | `create()`    |
  /// | `/{name}/:id`        | `show(id)`    |
  /// | `/{name}/:id/edit`   | `edit(id)`    |
  ///
  /// Only methods declared in the controller's [ResourceController.resourceMethods]
  /// set are registered. Use [only] or [except] to further filter the set.
  ///
  /// ```dart
  /// MagicRoute.resource('monitors', MonitorController.instance);
  /// MagicRoute.resource(
  ///   'status-pages',
  ///   StatusPagesController.instance,
  ///   only: ['index', 'show'],
  /// );
  /// MagicRoute.resource(
  ///   'metrics-library',
  ///   MetricsLibraryController.instance,
  ///   except: ['create', 'edit'],
  /// );
  /// ```
  ///
  /// Each route is auto-titled using the `{name}.{method}` translation key
  /// pattern (e.g. `monitors.index`, `monitors.show`). Override with
  /// `.title()` on the returned definitions if needed.
  ///
  /// Returns the list of registered [RouteDefinition]s in registration order.
  static List<RouteDefinition> resource(
    String name,
    ResourceController controller, {
    List<String>? only,
    List<String>? except,
  }) {
    const allMethods = ['index', 'create', 'show', 'edit'];

    final supported = controller.resourceMethods;
    final onlySet = only?.toSet();
    final exceptSet = except?.toSet() ?? const <String>{};

    final selected = allMethods.where((method) {
      if (!supported.contains(method)) return false;
      if (onlySet != null && !onlySet.contains(method)) return false;
      if (exceptSet.contains(method)) return false;
      return true;
    }).toList();

    final slug = name.startsWith('/') ? name.substring(1) : name;
    final registered = <RouteDefinition>[];

    for (final method in selected) {
      final RouteDefinition route;
      switch (method) {
        case 'index':
          route = page('/$slug', controller.index);
        case 'create':
          route = page('/$slug/create', controller.create);
        case 'show':
          route = page('/$slug/:id', (String id) => controller.show(id));
        case 'edit':
          route = page('/$slug/:id/edit', (String id) => controller.edit(id));
        default:
          continue;
      }
      route.title('$slug.$method').name('$slug.$method');
      registered.add(route);
    }

    return registered;
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
  /// Tries native pop first, then the internal history stack.
  /// When both are empty, navigates to [fallback] if provided.
  ///
  /// ```dart
  /// Route.back();
  /// Route.back(fallback: '/home');
  /// ```
  static void back({String? fallback}) {
    MagicRouter.instance.back(fallback: fallback);
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
  // Title Management
  // ---------------------------------------------------------------------------

  /// Set the page title imperatively from a controller or callback.
  ///
  /// Applies the configured suffix automatically.
  static void setTitle(String title) {
    TitleManager.instance.setOverride(title);
  }

  /// Get the current effective page title (without suffix).
  static String? get currentTitle => TitleManager.instance.currentTitle;

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
