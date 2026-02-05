# Facades

- [Introduction](#introduction)
- [When To Use Facades](#when-to-use-facades)
- [Available Facades](#available-facades)
- [How Facades Work](#how-facades-work)
- [Facade Class Reference](#facade-class-reference)

<a name="introduction"></a>
## Introduction

Facades provide a "static" interface to classes that are available in the application's service container. Magic ships with many facades which provide access to almost all of Magic's features. Magic facades serve as "static proxies" to underlying classes in the service container, providing the benefit of a terse, expressive syntax.

```dart
// Using a facade - clean and expressive
await Cache.put('key', 'value');
final user = Auth.user<User>();
MagicRoute.to('/dashboard');

// Instead of resolving from container
final cache = app.make<CacheManager>('cache');
await cache.put('key', 'value');
```

<a name="when-to-use-facades"></a>
## When To Use Facades

Facades have many benefits. They provide a terse, memorable syntax that allows you to use Magic's features without remembering long class names or understanding dependency injection.

Use facades when:
- You need quick access to a service from anywhere
- You want clean, readable code
- The service is stateless or globally applicable
- You're in a controller, service, or helper class

<a name="available-facades"></a>
## Available Facades

Magic provides the following facades:

### Core Facades

| Facade | Description |
|--------|-------------|
| `Magic` | Application container, UI helpers (snackbar, dialog) |
| `Config` | Configuration values access |
| `Env` | Environment variables |

### Authentication & Security

| Facade | Description |
|--------|-------------|
| `Auth` | Authentication state and user |
| `Gate` | Authorization abilities and policies |
| `Vault` | Secure storage (Keychain/Keystore) |

### HTTP & Network

| Facade | Description |
|--------|-------------|
| `Http` | HTTP client for API requests |

### Routing

| Facade | Description |
|--------|-------------|
| `MagicRoute` | Navigation and route definitions |

### Data & Storage

| Facade | Description |
|--------|-------------|
| `Cache` | Caching system |
| `Storage` | File storage |

### Utilities

| Facade | Description |
|--------|-------------|
| `Carbon` | Date and time manipulation |
| `Lang` | Localization and translations |
| `Event` | Event dispatching |
| `Log` | Logging |

<a name="how-facades-work"></a>
## How Facades Work

Behind the scenes, facades access the service container and resolve the relevant service. For example:

```dart
// When you call:
Cache.put('key', 'value');

// Magic actually does:
Magic.make<CacheManager>('cache').put('key', 'value');
```

Each facade has a static method that proxies to the underlying service instance.

<a name="facade-class-reference"></a>
## Facade Class Reference

### Magic

```dart
// Service container
Magic.bind('key', () => Service());
Magic.make<Service>('key');
Magic.findOrPut(Controller.new);

// UI Helpers
Magic.success('Title', 'Message');
Magic.error('Title', 'Message');
Magic.info('Title', 'Message');
Magic.warning('Title', 'Message');
Magic.toast('Message');
Magic.loading(message: 'Please wait...');
Magic.closeLoading();
Magic.dialog(Widget());
Magic.closeDialog();
await Magic.confirm(title: 'Delete?', message: '...');
```

### Config

```dart
Config.get<String>('app.name', 'Default');
Config.set('app.locale', 'tr');
Config.has('services.stripe');
Config.all();
Config.merge({'key': 'value'});
```

### Auth

```dart
Auth.check();                    // Is authenticated?
Auth.guest();                    // Is guest?
Auth.user<User>();              // Get typed user
Auth.id();                       // Get user ID
await Auth.login(data, user);   // Login
await Auth.logout();            // Logout
await Auth.restore();           // Restore from cache
await Auth.refreshToken();      // Refresh token
```

### MagicRoute

```dart
// Navigation
MagicRoute.to('/path');
MagicRoute.push('/path');
MagicRoute.back();
MagicRoute.replace('/path');
MagicRoute.toNamed('route.name', params: {});

// Route definition
MagicRoute.page('/path', () => Widget());
MagicRoute.group(prefix: '/admin', routes: () {});
```

### Http

```dart
await Http.get('/users', query: {'page': 1});
await Http.post('/users', data: {...});
await Http.put('/users/1', data: {...});
await Http.patch('/users/1', data: {...});
await Http.delete('/users/1');

// RESTful shortcuts
await Http.index('users');
await Http.show('users', '1');
await Http.store('users', data);
await Http.update('users', '1', data);
await Http.destroy('users', '1');
```

### Cache

```dart
await Cache.get('key', defaultValue: 'default');
await Cache.put('key', 'value', ttl: Duration(minutes: 5));
await Cache.remember('key', duration, () async => compute());
await Cache.forget('key');
await Cache.flush();
```

### Gate

```dart
Gate.define('ability', (user, model) => bool);
Gate.before((user, ability) => true/false/null);
Gate.allows('ability', model);
Gate.denies('ability', model);
```

### Lang

```dart
trans('key', {'param': 'value'});  // Global helper
Lang.locale;                        // Current locale
await Lang.setLocale(Locale('tr'));
Lang.isSupported(Locale('en'));
```

### Carbon

```dart
Carbon.now();
Carbon.parse('2024-01-15');

carbon.addDays(5);
carbon.subMonths(2);
carbon.diffForHumans();    // "2 days ago"
carbon.format('yyyy-MM-dd');
carbon.isToday();
carbon.isFuture();
```

### Vault

```dart
await Vault.put('api_key', 'secret');
await Vault.get('api_key');
await Vault.delete('api_key');
await Vault.has('api_key');
```

> [!TIP]
> When in doubt, check the facade source file in `/lib/src/facades/` for all available methods.
