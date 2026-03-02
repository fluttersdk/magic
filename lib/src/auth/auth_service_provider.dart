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

    // Guard: userFactory must be registered before restore.
    // AppServiceProvider.boot() calls Auth.manager.setUserFactory()
    // and MUST be listed before AuthServiceProvider in app.providers.
    if (!Auth.manager.hasUserFactory) {
      Log.warning(
        'Auth: Cannot restore session — userFactory not registered. '
        'Ensure AppServiceProvider is listed BEFORE AuthServiceProvider '
        'in your app.providers config.',
      );
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
