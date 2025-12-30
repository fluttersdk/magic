import 'dart:convert';
import 'package:web/web.dart' as web;
import '../cache_store.dart';
import '../../facades/config.dart';

/// Native File-based Cache Driver (Web Implementation).
///
/// Uses localStorage to persist data.
class FileStore implements CacheStore {
  /// The in-memory cache.
  Map<String, dynamic> _memory = {};

  /// The name of the file (key in localStorage).
  final String fileName;

  FileStore({this.fileName = 'magic_cache'});

  /// Constants for storage keys
  static const String _keyPayload = 'payload';
  static const String _keyExpireAt = 'expire_at';

  web.Storage get localStorage => web.window.localStorage;

  @override
  Future<void> init() async {
    final stored = localStorage.getItem(fileName);
    if (stored != null) {
      try {
        _memory = json.decode(stored) as Map<String, dynamic>;
      } catch (e) {
        _memory = {};
      }
    } else {
      _memory = {};
    }
  }

  @override
  dynamic get(String key, {dynamic defaultValue}) {
    if (!_memory.containsKey(key)) {
      return defaultValue;
    }

    final data = _memory[key];

    if (data is! Map) {
      _memory.remove(key);
      _persist();
      return defaultValue;
    }

    final int? expireAt = data[_keyExpireAt] as int?;
    if (expireAt != null) {
      if (DateTime.now().millisecondsSinceEpoch > expireAt) {
        _memory.remove(key);
        _persist();
        return defaultValue; // Expired
      }
    }

    return data[_keyPayload];
  }

  @override
  Future<void> put(String key, dynamic value, {Duration? ttl}) async {
    final duration = ttl ?? Duration(seconds: Config.get('cache.ttl', 3600)!);
    final int expireAt = DateTime.now().add(duration).millisecondsSinceEpoch;

    _memory[key] = {
      _keyPayload: value,
      _keyExpireAt: expireAt,
    };

    await _persist();
  }

  @override
  bool has(String key) {
    return get(key) != null;
  }

  @override
  Future<void> forget(String key) async {
    _memory.remove(key);
    await _persist();
  }

  @override
  Future<void> flush() async {
    _memory.clear();
    await _persist();
  }

  Future<void> _persist() async {
    localStorage.setItem(fileName, json.encode(_memory));
  }
}
