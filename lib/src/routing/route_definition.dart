import 'package:flutter/widgets.dart';

/// Transition types for route animations.
enum RouteTransition {
  /// Standard platform-specific transition (default).
  none,

  /// Fade in/out animation.
  fade,

  /// Slide in from right.
  slideRight,

  /// Slide in from bottom.
  slideUp,

  /// Scale and fade animation.
  scale,
}

/// A fluent route definition builder.
///
/// This class represents a single route and supports method chaining
/// for a clean, expressive API similar to Laravel's routing.
///
/// ## Basic Usage
///
/// ```dart
/// MagicRoute.get('/users', () => UsersPage());
/// MagicRoute.get('/users/:id', (id) => UserDetailPage(id: id));
/// ```
///
/// ## Fluent Chaining
///
/// ```dart
/// MagicRoute.get('/dashboard', () => controller.index())
///     .name('dashboard')
///     .middleware(['auth'])
///     .transition(RouteTransition.fade);
/// ```
class RouteDefinition {
  /// The URL path pattern (e.g., '/users/:id').
  final String path;

  /// The handler function that returns a Widget.
  final Function handler;

  /// HTTP method (GET, POST, etc.) - primarily for documentation.
  final String method;

  /// Optional route name for named navigation.
  String? _name;

  /// Middleware applied to this route.
  /// Can contain String aliases or direct MagicMiddleware factories.
  List<dynamic> _middlewares = [];

  /// Page transition animation type.
  RouteTransition _transition = RouteTransition.none;

  /// Parent group prefix (set by Route.group).
  String? _groupPrefix;

  /// Create a new route definition.
  RouteDefinition({
    required this.path,
    required this.handler,
    this.method = 'GET',
  });

  // ---------------------------------------------------------------------------
  // Fluent API Methods
  // ---------------------------------------------------------------------------

  /// Assign a name to this route for named navigation.
  ///
  /// ```dart
  /// MagicRoute.get('/users/:id', (id) => UserPage(id))
  ///     .name('users.show');
  /// ```
  RouteDefinition name(String routeName) {
    _name = routeName;
    return this;
  }

  /// Apply middleware to this route.
  ///
  /// Accepts:
  /// - String aliases registered in Kernel (e.g., 'auth', 'guest')
  /// - Direct middleware factories
  ///
  /// ```dart
  /// // Using alias
  /// MagicRoute.get('/admin', () => AdminPage())
  ///     .middleware(['auth', 'admin']);
  ///
  /// // Using factory
  /// MagicRoute.get('/log', () => LogPage())
  ///     .middleware([() => LoggingMiddleware()]);
  /// ```
  RouteDefinition middleware(List<dynamic> middlewares) {
    _middlewares = middlewares;
    return this;
  }

  /// Set the page transition animation.
  ///
  /// ```dart
  /// MagicRoute.get('/modal', () => ModalPage())
  ///     .transition(RouteTransition.slideUp);
  /// ```
  RouteDefinition transition(RouteTransition type) {
    _transition = type;
    return this;
  }

  // ---------------------------------------------------------------------------
  // Internal Getters
  // ---------------------------------------------------------------------------

  /// Get the route name, if defined.
  String? get routeName => _name;

  /// Get the list of middleware (strings or factories).
  List<dynamic> get middlewares => _middlewares;

  /// Get the transition type.
  RouteTransition get transitionType => _transition;

  /// Get the full path including any group prefix.
  String get fullPath {
    if (_groupPrefix != null && _groupPrefix!.isNotEmpty) {
      return '$_groupPrefix$path';
    }
    return path;
  }

  /// Set the group prefix (internal use).
  set groupPrefix(String? prefix) => _groupPrefix = prefix;

  /// Build the widget from the handler, passing parameters if needed.
  Widget buildWidget(Map<String, String> pathParameters) {
    if (handler is Widget Function()) {
      return (handler as Widget Function())();
    }

    final params = pathParameters.values.toList();

    switch (params.length) {
      case 1:
        return (handler as Widget Function(String))(params[0]);
      case 2:
        return (handler as Widget Function(String, String))(
          params[0],
          params[1],
        );
      case 3:
        return (handler as Widget Function(String, String, String))(
          params[0],
          params[1],
          params[2],
        );
      default:
        return (handler as Widget Function())();
    }
  }
}

/// A route group definition for shared options.
class RouteGroup {
  /// URL prefix for all routes in this group.
  final String? prefix;

  /// Middleware applied to all routes in this group.
  final List<dynamic> middleware;

  /// Named route prefix (e.g., 'admin.' makes routes 'admin.dashboard').
  final String? as;

  RouteGroup({
    this.prefix,
    this.middleware = const [],
    this.as,
  });
}

/// A layout route definition for persistent shells.
class LayoutDefinition {
  /// Optional layout ID for merging multiple groups.
  final String? id;

  /// The layout widget builder.
  final Widget Function(Widget child) builder;

  /// Child routes rendered inside this layout.
  final List<RouteDefinition> children;

  LayoutDefinition({
    this.id,
    required this.builder,
    required this.children,
  });
}
