import 'dart:async';
import '../cache/cache_manager.dart';
import '../foundation/magic.dart';

/// Laravel-style Cache Facade.
///
/// Provides static access to the [CacheManager].
class Cache {
  /// Get the backing service.
  static CacheManager get _service => Magic.make<CacheManager>('cache');

  /// Store an item in the cache.
  ///
  /// ```dart
  /// await Cache.put('key', 'value', ttl: Duration(seconds: 10));
  /// ```
  ///
  /// **Parameters:**
  /// - [key]: The key to store the value under.
  /// - [value]: The value to store (must be supported by GetStorage).
  /// - [ttl]: Optional duration after which the item expires.
  static Future<void> put(String key, dynamic value, {Duration? ttl}) {
    return _service.put(key, value, ttl: ttl);
  }

  /// Retrieve an item from the cache.
  ///
  /// ```dart
  /// final value = await Cache.get('key');
  /// final withDefault = await Cache.get('missing', defaultValue: 'default');
  /// ```
  ///
  /// **Parameters:**
  /// - [key]: The key to retrieve.
  /// - [defaultValue]: Value to return if key doesn't exist or is expired.
  static dynamic get(String key, {dynamic defaultValue}) {
    return _service.get(key, defaultValue: defaultValue);
  }

  /// Check if an item exists in the cache.
  ///
  /// ```dart
  /// if (Cache.has('key')) {
  ///   // ...
  /// }
  /// ```
  static bool has(String key) {
    return _service.has(key);
  }

  /// Remove an item from the cache.
  ///
  /// ```dart
  /// await Cache.forget('key');
  /// ```
  static Future<void> forget(String key) {
    return _service.forget(key);
  }

  /// Remove all items from the cache.
  ///
  /// ```dart
  /// await Cache.flush();
  /// ```
  static Future<void> flush() {
    return _service.flush();
  }

  /// Get an item from the cache, or execute the given closure and store the result.
  ///
  /// This method will first attempt to retrieve the item from the cache. If it
  /// does not exist or has expired, the [callback] will be executed. The result
  /// of the callback will be stored in the cache for the specified [ttl] and
  /// then returned.
  ///
  /// ```dart
  /// final users = await Cache.remember('users', Duration(minutes: 5), () async {
  ///   return await fetchUsers();
  /// });
  /// ```
  static Future<T> remember<T>(
    String key,
    Duration ttl,
    Future<T> Function() callback,
  ) async {
    if (has(key)) {
      return get(key) as T;
    }

    final value = await callback();
    await put(key, value, ttl: ttl);
    return value;
  }
}
