import 'package:fluttersdk_magic/fluttersdk_magic.dart';

/// Ensure the user is authenticated.
///
/// Redirects to /login if not authenticated.
///
/// ## Usage
///
/// ```dart
/// // In Kernel
/// Kernel.register('auth', () => EnsureAuthenticated());
///
/// // In Routes
/// MagicRoute.get('/dashboard', () => controller.index())
///     .middleware(['auth']);
/// ```
class EnsureAuthenticated extends MagicMiddleware {
  @override
  Future<void> handle(void Function() next) async {
    // Check if user is authenticated
    // In a real app, you'd check AuthService or similar
    final isLoggedIn = _checkAuth();

    if (isLoggedIn) {
      next(); // Allow navigation
    } else {
      // Redirect to login
      MagicRoute.to('/auth/login');
    }
  }

  // Demo static state
  static bool mockIsLoggedIn = false;

  bool _checkAuth() {
    return mockIsLoggedIn;
  }
}
