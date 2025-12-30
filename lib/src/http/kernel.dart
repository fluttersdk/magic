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

  /// Resolve a list of middleware.
  static List<MagicMiddleware> resolveAll(List<dynamic> middlewares) {
    return middlewares
        .map((m) => resolve(m))
        .whereType<MagicMiddleware>()
        .toList();
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
