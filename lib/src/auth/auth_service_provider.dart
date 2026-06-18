import '../support/service_provider.dart';
import '../auth/auth_manager.dart';
import '../auth/auth_interceptor.dart';
import '../network/contracts/network_driver.dart';
import '../facades/auth.dart';
import '../facades/log.dart';
import '../facades/config.dart';
import '../foundation/magic.dart';

/// The Auth Service Provider.
///
/// Registers the authentication system and handles auto-login on boot.
class AuthServiceProvider extends ServiceProvider {
  AuthServiceProvider(super.app);

  @override
  void register() {
    // Register the AuthManager singleton
    app.singleton('auth', () => AuthManager());
  }

  @override
  Future<void> boot() async {
    // Register auth interceptor for HTTP requests
    _registerAuthInterceptor();

    // Check if auto-refresh is enabled (default: true)
    final authConfig = Config.get<Map<String, dynamic>>('auth', {});
    final autoRefresh = authConfig?['auto_refresh'] ?? true;

    Log.debug(
      'Auth: boot (autoRefresh=$autoRefresh, '
      'hasUserFactory=${Auth.manager.hasUserFactory})',
    );

    if (!autoRefresh) return;

    // A userFactory is required to rebuild the user from a stored session.
    // Only warn when there is actually a session to restore: a fresh app (or
    // a user who never logged in) has no stored token, so restore is a no-op
    // and a warning would just be boot noise on every launch.
    if (!Auth.manager.hasUserFactory) {
      // Deciding warning verbosity must never crash boot: if Auth is not fully
      // configured (Vault unavailable, guard config missing), Auth.hasToken()
      // can throw. Treat any failure as "no stored session" and stay quiet.
      var hasStoredSession = false;
      try {
        hasStoredSession = await Auth.hasToken();
      } catch (_) {
        hasStoredSession = false;
      }
      if (hasStoredSession) {
        Log.warning(
          'Auth: a stored session exists but cannot be restored (no '
          'userFactory registered). Register it in AppServiceProvider.boot() '
          'via Auth.manager.setUserFactory(...), and list AppServiceProvider '
          'before AuthServiceProvider in app.providers.',
        );
      } else {
        Log.debug(
          'Auth: no userFactory and no stored session; skipping restore.',
        );
      }
      return;
    }

    try {
      // Automatically restore login state from Vault
      await Auth.restore();

      if (Auth.check()) {
        Log.info('User session restored');
      } else {
        Log.debug('Auth: restore completed but no user authenticated');
      }
    } catch (e, stackTrace) {
      Log.warning('Auth restore failed: $e\n$stackTrace');
    }
  }

  /// Register the auth interceptor with the network driver.
  void _registerAuthInterceptor() {
    try {
      final driver = Magic.make<NetworkDriver>('network');
      driver.addInterceptor(AuthInterceptor());
    } catch (e) {
      Log.warning('Could not register auth interceptor: $e');
    }
  }
}
