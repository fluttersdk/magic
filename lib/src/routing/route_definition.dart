import 'package:flutter/widgets.dart';

/// Transition types for route animations.
enum RouteTransition {
  /// No animation; the page switches instantly. The default.
  ///
  /// This used to be documented as the platform transition and never was:
  /// it builds a `NoTransitionPage`, which is the right answer on web and the
  /// reason the default is not being changed. Use [platform] for the
  /// per-platform animation and the gestures that come with it.
  none,

  /// The platform's own page transition, and its back gestures with it.
  ///
  /// Routes to Flutter's `PageTransitionsTheme`, so iOS and macOS get the
  /// Cupertino slide plus the left-edge swipe back, Android gets predictive
  /// back, and Windows and Linux get the zoom. The other values here build a
  /// bare `PageRoute` with a custom transition, which carries no gesture at
  /// all: Flutter installs the back-swipe detector inside the Cupertino
  /// transition, not beside it.
  ///
  /// A gesture still needs something to pop, so this only does anything on a
  /// route reached by a push. See [RouteDefinition.stacked].
  platform,

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
  ///
  /// Null means "follow the router's default". Distinct from an explicit
  /// [RouteTransition.none], which is a route asking for no animation and has
  /// to beat an app-wide default rather than be indistinguishable from
  /// silence.
  RouteTransition? _transition;

  /// Page title for browser tab / app switcher.
  String? _title;

  /// Parent group prefix (set by Route.group).
  String? _groupPrefix;

  /// Whether navigating here pushes a page rather than replacing the stack.
  ///
  /// Null means "follow the router's default", which is what almost every
  /// route does; [stacked] sets it per route.
  bool? _stacked;

  /// Whether a back gesture may pop this route.
  ///
  /// Null means "whatever the transition implies", which is on for
  /// [RouteTransition.platform] and off for the rest, since no other value
  /// installs a gesture in the first place.
  bool? _swipeBack;

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

  /// Push this route onto the stack instead of replacing it.
  ///
  /// `to()` calls `go()`, which replaces the Navigator's whole page list, so
  /// an app that only ever calls `to()` never has more than one page and
  /// nothing can pop. That is not only a missing swipe: Flutter reports
  /// `canHandlePop` to the platform, so on Android the system back button
  /// leaves the app rather than going back.
  ///
  /// Mark the routes a reader drills INTO, and leave the ones they switch
  /// BETWEEN alone: a tab or a nav destination that pushes grows the stack
  /// every time it is tapped.
  ///
  /// ```dart
  /// MagicRoute.page('/monitors', () => MonitorsPage());
  /// MagicRoute.page('/monitors/:id', (id) => MonitorPage(id))
  ///     .stacked()
  ///     .transition(RouteTransition.platform);
  /// ```
  RouteDefinition stacked([bool value = true]) {
    _stacked = value;
    return this;
  }

  /// Allow or refuse the platform back gesture on this route.
  ///
  /// Only the gesture. Use `PopScope` when the answer is "this route should
  /// not be left yet at all", because that also covers the Android back
  /// button and any back affordance in the app's own chrome; Flutter's
  /// `popGestureEnabled` already honours it.
  ///
  /// ```dart
  /// MagicRoute.page('/checkout/payment', () => PaymentPage())
  ///     .stacked()
  ///     .transition(RouteTransition.platform)
  ///     .swipeBack(false);
  /// ```
  RouteDefinition swipeBack(bool value) {
    _swipeBack = value;
    return this;
  }

  /// Set the page title for this route.
  ///
  /// ```dart
  /// MagicRoute.page('/dashboard', () => DashboardPage())
  ///     .title('Dashboard');
  /// ```
  RouteDefinition title(String pageTitle) {
    _title = pageTitle;
    return this;
  }

  // ---------------------------------------------------------------------------
  // Internal Getters
  // ---------------------------------------------------------------------------

  /// Get the route name, if defined.
  String? get routeName => _name;

  /// Get the list of middleware (strings or factories).
  List<dynamic> get middlewares => _middlewares;

  /// The transition this route declared, or [RouteTransition.none].
  ///
  /// Deliberately ignores [MagicRouter.defaultTransition], because a caller
  /// asking a definition what IT says has no business being handed the
  /// router's answer. Use [declaredTransition] where the difference between
  /// "declared none" and "declared nothing" matters; the router resolves the
  /// default from that one.
  RouteTransition get transitionType => _transition ?? RouteTransition.none;

  /// The transition this route named, or null to take the router's default.
  RouteTransition? get declaredTransition => _transition;

  /// Whether [stacked] was set here, or null to take the router's default.
  bool? get isStacked => _stacked;

  /// Whether [swipeBack] was set here, or null to take the transition's.
  bool? get isSwipeBackAllowed => _swipeBack;

  /// Get the page title, if defined.
  String? get routeTitle => _title;

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

  RouteGroup({this.prefix, this.middleware = const [], this.as});
}

/// A layout route definition for persistent shells.
class LayoutDefinition {
  /// Optional layout ID for merging multiple groups.
  final String? id;

  /// The layout widget builder.
  final Widget Function(Widget child) builder;

  /// Child routes rendered inside this layout.
  final List<RouteDefinition> children;

  LayoutDefinition({this.id, required this.builder, required this.children});
}
