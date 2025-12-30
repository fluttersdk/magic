/// The Configuration Repository.
///
/// A powerful configuration manager with dot-notation access and deep merging.
/// This is the internal storage mechanism used by the `Config` facade.
///
/// ## Dot Notation
///
/// Access nested values using dot notation:
///
/// ```dart
/// final config = ConfigRepository({
///   'database': {
///     'host': 'localhost',
///     'port': 5432,
///   }
/// });
///
/// config.get('database.host'); // 'localhost'
/// config.get('database.port'); // 5432
/// ```
///
/// ## Deep Merging
///
/// Merge new configuration without losing nested values:
///
/// ```dart
/// config.merge({
///   'database': {
///     'name': 'myapp', // Added, doesn't overwrite host/port
///   }
/// });
/// ```
class ConfigRepository {
  /// Internal configuration storage.
  final Map<String, dynamic> _config = {};

  /// Create a new configuration repository.
  ///
  /// Optionally provide initial configuration.
  ConfigRepository([Map<String, dynamic>? initial]) {
    if (initial != null) {
      merge(initial);
    }
  }

  // ---------------------------------------------------------------------------
  // Get
  // ---------------------------------------------------------------------------

  /// Get a configuration value using dot notation.
  ///
  /// ```dart
  /// Config.get('app.name');
  /// Config.get('services.stripe.key', 'default-key');
  /// ```
  ///
  /// **Parameters:**
  /// - [key]: Dot-notated key (e.g., 'app.name')
  /// - [defaultValue]: Value to return if key doesn't exist
  T? get<T>(String key, [T? defaultValue]) {
    final segments = key.split('.');
    dynamic current = _config;

    for (final segment in segments) {
      if (current is! Map) {
        return defaultValue;
      }

      if (!current.containsKey(segment)) {
        return defaultValue;
      }

      current = current[segment];
    }

    if (current is T) {
      return current;
    }

    return defaultValue;
  }

  /// Get a configuration value, throwing if not found.
  ///
  /// Use this when the config value is required.
  ///
  /// ```dart
  /// final apiKey = Config.getOrFail<String>('services.api.key');
  /// ```
  T getOrFail<T>(String key) {
    final value = get<T>(key);
    if (value == null) {
      throw Exception('Configuration key [$key] is required but not set.');
    }
    return value;
  }

  // ---------------------------------------------------------------------------
  // Set
  // ---------------------------------------------------------------------------

  /// Set a configuration value using dot notation.
  ///
  /// ```dart
  /// Config.set('app.debug', true);
  /// Config.set('services.mail.driver', 'smtp');
  /// ```
  void set(String key, dynamic value) {
    final segments = key.split('.');
    Map<String, dynamic> current = _config;

    for (var i = 0; i < segments.length - 1; i++) {
      final segment = segments[i];

      if (!current.containsKey(segment) || current[segment] is! Map) {
        current[segment] = <String, dynamic>{};
      }

      current = current[segment] as Map<String, dynamic>;
    }

    current[segments.last] = value;
  }

  // ---------------------------------------------------------------------------
  // Has
  // ---------------------------------------------------------------------------

  /// Check if a configuration key exists.
  ///
  /// ```dart
  /// if (Config.has('services.stripe')) {
  ///   // Stripe is configured
  /// }
  /// ```
  bool has(String key) {
    return get(key) != null;
  }

  // ---------------------------------------------------------------------------
  // All
  // ---------------------------------------------------------------------------

  /// Get all configuration as a Map.
  ///
  /// ```dart
  /// final allConfig = Config.all();
  /// ```
  Map<String, dynamic> all() {
    return Map<String, dynamic>.from(_config);
  }

  // ---------------------------------------------------------------------------
  // Merge
  // ---------------------------------------------------------------------------

  /// Deep merge new configuration into existing.
  ///
  /// This recursively merges maps, so nested values are preserved:
  ///
  /// ```dart
  /// // Initial:
  /// Config.set('database', {'host': 'localhost', 'port': 5432});
  ///
  /// // Merge:
  /// Config.merge({'database': {'name': 'myapp'}});
  ///
  /// // Result:
  /// // database.host = 'localhost' (preserved)
  /// // database.port = 5432 (preserved)
  /// // database.name = 'myapp' (added)
  /// ```
  void merge(Map<String, dynamic> newConfig) {
    _deepMerge(_config, newConfig);
  }

  /// Recursively merge two maps.
  void _deepMerge(Map<String, dynamic> target, Map source) {
    source.forEach((key, value) {
      final keyStr = key.toString();
      if (value is Map && target[keyStr] is Map<String, dynamic>) {
        // Both are maps - recurse
        _deepMerge(target[keyStr] as Map<String, dynamic>, value);
      } else if (value is Map) {
        // Source is a map but target isn't - convert and set
        target[keyStr] = _convertToStringDynamic(value);
      } else {
        // Replace value
        target[keyStr] = value;
      }
    });
  }

  /// Convert a Map to Map<String, dynamic>.
  Map<String, dynamic> _convertToStringDynamic(Map source) {
    final result = <String, dynamic>{};
    source.forEach((key, value) {
      if (value is Map) {
        result[key.toString()] = _convertToStringDynamic(value);
      } else {
        result[key.toString()] = value;
      }
    });
    return result;
  }

  // ---------------------------------------------------------------------------
  // Prepend / Push (Array Config)
  // ---------------------------------------------------------------------------

  /// Prepend a value to an array configuration.
  ///
  /// ```dart
  /// Config.prepend('app.providers', MyProvider);
  /// ```
  void prepend(String key, dynamic value) {
    final existing = get<List>(key) ?? [];
    set(key, [value, ...existing]);
  }

  /// Push a value to an array configuration.
  ///
  /// ```dart
  /// Config.push('app.middlewares', AuthMiddleware);
  /// ```
  void push(String key, dynamic value) {
    final existing = get<List>(key) ?? [];
    set(key, [...existing, value]);
  }

  // ---------------------------------------------------------------------------
  // Forget / Flush
  // ---------------------------------------------------------------------------

  /// Remove a configuration value.
  ///
  /// ```dart
  /// Config.forget('cache.ttl');
  /// ```
  void forget(String key) {
    final segments = key.split('.');
    Map<String, dynamic> current = _config;

    for (var i = 0; i < segments.length - 1; i++) {
      final segment = segments[i];

      if (!current.containsKey(segment) || current[segment] is! Map) {
        return; // Key doesn't exist
      }

      current = current[segment] as Map<String, dynamic>;
    }

    current.remove(segments.last);
  }

  /// Clear all configuration.
  void flush() {
    _config.clear();
  }
}
