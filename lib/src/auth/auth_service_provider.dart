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

    if (autoRefresh) {
      try {
        // Automatically restore login state from Vault
        await Auth.restore();

        if (Auth.check()) {
          Log.info('User session restored');
        }
      } catch (e) {
        Log.warning('Auth restore failed: $e');
      }
    }
  }

  /// Register the auth interceptor with the network driver.
  void _registerAuthInterceptor() {
    try {
      final driver = Magic.make<NetworkDriver>('network');
      driver.addInterceptor(AuthInterceptor());
      Log.debug('Auth interceptor registered');
    } catch (e) {
      Log.warning('Could not register auth interceptor: $e');
    }
  }
}
