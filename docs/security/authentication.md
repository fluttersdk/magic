# Authentication

- [Introduction](#introduction)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [The Auth Facade](#the-auth-facade)
- [Guards](#guards)
    - [Built-in Guards](#built-in-guards)
    - [Custom Guards](#custom-guards)
- [Auto Token Refresh](#auto-token-refresh)
- [Protecting Routes](#protecting-routes)
- [Login & Logout](#login--logout)

<a name="introduction"></a>
## Introduction

Magic provides a simple, frontend-focused authentication system with user caching and automatic token refresh. Like Laravel's Auth system, it's built around the concept of "guards" that define how users are authenticated.

### Key Features

| Feature | Description |
|---------|-------------|
| **User Caching** | Instant restore from secure cache, then sync from API |
| **Auto Token Refresh** | 401 response → refresh token → retry original request |
| **Multiple Guards** | Support for Bearer, Basic, API Key, or custom guards |
| **Secure Storage** | Tokens stored in platform secure storage (Keychain/Keystore) |

<a name="quick-start"></a>
## Quick Start

```dart
// 1. Register user factory (tells Magic how to create User from API data)
Auth.registerModel<User>(User.fromMap);

// 2. Login after API call
final response = await Http.post('/login', data: {
  'email': email,
  'password': password,
});

if (response.successful) {
  final user = User.fromMap(response['data']['user']);
  await Auth.login({
    'token': response['data']['token'],
    'refresh_token': response['data']['refresh_token'],
  }, user);
  
  MagicRoute.to('/dashboard');
}

// 3. Check authentication anywhere
if (Auth.check()) {
  final user = Auth.user<User>();
  print('Welcome, ${user?.name}');
}

// 4. Logout
await Auth.logout();
MagicRoute.to('/login');
```

<a name="configuration"></a>
## Configuration

Create `lib/config/auth.dart`:

```dart
Map<String, dynamic> get authConfig => {
  'auth': {
    'defaults': {
      'guard': 'api',
    },
    'guards': {
      'api': {
        'driver': 'bearer',
      },
    },
    'endpoints': {
      'user': '/api/user',
      'refresh': '/api/auth/refresh',
    },
    'token': {
      'key': 'auth_token',
      'header': 'Authorization',
      'prefix': 'Bearer',
    },
    'auto_refresh': true,
  },
};
```

Register in your config and add `AuthServiceProvider`:

```dart
'providers': [
  (app) => AuthServiceProvider(app),
  // ...
],
```

<a name="the-auth-facade"></a>
## The Auth Facade

The `Auth` facade provides convenient access to authentication functionality:

```dart
// Check if user is authenticated
Auth.check()              // bool

// Check if user is a guest (not authenticated)
Auth.guest()              // bool

// Get the authenticated user
Auth.user<User>()         // User?

// Get user ID
Auth.id()                 // dynamic

// Login
await Auth.login(tokenData, user)

// Logout
await Auth.logout()

// Restore session from cache
await Auth.restore()

// Manually refresh token
await Auth.refreshToken()

// Token management
await Auth.hasToken()     // bool
await Auth.getToken()     // String?
```

<a name="guards"></a>
## Guards

Guards define how users are authenticated. Each guard implements the `Guard` contract:

```dart
abstract class Guard {
  Future<void> login(Map<String, dynamic> data, Authenticatable user);
  Future<void> logout();
  bool check();
  bool get guest;
  T? user<T>();
  dynamic id();
  Future<bool> hasToken();
  Future<String?> getToken();
  Future<bool> refreshToken();
  Future<void> restore();
}
```

<a name="built-in-guards"></a>
### Built-in Guards

| Guard | Login Data | Use Case |
|-------|-----------|----------|
| `BearerTokenGuard` | `token`, `refresh_token` | JWT/OAuth APIs |
| `BasicAuthGuard` | `username`, `password` | Basic HTTP Auth |
| `ApiKeyGuard` | `api_key` | API Key authentication |

<a name="custom-guards"></a>
### Custom Guards

Create custom guards by extending `BaseGuard`:

```dart
class MyGuard extends BaseGuard {
  MyGuard() : super(
    userEndpoint: '/api/me',
    refreshEndpoint: '/api/refresh',
    userFactory: (data) => User.fromMap(data),
  );

  @override
  Future<void> login(Map<String, dynamic> data, Authenticatable user) async {
    await storeToken(data['token'], data['refresh_token']);
    await cacheUser(user);
    setUser(user);
  }
}

// Register in your auth config
Auth.manager.extend('myguard', (config) => MyGuard());
```

### Firebase Guard Example

```dart
class FirebaseGuard extends BaseGuard {
  final _auth = firebase.FirebaseAuth.instance;

  FirebaseGuard() : super(userFactory: (data) => User.fromMap(data));

  @override
  Future<void> login(Map<String, dynamic> data, Authenticatable user) async {
    final idToken = await _auth.currentUser?.getIdToken();
    if (idToken != null) await storeToken(idToken);
    await cacheUser(user);
    setUser(user);
  }

  @override
  Future<void> restore() async {
    // Try cached user first (instant UI)
    final cached = await loadCachedUser();
    if (cached != null) setUser(cached);

    // Then verify with Firebase
    final fbUser = _auth.currentUser;
    if (fbUser == null) {
      await logout();
      return;
    }

    final token = await fbUser.getIdToken();
    if (token != null) await storeToken(token);

    final user = userFactory!({
      'id': fbUser.uid,
      'email': fbUser.email,
      'name': fbUser.displayName,
    });
    setUser(user);
    await cacheUser(user);
  }

  @override
  Future<void> logout() async {
    await _auth.signOut();
    await super.logout();
  }
}
```

<a name="auto-token-refresh"></a>
## Auto Token Refresh

When `auto_refresh` is enabled, Magic automatically handles 401 responses:

1. Original request fails with 401
2. Interceptor calls `Auth.refreshToken()`
3. If refresh succeeds, original request is retried with new token
4. If refresh fails, user is logged out

The auth interceptor is built into `AuthServiceProvider` and works automatically when configured.

```dart
// Manual token refresh
final success = await Auth.refreshToken();
if (!success) {
  await Auth.logout();
  MagicRoute.to('/login');
}
```

<a name="protecting-routes"></a>
## Protecting Routes

Use the `auth` middleware to protect routes:

```dart
// Single route
MagicRoute.page('/dashboard', () => DashboardView())
    .middleware(['auth']);

// Route group
MagicRoute.group(
  middleware: ['auth'],
  routes: () {
    MagicRoute.page('/dashboard', () => DashboardView());
    MagicRoute.page('/profile', () => ProfileView());
    MagicRoute.page('/settings', () => SettingsView());
  },
);
```

Create a `guest` middleware to redirect authenticated users:

```dart
class RedirectIfAuthenticated extends MagicMiddleware {
  @override
  Future<void> handle(void Function() next) async {
    if (Auth.check()) {
      MagicRoute.to('/dashboard');
    } else {
      next();
    }
  }
}
```

<a name="login--logout"></a>
## Login & Logout

### Login Flow

```dart
class AuthController extends MagicController with ValidatesRequests {
  Future<void> login(Map<String, dynamic> data) async {
    clearErrors();
    
    final response = await Http.post('/login', data: data);
    
    if (response.successful) {
      final user = User.fromMap(response['data']['user']);
      
      await Auth.login({
        'token': response['data']['token'],
        'refresh_token': response['data']['refresh_token'],
      }, user);
      
      Magic.success('Success', 'Welcome back!');
      MagicRoute.to('/dashboard');
    } else {
      handleApiError(response, fallback: 'Invalid credentials');
    }
  }
}
```

### Logout Flow

```dart
Future<void> logout() async {
  // Optionally notify backend
  await Http.post('/logout');
  
  // Clear local auth state
  await Auth.logout();
  
  Magic.info('Logged Out', 'See you next time!');
  MagicRoute.to('/login');
}
```

### Restoring Session on App Start

In your `main.dart`:

```dart
void main() async {
  await Magic.init(...);
  
  // Restore auth session from cache
  await Auth.restore();
  
  runApp(MagicApplication(...));
}
```

This instantly restores the cached user for a fast startup, then syncs with the API in the background.
