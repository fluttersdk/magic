import '../facades/config.dart';
import 'cache_store.dart';

/// The Cache Manager.
///
/// This service acts as a manager for various cache drivers.
/// It resolves the active driver based on configuration and proxies calls to it.
class CacheManager implements CacheStore {
  /// Get a cache driver instance.
  ///
  /// [driver] The name of the driver to retrieve. If null, uses default config.
  CacheStore driver([String? driver]) {
    // If specific driver requested, resolve it
    // For now we primarily support the default one from config
    return _resolve(driver);
  }

  /// Get the default cache driver instance from config.
  CacheStore _getDefaultDriver() {
    final driver = Config.get('cache.driver');

    if (driver is CacheStore) {
      return driver;
    }

    throw Exception(
      'Cache driver must be an instance of CacheStore. '
      'Check your config/defaults.dart.',
    );
  }

  /// Resolve a driver instance (Legacy support or multi-driver map).
  ///
  /// Since we are now using instances in config, we just return the default reference.
  /// If we wanted named drivers in config, we'd look them up here.
  CacheStore _resolve(String? driverName) {
    if (driverName == null) {
      return _getDefaultDriver();
    }
    // Expand here if we add named driver support in config
    return _getDefaultDriver();
  }

  // ---------------------------------------------------------------------------
  // Proxy Methods (Forward to Default Driver)
  // ---------------------------------------------------------------------------

  @override
  Future<void> init() {
    return driver().init();
  }

  @override
  dynamic get(String key, {dynamic defaultValue}) {
    return driver().get(key, defaultValue: defaultValue);
  }

  @override
  Future<void> put(String key, dynamic value, {Duration? ttl}) {
    return driver().put(key, value, ttl: ttl);
  }

  @override
  bool has(String key) {
    return driver().has(key);
  }

  @override
  Future<void> forget(String key) {
    return driver().forget(key);
  }

  @override
  Future<void> flush() {
    return driver().flush();
  }
}
