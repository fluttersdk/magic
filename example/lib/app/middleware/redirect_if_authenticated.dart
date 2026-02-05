import 'package:magic/magic.dart';

/// Redirect if already authenticated.
///
/// Used for login/register pages - redirects to home if already logged in.
///
/// ## Usage
///
/// ```dart
/// // In Kernel
/// Kernel.register('guest', () => RedirectIfAuthenticated());
///
/// // In Routes
/// MagicRoute.get('/login', () => LoginPage())
///     .middleware(['guest']);
/// ```
class RedirectIfAuthenticated extends MagicMiddleware {
  @override
  Future<void> handle(void Function() next) async {
    final isLoggedIn = _checkAuth();

    if (!isLoggedIn) {
      next(); // Allow navigation (user is guest)
    } else {
      // Already logged in, redirect to home
      MagicRoute.to('/');
    }
  }

  bool _checkAuth() {
    // Placeholder - in real app, check token/session
    return false; // Default to false for demo
  }
}
