import 'contracts/guard.dart';
import 'guards/bearer_token_guard.dart';
import 'guards/basic_auth_guard.dart';
import 'guards/api_key_guard.dart';
import 'authenticatable.dart';
import '../facades/config.dart';

/// The Auth Manager.
///
/// Manages authentication guards for the application.
/// Resolves guards based on configuration.
///
/// ## Built-in Drivers
///
/// - `bearer` / `sanctum` - BearerTokenGuard (default)
/// - `basic` - BasicAuthGuard
/// - `api_key` - ApiKeyGuard
///
/// ## Usage
///
/// ```dart
/// // Get the default guard
/// final guard = Auth.guard();
///
/// // Get a specific guard
/// final apiGuard = Auth.guard('api');
/// ```
///
/// ## Custom Guards
///
/// ```dart
/// Auth.manager.extend('firebase', (config) => FirebaseGuard());
/// ```
class AuthManager {
  /// Singleton instance.
  static final AuthManager _instance = AuthManager._internal();

  /// Factory constructor returning the singleton.
  factory AuthManager() => _instance;

  AuthManager._internal();

  /// Resolved guard instances.
  final Map<String, Guard> _guards = {};

  /// Custom guard driver factories.
  final Map<String, Guard Function(Map<String, dynamic>)> _customDrivers = {};

  /// User factory for restoring users from API responses.
  Authenticatable Function(Map<String, dynamic>)? _userFactory;

  /// Register the user factory for session restoration.
  ///
  /// ```dart
  /// Auth.manager.setUserFactory((data) => User.fromMap(data));
  /// ```
  void setUserFactory(Authenticatable Function(Map<String, dynamic>) factory) {
    _userFactory = factory;
  }

  /// Get a guard instance.
  ///
  /// If no name is provided, returns the default guard from config.
  Guard guard([String? name]) {
    name ??= _defaultGuard;

    if (_guards.containsKey(name)) {
      return _guards[name]!;
    }

    return _guards[name] = _resolveGuard(name);
  }

  /// Get the default guard name from config.
  String get _defaultGuard {
    final config = Config.get<Map<String, dynamic>>('auth', {});
    final defaults = config?['defaults'] as Map<String, dynamic>?;
    return defaults?['guard'] as String? ?? 'api';
  }

  /// Resolve a guard by name.
  Guard _resolveGuard(String name) {
    final config = _getGuardConfig(name);
    final driver = config['driver'] as String? ?? 'bearer';
    return _createGuard(driver, config);
  }

  /// Get guard configuration by name.
  Map<String, dynamic> _getGuardConfig(String name) {
    final config = Config.get<Map<String, dynamic>>('auth', {});
    final guards = config?['guards'] as Map<String, dynamic>?;
    return (guards?[name] as Map<String, dynamic>?) ?? {};
  }

  /// Create a guard instance.
  Guard _createGuard(String driver, Map<String, dynamic> config) {
    // Check for custom drivers first
    if (_customDrivers.containsKey(driver)) {
      return _customDrivers[driver]!(config);
    }

    // Get endpoints config
    final authConfig = Config.get<Map<String, dynamic>>('auth', {});
    final endpoints = authConfig?['endpoints'] as Map<String, dynamic>?;
    final tokenConfig = authConfig?['token'] as Map<String, dynamic>?;
    final tokenKey = tokenConfig?['key'] as String? ?? 'auth_token';

    // Built-in drivers
    switch (driver) {
      case 'bearer':
      case 'sanctum':
        return BearerTokenGuard(
          tokenKey: tokenKey,
          userEndpoint: endpoints?['user'] as String? ?? '/api/user',
          userFactory: _userFactory,
        );
      case 'basic':
        return BasicAuthGuard(tokenKey: tokenKey);
      case 'api_key':
        return ApiKeyGuard(tokenKey: tokenKey);
      default:
        throw ArgumentError('Unsupported guard driver: $driver');
    }
  }

  /// Register a custom guard driver.
  ///
  /// ```dart
  /// Auth.manager.extend('firebase', (config) => FirebaseGuard());
  /// ```
  void extend(
    String driver,
    Guard Function(Map<String, dynamic> config) factory,
  ) {
    _customDrivers[driver] = factory;
  }

  /// Reset all guards (useful for testing).
  void forgetGuards() {
    _guards.clear();
  }
}
