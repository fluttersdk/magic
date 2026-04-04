import '../cache/cache_manager.dart';
import '../cache/cache_store.dart';

/// A recorded cache operation entry.
typedef CacheRecord = ({String operation, String key, dynamic value});

/// A fake [CacheManager] for testing.
///
/// Routes all cache operations through an in-memory store instead of a
/// real driver. Supports assertions and operation recording.
///
/// ```dart
/// final fake = Cache.fake();
///
/// await Cache.put('user', 'alice');
///
/// fake.assertHas('user');
/// fake.assertPut('user');
/// ```
class FakeCacheManager extends CacheManager {
  final _InMemoryCacheStore _store = _InMemoryCacheStore();

  /// All recorded cache operations in chronological order.
  final List<CacheRecord> recorded = [];

  @override
  CacheStore driver([String? driver]) => _store;

  // ---------------------------------------------------------------------------
  // Proxy — record every operation then delegate
  // ---------------------------------------------------------------------------

  @override
  dynamic get(String key, {dynamic defaultValue}) {
    final value = _store.get(key, defaultValue: defaultValue);
    recorded.add((operation: 'get', key: key, value: value));
    return value;
  }

  @override
  Future<void> put(String key, dynamic value, {Duration? ttl}) async {
    await _store.put(key, value, ttl: ttl);
    recorded.add((operation: 'put', key: key, value: value));
  }

  @override
  bool has(String key) => _store.has(key);

  @override
  Future<void> forget(String key) async {
    await _store.forget(key);
    recorded.add((operation: 'forget', key: key, value: null));
  }

  @override
  Future<void> flush() async {
    await _store.flush();
    recorded.add((operation: 'flush', key: '', value: null));
  }

  @override
  Future<void> init() => Future<void>.value();

  // ---------------------------------------------------------------------------
  // Assertions
  // ---------------------------------------------------------------------------

  /// Assert that [key] currently exists in the cache store.
  void assertHas(String key) {
    if (!_store.has(key)) {
      throw AssertionError(
        'Expected cache to have key "$key" but it was missing.',
      );
    }
  }

  /// Assert that [key] does not exist in the cache store.
  void assertMissing(String key) {
    if (_store.has(key)) {
      throw AssertionError(
        'Expected cache to be missing key "$key" but it was present.',
      );
    }
  }

  /// Assert that [key] was stored via [put] at least once.
  void assertPut(String key) {
    final wasPut = recorded.any((r) => r.operation == 'put' && r.key == key);
    if (!wasPut) {
      throw AssertionError(
        'Expected cache key "$key" to have been put but it was never stored.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Reset
  // ---------------------------------------------------------------------------

  /// Clear the store and all recorded operations.
  void reset() {
    _store._data.clear();
    recorded.clear();
  }
}

// ---------------------------------------------------------------------------
// Internal in-memory store
// ---------------------------------------------------------------------------

class _InMemoryCacheStore implements CacheStore {
  final Map<String, dynamic> _data = {};

  @override
  Future<void> init() => Future<void>.value();

  @override
  dynamic get(String key, {dynamic defaultValue}) =>
      _data.containsKey(key) ? _data[key] : defaultValue;

  @override
  Future<void> put(String key, dynamic value, {Duration? ttl}) async {
    _data[key] = value;
  }

  @override
  bool has(String key) => _data.containsKey(key);

  @override
  Future<void> forget(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> flush() async {
    _data.clear();
  }
}
