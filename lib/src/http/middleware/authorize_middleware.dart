import 'package:fluttersdk_magic/src/http/middleware/magic_middleware.dart';
import 'package:fluttersdk_magic/src/facades/gate.dart';
import 'package:fluttersdk_magic/src/facades/route.dart';

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
/// ## With Route Arguments
///
/// When you need to check authorization against a model, pass the model
/// from the route parameters:
///
/// ```dart
/// class EditPostMiddleware extends MagicMiddleware {
///   @override
///   Future<void> handle(void Function() next) async {
///     final postId = MagicRoute.param('id');
///     final post = await Post.find(postId);
///
///     if (Gate.allows('edit-post', post)) {
///       next();
///     } else {
///       MagicRoute.to('/unauthorized');
///     }
///   }
/// }
/// ```
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
  Future<void> handle(void Function() next) async {
    if (Gate.allows(ability, arguments)) {
      next();
    } else {
      MagicRoute.to(unauthorizedRoute);
    }
  }
}
