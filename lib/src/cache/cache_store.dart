/// The Cache Store Contract.
///
/// This interface corresponds to Laravel's `Illuminate\Contracts\Cache\Store`.
abstract class CacheStore {
  /// Retrieve an item from the cache by key.
  dynamic get(String key, {dynamic defaultValue});

  /// Store an item in the cache for a given number of seconds.
  Future<void> put(String key, dynamic value, {Duration? ttl});

  /// Determine if an item exists in the cache.
  bool has(String key);

  /// Remove an item from the cache.
  Future<void> forget(String key);

  /// Remove all items from the cache.
  Future<void> flush();

  /// Initialize the driver (optional async setup).
  Future<void> init();
}
