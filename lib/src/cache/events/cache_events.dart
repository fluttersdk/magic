import '../../events/magic_event.dart';

/// Fired when a cache lookup returns a stored value (cache hit).
class CacheHit extends MagicEvent {
  CacheHit(this.key, this.value);

  /// The cache key that was queried.
  final String key;

  /// The hit value returned to the caller.
  final dynamic value;
}

/// Fired when a cache lookup returns no stored value (cache miss).
class CacheMiss extends MagicEvent {
  CacheMiss(this.key);

  /// The cache key that was queried but absent.
  final String key;
}

/// Fired when a value is written to the cache.
class CachePut extends MagicEvent {
  CachePut(this.key, this.value, {this.ttl});

  /// The cache key the value was stored under.
  final String key;

  /// The value persisted to cache.
  final dynamic value;

  /// Optional time-to-live; `null` means default driver TTL.
  final Duration? ttl;
}

/// Fired when a single key is removed from the cache.
class CacheForget extends MagicEvent {
  CacheForget(this.key);

  /// The cache key removed.
  final String key;
}

/// Fired when the entire cache is flushed.
class CacheFlush extends MagicEvent {
  CacheFlush();
}
