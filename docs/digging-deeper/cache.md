# Cache

## Introduction

Magic provides an expressive, unified API for various caching backends. The framework ships with a native `FileStore` driver that supports both Mobile/Desktop (File System) and Web (LocalStorage).

## Enabling Cache Support

By default, the cache service provider is **not enabled**. You can enable it using the Magic CLI:

```bash
magic init:cache
```

This command will:
- Create `config/cache.dart` with default settings
- Add `CacheServiceProvider` to your providers

### Manual Setup

Alternatively, add the provider manually to your `config/app.dart`:

```dart
'providers': [
  (app) => CacheServiceProvider(app),
],
```

## Configuration

```dart
// config/cache.dart
'cache': {
  'driver': FileStore(fileName: 'magic_cache'),
  'ttl': 3600, // Default TTL in seconds
}
```

## Retrieving Items

```dart
final value = await Cache.get('key');

// With default value
final value = await Cache.get('key', defaultValue: 'default');
```

## Storing Items

```dart
// With custom TTL
await Cache.put('key', 'value', ttl: Duration(minutes: 10));

// Uses default TTL
await Cache.put('key', 'value');
```

## Removing Items

```dart
// Remove single item
await Cache.forget('key');

// Clear entire cache
await Cache.flush();
```

## The Remember Method

Retrieve from cache or store a computed value:

```dart
final users = await Cache.remember('users', const Duration(minutes: 5), () async {
  return await fetchUsersFromApi();
});
```

## Custom Drivers

Implement `CacheStore` for custom backends:

```dart
class MyCustomStore implements CacheStore {
  @override
  Future<void> init() async {
    // Async setup
  }

  @override
  dynamic get(String key, {dynamic defaultValue}) {
    // ...
  }

  // ... implement put, has, forget, flush
}
```
