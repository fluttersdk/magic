import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

import '../cache_store.dart';
import '../../facades/config.dart';

/// Native File-based Cache Driver (IO Implementation).
class FileStore implements CacheStore {
  /// The in-memory cache.
  Map<String, dynamic> _memory = {};

  /// The file where data is persisted.
  File? _file;

  /// The name of the file (without extension).
  final String fileName;

  FileStore({this.fileName = 'magic_cache'});

  /// Constants for storage keys
  static const String _keyPayload = 'payload';
  static const String _keyExpireAt = 'expire_at';

  @override
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, '$fileName.json');
    _file = File(path);

    if (await _file!.exists()) {
      try {
        final content = await _file!.readAsString();
        if (content.isNotEmpty) {
          _memory = json.decode(content) as Map<String, dynamic>;
        }
      } catch (e) {
        // Starting fresh is the right answer for a cache: the data is by
        // definition reproducible, and refusing to boot over it would be
        // worse than losing it. But doing it silently means a file that is
        // corrupt on every launch looks exactly like a cache that is merely
        // cold, so the reason is printed rather than swallowed.
        debugPrint('FileStore: cache file unreadable, starting fresh ($e)');
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
      // Evicted from memory only. `get` is synchronous, so the write this used
      // to fire could not be awaited: a failure had nowhere to go and became
      // an unhandled async error, and reading N stale keys rewrote the whole
      // file N times. Correctness does not need it, because expiry and shape
      // are re-checked on every read, so a row left on disk is inert. The next
      // write persists the map without it.
      _memory.remove(key);
      return defaultValue;
    }

    final int? expireAt = data[_keyExpireAt] as int?;
    if (expireAt != null) {
      if (DateTime.now().millisecondsSinceEpoch > expireAt) {
        _memory.remove(key);
        return defaultValue; // Expired
      }
    }

    return data[_keyPayload];
  }

  @override
  Future<void> put(String key, dynamic value, {Duration? ttl}) async {
    // defaults to 1 hour if not set
    final duration = ttl ?? Duration(seconds: Config.get('cache.ttl', 3600)!);
    final int expireAt = DateTime.now().add(duration).millisecondsSinceEpoch;

    _memory[key] = {_keyPayload: value, _keyExpireAt: expireAt};

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

  /// Persist the in-memory cache to disk.
  Future<void> _persist() async {
    if (_file == null) return;
    // Simple write for now. Could be optimized with debounce or async queue.
    await _file!.writeAsString(json.encode(_memory));
  }
}
