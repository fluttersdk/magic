# Service Container

- [Introduction](#introduction)
- [Binding Services](#binding-services)
    - [Simple Bindings](#simple-bindings)
    - [Singletons](#singletons)
- [Resolving Services](#resolving-services)
- [Automatic Resolution](#automatic-resolution)
- [Using Controllers](#using-controllers)

<a name="introduction"></a>
## Introduction

The Magic service container is a powerful tool for managing class dependencies and performing dependency injection. Like Laravel's container, it allows you to register bindings and resolve them throughout your application.

```dart
// Register a service
Magic.bind('mailer', () => MailService());

// Resolve it anywhere
final mailer = Magic.make<MailService>('mailer');
```

<a name="binding-services"></a>
## Binding Services

<a name="simple-bindings"></a>
### Simple Bindings

Use `Magic.bind()` to register a service. Each resolve creates a new instance:

```dart
Magic.bind('api', () => ApiClient());

// Each call creates a new instance
final api1 = Magic.make<ApiClient>('api');
final api2 = Magic.make<ApiClient>('api');
// api1 != api2
```

<a name="singletons"></a>
### Singletons

Use `Magic.singleton()` to register a service that's instantiated only once:

```dart
Magic.singleton('cache', () => CacheManager());

// Always returns the same instance
final cache1 = Magic.make<CacheManager>('cache');
final cache2 = Magic.make<CacheManager>('cache');
// cache1 == cache2
```

### Binding in Service Providers

The recommended way to register services is in a service provider:

```dart
class AppServiceProvider extends ServiceProvider {
  @override
  void register() {
    // Register services
    app.bind('api', () => ApiClient(Config.get('api.url')));
    app.singleton('cache', () => CacheManager());
  }

  @override
  Future<void> boot() async {
    // Perform initialization after all services are registered
    final cache = app.make<CacheManager>('cache');
    await cache.initialize();
  }
}
```

<a name="resolving-services"></a>
## Resolving Services

### Using Magic.make()

```dart
// With type inference
final service = Magic.make<MyService>('myservice');

// Without type (returns dynamic)
final service = Magic.make('myservice');
```

### Checking Existence

```dart
if (Magic.bound('api')) {
  final api = Magic.make<ApiClient>('api');
}
```

<a name="automatic-resolution"></a>
## Automatic Resolution

Magic facades automatically resolve their underlying services. You don't need to manually resolve common services:

```dart
// These facades auto-resolve from the container:
Cache.get('key');           // Resolves CacheManager
Auth.check();               // Resolves AuthManager
Lang.setLocale(locale);     // Resolves LocalizationService
```

<a name="using-controllers"></a>
## Using Controllers

Magic provides a convenient way to manage controller instances:

### findOrPut Pattern

The recommended pattern for controllers is using `Magic.findOrPut()`:

```dart
class UserController extends MagicController with MagicStateMixin<List<User>> {
  // Singleton accessor
  static UserController get instance => Magic.findOrPut(UserController.new);
  
  // Controller logic...
}

// Usage anywhere in your app
final controller = UserController.instance;
```

### How It Works

1. **First call**: Creates a new controller instance and stores it
2. **Subsequent calls**: Returns the existing instance
3. **Automatic cleanup**: Controller's `onClose()` is called when disposed

### Manual Controller Management

```dart
// Register a controller
Magic.put(UserController());

// Find an existing controller
final controller = Magic.find<UserController>();

// Delete a controller
Magic.delete<UserController>();
```

### Controller Lifecycle

```dart
class UserController extends MagicController {
  @override
  void onInit() {
    // Called when controller is first created
    loadUsers();
  }

  @override
  void onClose() {
    // Called when controller is disposed
    // Clean up subscriptions, streams, etc.
  }
}
```

> [!TIP]
> Use the `findOrPut` pattern for controllers to ensure a single instance is used throughout your application while maintaining proper lifecycle management.
