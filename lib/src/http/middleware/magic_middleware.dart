/// The Base Middleware for Magic.
///
/// Middleware intercepts navigation and can allow, block, or redirect.
/// This mimics Laravel's `$next($request)` pattern.
///
/// ## Redirect-style guards
///
/// Override [redirectTarget] so the redirect resolves BEFORE the route builds.
/// The destination view then mounts exactly once.
///
/// ```dart
/// class EnsureAuthenticated extends MagicMiddleware {
///   @override
///   String? redirectTarget(String location) {
///     if (!Auth.check() && location != '/login') return '/login';
///     return null;
///   }
/// }
/// ```
///
/// ## Blocking / async guards
///
/// Override [handle] for async, non-redirecting concerns. Call `next()` to
/// allow navigation; skip it to block.
///
/// ```dart
/// class LogNavigation extends MagicMiddleware {
///   @override
///   Future<void> handle(void Function() next) async {
///     Log.info('navigating');
///     next();
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
  /// Resolve a redirect target for [location] BEFORE the route builds.
  ///
  /// This is the redirect-guard hook. Return a path to redirect to, or `null`
  /// to allow the navigation. It is evaluated synchronously inside the router's
  /// `redirect` callback, so a redirect-style guard resolves before any page
  /// is built and the destination view mounts exactly once. Prefer this over
  /// an imperative `MagicRoute.to()` inside [handle]: redirecting from [handle]
  /// runs post-mount and remounts the destination.
  ///
  /// Always return `null` when [location] already equals the target, otherwise
  /// the redirect loops.
  ///
  /// ```dart
  /// class EnsureAuthenticated extends MagicMiddleware {
  ///   @override
  ///   String? redirectTarget(String location) {
  ///     if (!Auth.check() && location != '/login') return '/login';
  ///     return null;
  ///   }
  /// }
  /// ```
  ///
  /// The default returns `null` (no redirect), so non-redirecting middleware
  /// only need to implement [handle].
  String? redirectTarget(String location) => null;

  /// Handle the navigation request.
  ///
  /// Call [next] to allow navigation to proceed.
  /// If [next] is NOT called, navigation stops.
  ///
  /// Use this for async, non-redirecting concerns (logging, feature gating
  /// that shows a blocked state). For redirect-style guards, override
  /// [redirectTarget] instead so the redirect resolves pre-build.
  ///
  /// The default allows navigation, so a redirect-only guard can override
  /// just [redirectTarget] and leave this alone.
  ///
  /// ```dart
  /// @override
  /// Future<void> handle(void Function() next) async {
  ///   if (canProceed) {
  ///     next();
  ///   }
  /// }
  /// ```
  Future<void> handle(void Function() next) async => next();
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
