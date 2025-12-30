/// The Base Middleware for Magic.
///
/// Middleware intercepts navigation and can allow, block, or redirect.
/// This mimics Laravel's `$next($request)` pattern.
///
/// ## Usage
///
/// ```dart
/// class EnsureAuthenticated extends MagicMiddleware {
///   @override
///   Future<void> handle(void Function() next) async {
///     if (AuthService.isLoggedIn) {
///       next(); // Allow navigation
///     } else {
///       MagicRoute.to('/login'); // Redirect
///     }
///   }
/// }
/// ```
///
/// Register in Kernel:
/// ```dart
/// Kernel.register('auth', () => EnsureAuthenticated());
/// ```
///
/// Use in routes:
/// ```dart
/// MagicRoute.get('/dashboard', () => controller.index())
///     .middleware(['auth']);
/// ```
abstract class MagicMiddleware {
  /// Handle the navigation request.
  ///
  /// Call [next] to allow navigation to proceed.
  /// If [next] is NOT called, navigation stops (redirect can happen inside).
  ///
  /// ```dart
  /// @override
  /// Future<void> handle(void Function() next) async {
  ///   if (canProceed) {
  ///     next();
  ///   } else {
  ///     MagicRoute.to('/login');
  ///   }
  /// }
  /// ```
  Future<void> handle(void Function() next);
}

/// A simple middleware that always allows navigation.
///
/// Useful as a base or for testing.
class AllowAllMiddleware extends MagicMiddleware {
  @override
  Future<void> handle(void Function() next) async {
    next();
  }
}
