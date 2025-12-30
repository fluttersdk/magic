import 'package:fluttersdk_magic/fluttersdk_magic.dart';

import 'middleware/ensure_authenticated.dart';
import 'middleware/redirect_if_authenticated.dart';

/// The HTTP Kernel.
///
/// Register all middleware here, similar to Laravel's app/Http/Kernel.php.
///
/// ## Usage
///
/// ```dart
/// // In main.dart onInit
/// registerKernel();
/// ```
void registerKernel() {
  // ---------------------------------------------------------------------------
  // Global Middleware
  // ---------------------------------------------------------------------------
  // These run on EVERY route.
  // Kernel.global([
  //   () => LoggingMiddleware(),
  // ]);

  // ---------------------------------------------------------------------------
  // Route Middleware
  // ---------------------------------------------------------------------------
  // These are aliases you can use in routes with .middleware(['alias']).
  Kernel.registerAll({
    'auth': () => EnsureAuthenticated(),
    'guest': () => RedirectIfAuthenticated(),
  });
}
