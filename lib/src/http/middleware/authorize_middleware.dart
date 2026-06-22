import 'package:magic/src/http/middleware/magic_middleware.dart';
import 'package:magic/src/facades/gate.dart';

/// Authorization Middleware.
///
/// Checks if the authenticated user has the specified ability before
/// allowing navigation. This is Laravel's `can` middleware equivalent.
///
/// ## Usage
///
/// Register in Kernel with ability name:
/// ```dart
/// Kernel.register('can:edit-post', () => AuthorizeMiddleware('edit-post'));
/// Kernel.register('can:delete-post', () => AuthorizeMiddleware('delete-post'));
/// ```
///
/// Use in routes:
/// ```dart
/// MagicRoute.page('/posts/:id/edit', () => EditPost())
///     .middleware(['auth', 'can:edit-post']);
/// ```
///
/// Gating resolves in the router's `redirect` callback (pre-build) via
/// [redirectTarget], so a denied route never builds and the unauthorized
/// destination mounts exactly once.
class AuthorizeMiddleware extends MagicMiddleware {
  /// The ability to check.
  final String ability;

  /// Optional arguments to pass to the ability check.
  final dynamic arguments;

  /// The route to redirect to when unauthorized.
  final String unauthorizedRoute;

  /// Create an authorization middleware.
  ///
  /// - [ability]: The Gate ability to check (e.g., 'edit-post').
  /// - [arguments]: Optional model or data passed to the ability check.
  /// - [unauthorizedRoute]: Where to redirect if denied (default: '/unauthorized').
  AuthorizeMiddleware(
    this.ability, {
    this.arguments,
    this.unauthorizedRoute = '/unauthorized',
  });

  @override
  String? redirectTarget(String location) {
    if (!Gate.allows(ability, arguments) && location != unauthorizedRoute) {
      return unauthorizedRoute;
    }
    return null;
  }
}
