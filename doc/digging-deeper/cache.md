# Cache

- [Introduction](#introduction)
- [Configuration](#configuration)
- [Retrieving Items](#retrieving-items)
- [Storing Items](#storing-items)
- [The Remember Method](#the-remember-method)
- [Removing Items](#removing-items)
- [Custom Cache Drivers](#custom-cache-drivers)

<a name="introduction"></a>
## Introduction

Magic provides an expressive, unified API for various caching backends. The framework ships with a native `FileStore` driver that supports both Mobile/Desktop (File System) and Web (LocalStorage).

Caching is essential for reducing API calls, storing computed values, and improving application performance.

<a name="configuration"></a>
## Configuration

### Enabling Cache Support

Add `CacheServiceProvider` to your providers in `config/app.dart`:

```dart
'providers': [
  (app) => CacheServiceProvider(app),
  // ... other providers
],
```

### Cache Configuration

Create `lib/config/cache.dart`:

```dart
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

Map<String, dynamic> get cacheConfig => {
  'cache': {
    'driver': FileStore(fileName: 'magic_cache'),
    'ttl': 3600, // Default TTL in seconds
  },
};
```

<a name="retrieving-items"></a>
## Retrieving Items

Use the `Cache` facade to retrieve items from the cache:

```dart
// Basic retrieval
final value = await Cache.get('key');

// With default value
final username = await Cache.get('username', defaultValue: 'Guest');

// Check existence
if (await Cache.has('user_settings')) {
  final settings = await Cache.get('user_settings');
}
```

<a name="storing-items"></a>
## Storing Items

Store items with optional TTL (time-to-live):

```dart
// With custom TTL
await Cache.put('key', 'value', ttl: Duration(minutes: 10));

// With default TTL from config
await Cache.put('key', 'value');

// Store any serializable data
await Cache.put('user', {
  'id': 1,
  'name': 'John',
  'email': 'john@example.com',
});


```

<a name="the-remember-method"></a>
## The Remember Method

The most powerful caching pattern—retrieve from cache or compute and store:

```dart
final users = await Cache.remember(
  'users', 
  Duration(minutes: 5), 
  () async {
    return await Http.get('/users');
  },
);
```

This method:
1. Checks if `users` exists in cache
2. If yes, returns the cached value
3. If no, calls the closure, stores the result, and returns it

### API Response Caching

```dart
class UserController extends MagicController {
  Future<List<User>> getUsers() async {
    return await Cache.remember('all_users', Duration(minutes: 10), () async {
      final response = await Http.get('/users');
      return (response.body as List).map((u) => User.fromMap(u)).toList();
    });
  }
}
```

### Computed Values

```dart
final dashboardStats = await Cache.remember('dashboard_stats', Duration(hours: 1), () async {
  return {
    'total_users': await User.count(),
    'active_monitors': await Monitor.where('is_active', true).count(),
    'incidents_today': await Incident.whereDate('created_at', Carbon.today()).count(),
  };
});
```

<a name="removing-items"></a>
## Removing Items

```dart
// Remove a single item
await Cache.forget('users');

// Clear entire cache
await Cache.flush();
```

### Invalidating Related Cache

```dart
class UserController extends MagicController {
  Future<void> updateUser(Map<String, dynamic> data) async {
    final response = await Http.put('/users/${data['id']}', data: data);
    
    if (response.successful) {
      // Invalidate related caches
      await Cache.forget('all_users');
      await Cache.forget('user_${data['id']}');
      await Cache.forget('dashboard_stats');
    }
  }
}
```

<a name="custom-cache-drivers"></a>
## Custom Cache Drivers

Implement `CacheStore` for custom backends:

```dart
class RedisStore implements CacheStore {
  final RedisClient _client;
  
  RedisStore(this._client);

  @override
  Future<void> init() async {
    await _client.connect();
  }

  @override
  Future<dynamic> get(String key, {dynamic defaultValue}) async {
    final value = await _client.get(key);
    if (value == null) return defaultValue;
    return jsonDecode(value);
  }

  @override
  Future<void> put(String key, dynamic value, {Duration? ttl}) async {
    final encoded = jsonEncode(value);
    if (ttl != null) {
      await _client.setex(key, ttl.inSeconds, encoded);
    } else {
      await _client.set(key, encoded);
    }
  }

  @override
  Future<bool> has(String key) async {
    return await _client.exists(key) > 0;
  }

  @override
  Future<void> forget(String key) async {
    await _client.del(key);
  }

  @override
  Future<void> flush() async {
    await _client.flushdb();
  }
}
```

Use your custom driver in config:

```dart
'cache': {
  'driver': RedisStore(RedisClient()),
},
```

> [!TIP]
> Use caching for expensive API calls, complex computations, and data that doesn't change frequently.
