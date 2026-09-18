import 'middleware/magic_middleware.dart';

/// The HTTP Kernel - Middleware Registry.
///
/// Register global and route-specific middleware here.
/// Similar to Laravel's `app/Http/Kernel.php`.
///
/// ## Usage
///
/// ```dart
/// // In your app initialization
/// void registerMiddleware() {
///   // Global middleware (runs on every route)
///   Kernel.global([
///     () => LoggingMiddleware(),
///   ]);
///
///   // Route middleware (use with .middleware(['auth']))
///   Kernel.register('auth', () => EnsureAuthenticated());
///   Kernel.register('guest', () => RedirectIfAuthenticated());
/// }
/// ```
class Kernel {
  Kernel._();

  // ---------------------------------------------------------------------------
  // Global Middleware
  // ---------------------------------------------------------------------------

  /// Global middleware factories.
  /// These run on every route change.
  static final List<MagicMiddleware Function()> _globalMiddleware = [];

  /// Get global middleware instances.
  static List<MagicMiddleware> get globalMiddleware =>
      _globalMiddleware.map((f) => f()).toList();

  /// Register global middleware.
  ///
  /// ```dart
  /// Kernel.global([
  ///   () => LoggingMiddleware(),
  ///   () => MaintenanceModeMiddleware(),
  /// ]);
  /// ```
  static void global(List<MagicMiddleware Function()> factories) {
    _globalMiddleware.addAll(factories);
  }

  /// Add a single global middleware.
  static void addGlobal(MagicMiddleware Function() factory) {
    _globalMiddleware.add(factory);
  }

  // ---------------------------------------------------------------------------
  // Route Middleware
  // ---------------------------------------------------------------------------

  /// Route middleware aliases.
  /// Key is the alias name, value is the factory function.
  static final Map<String, MagicMiddleware Function()> _routeMiddleware = {};

  /// Get route middleware map.
  static Map<String, MagicMiddleware Function()> get routeMiddleware =>
      Map.unmodifiable(_routeMiddleware);

  /// Register a route middleware alias.
  ///
  /// ```dart
  /// Kernel.register('auth', () => EnsureAuthenticated());
  /// Kernel.register('guest', () => RedirectIfAuthenticated());
  /// Kernel.register('admin', () => EnsureAdmin());
  /// ```
  static void register(String name, MagicMiddleware Function() factory) {
    _routeMiddleware[name] = factory;
  }

  /// Register multiple route middleware aliases.
  ///
  /// ```dart
  /// Kernel.registerAll({
  ///   'auth': () => EnsureAuthenticated(),
  ///   'guest': () => RedirectIfAuthenticated(),
  /// });
  /// ```
  static void registerAll(Map<String, MagicMiddleware Function()> middleware) {
    _routeMiddleware.addAll(middleware);
  }

  // ---------------------------------------------------------------------------
  // Middleware Resolution
  // ---------------------------------------------------------------------------

  /// Resolve middleware by name or type.
  ///
  /// Accepts:
  /// - String: Alias name from routeMiddleware
  /// - MagicMiddleware Function(): Factory function
  /// - MagicMiddleware: Direct instance
  static MagicMiddleware? resolve(dynamic middleware) {
    if (middleware is String) {
      final factory = _routeMiddleware[middleware];
      return factory?.call();
    }
    if (middleware is MagicMiddleware Function()) {
      return middleware();
    }
    if (middleware is MagicMiddleware) {
      return middleware;
    }
    return null;
  }

  /// The entries of [middlewares] that [resolveAll] would throw on.
  ///
  /// Checks WITHOUT constructing anything: a registered factory is not called,
  /// so validating a whole route table costs nothing and fires no factory's
  /// side effects. That is what lets [MagicRouter] check every route once at
  /// bootstrap rather than discovering the problem at navigation, where
  /// GoRouter's `onException` swallows a redirect throw.
  static List<Object?> unresolvable(List<dynamic> middlewares) {
    return middlewares.where((m) {
      if (m is MagicMiddleware || m is MagicMiddleware Function()) return false;

      return !(m is String && _routeMiddleware.containsKey(m));
    }).toList();
  }

  /// The message [resolveAll] and [MagicRouter] both report for [entry].
  static String unresolvableMessage(Object? entry) {
    return entry is String
        ? 'Route middleware alias "$entry" is not registered. '
              'Register it with Kernel.register(\'$entry\', () => ...) '
              'from a service provider.'
        : 'Route middleware $entry could not be resolved. Pass an alias '
              'String registered with Kernel.register, a '
              'MagicMiddleware Function() factory, or a MagicMiddleware '
              'instance.';
  }

  /// Resolve a list of middleware, throwing on any entry that cannot resolve.
  ///
  /// The throw is the point. This used to drop an unresolvable entry with
  /// `whereType`, so a route declaring `middleware: ['auth']` against a Kernel
  /// that never received an `auth` alias rendered with NO gate on it and
  /// reported nothing. A missing gate lets everybody through, which is the one
  /// failure mode that must not be silent, and the usual cause is ordinary: a
  /// typo, or an app that registers its aliases after the router is built.
  ///
  /// Throws [StateError] naming the offending entry. [resolve] still answers
  /// null for a caller that wants to test one entry without committing to it.
  ///
  /// This runs at NAVIGATION time, from [MagicRouter]'s redirect callback and
  /// its middleware guard. It is the second line of defence rather than the
  /// first: a throw from inside GoRouter's `redirect` is routed to
  /// `onException` and never reaches the app, so [MagicRouter] validates every
  /// registered route's middleware through [unresolvable] when it builds,
  /// where the throw lands in `Magic.init` and is loud.
  static List<MagicMiddleware> resolveAll(List<dynamic> middlewares) {
    return middlewares.map((m) {
      final resolved = resolve(m);
      if (resolved != null) return resolved;

      throw StateError(unresolvableMessage(m));
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Middleware Execution
  // ---------------------------------------------------------------------------

  /// Execute middleware chain sequentially.
  ///
  /// Returns true if all middleware called next(), false otherwise.
  static Future<bool> execute(List<MagicMiddleware> middlewares) async {
    bool allowed = true;
    int index = 0;

    Future<void> runNext() async {
      if (index < middlewares.length) {
        final current = middlewares[index];
        index++;

        bool nextCalled = false;
        await current.handle(() {
          nextCalled = true;
        });

        if (nextCalled) {
          await runNext();
        } else {
          allowed = false;
        }
      }
    }

    await runNext();
    return allowed;
  }

  // ---------------------------------------------------------------------------
  // Reset (for testing)
  // ---------------------------------------------------------------------------

  /// Clear all registered middleware.
  static void flush() {
    _globalMiddleware.clear();
    _routeMiddleware.clear();
  }
}
