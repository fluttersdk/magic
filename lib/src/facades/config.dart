import '../foundation/application.dart';
import '../foundation/config_repository.dart';

/// The Config Facade.
///
/// Access and modify application configuration with clean, expressive syntax.
/// Supports dot notation for nested values.
///
/// ## Getting Values
///
/// ```dart
/// final appName = Config.get('app.name');
/// final debug = Config.get('app.debug', false);
/// final apiKey = Config.get<String>('services.stripe.key');
/// ```
///
/// ## Setting Values
///
/// ```dart
/// Config.set('cache.ttl', 3600);
/// Config.set('services.mail.driver', 'smtp');
/// ```
///
/// ## Merging Configuration
///
/// ```dart
/// Config.merge({
///   'database': {
///     'host': 'production.db.example.com',
///   }
/// });
/// ```
class Config {
  // Prevent instantiation
  Config._();

  /// The singleton repository instance.
  static ConfigRepository get _repository => MagicApp.config;

  // ---------------------------------------------------------------------------
  // Get
  // ---------------------------------------------------------------------------

  /// Get a configuration value using dot notation.
  ///
  /// ```dart
  /// Config.get('app.name'); // 'My App'
  /// Config.get('database.port', 5432); // Default if not set
  /// ```
  static T? get<T>(String key, [T? defaultValue]) {
    return _repository.get<T>(key, defaultValue);
  }

  /// Get a configuration value, throwing if not found.
  ///
  /// ```dart
  /// final secret = Config.getOrFail<String>('app.secret');
  /// ```
  static T getOrFail<T>(String key) {
    return _repository.getOrFail<T>(key);
  }

  // ---------------------------------------------------------------------------
  // Set
  // ---------------------------------------------------------------------------

  /// Set a configuration value using dot notation.
  ///
  /// ```dart
  /// Config.set('app.debug', true);
  /// ```
  static void set(String key, dynamic value) {
    _repository.set(key, value);
  }

  // ---------------------------------------------------------------------------
  // Has
  // ---------------------------------------------------------------------------

  /// Check if a configuration key exists.
  ///
  /// ```dart
  /// if (Config.has('services.stripe')) {
  ///   initStripe();
  /// }
  /// ```
  static bool has(String key) {
    return _repository.has(key);
  }

  // ---------------------------------------------------------------------------
  // All
  // ---------------------------------------------------------------------------

  /// Get all configuration as a Map.
  static Map<String, dynamic> all() {
    return _repository.all();
  }

  // ---------------------------------------------------------------------------
  // Merge
  // ---------------------------------------------------------------------------

  /// Deep merge new configuration into existing.
  ///
  /// ```dart
  /// Config.merge(appConfig);
  /// Config.merge(databaseConfig);
  /// ```
  static void merge(Map<String, dynamic> config) {
    _repository.merge(config);
  }

  // ---------------------------------------------------------------------------
  // Array Helpers
  // ---------------------------------------------------------------------------

  /// Prepend a value to an array configuration.
  static void prepend(String key, dynamic value) {
    _repository.prepend(key, value);
  }

  /// Push a value to an array configuration.
  static void push(String key, dynamic value) {
    _repository.push(key, value);
  }

  // ---------------------------------------------------------------------------
  // Remove
  // ---------------------------------------------------------------------------

  /// Remove a configuration key.
  static void forget(String key) {
    _repository.forget(key);
  }

  /// Clear all configuration.
  static void flush() {
    _repository.flush();
  }

  // ---------------------------------------------------------------------------
  // Repository Access
  // ---------------------------------------------------------------------------

  /// Get the underlying repository (for advanced use).
  static ConfigRepository get repository => _repository;
}
