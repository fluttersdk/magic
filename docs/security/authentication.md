# Authentication

Simple, frontend-focused auth with user caching and auto token refresh.

## Quick Start

```dart
// 1. Register user factory
Auth.manager.setUserFactory((data) => User.fromMap(data));

// 2. Login
final response = await Http.post('/login', data: credentials);
final user = User.fromMap(response['data']['user']);
await Auth.login({
  'token': response['data']['token'],
  'refresh_token': response['data']['refresh_token'],
}, user);

// 3. Check auth
if (Auth.check()) {
  final user = Auth.user<User>();
}
```

---

## Features

| Feature | Description |
|---------|-------------|
| **User Caching** | Instant restore from cache, then sync from API |
| **Auto Token Refresh** | 401 → refresh token → retry request |
| **Driver-Agnostic** | Interceptors work with any HTTP driver |

---

## Guard Contract

```dart
abstract class Guard {
  Future<void> login(Map<String, dynamic> data, Authenticatable user);
  Future<void> logout();
  bool check();
  bool get guest;
  T? user<T>();
  dynamic id();
  void setUser(Authenticatable user);
  Future<bool> hasToken();
  Future<String?> getToken();
  Future<bool> refreshToken();
  Future<void> restore();
}
```

---

## Built-in Guards

| Guard | Login Data |
|-------|-----------|
| `BearerTokenGuard` | `token`, `refresh_token` |
| `BasicAuthGuard` | `username`, `password` |
| `ApiKeyGuard` | `api_key` |

---

## Custom Guards

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

// Register
Auth.manager.extend('myguard', (c) => MyGuard());
```

### Firebase Example

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
    final cached = await loadCachedUser();
    if (cached != null) setUser(cached);

    final fbUser = _auth.currentUser;
    if (fbUser == null) { await logout(); return; }

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
  Future<bool> refreshToken() async {
    final token = await _auth.currentUser?.getIdToken(true);
    if (token != null) { await storeToken(token); return true; }
    return false;
  }

  @override
  Future<void> logout() async {
    await _auth.signOut();
    await super.logout();
  }
}
```

---

## Auth Facade

| Method | Description |
|--------|-------------|
| `login(data, user)` | Store token and user |
| `logout()` | Clear everything |
| `check()` | Is authenticated? |
| `user<T>()` | Get user |
| `refreshToken()` | Refresh token manually |
| `restore()` | Restore from cache + API |

---

## Interceptor Architecture

The auth interceptor is driver-agnostic:

```dart
// MagicRequest, MagicResponse, MagicError - no Dio dependency
class AuthInterceptor extends MagicNetworkInterceptor {
  @override
  dynamic onRequest(MagicRequest request) {
    request.headers['Authorization'] = 'Bearer $token';
    return request;
  }

  @override
  dynamic onError(MagicError error) async {
    if (error.isUnauthorized) {
      await Auth.refreshToken();
      // Retry via Http facade
    }
    return error;
  }
}
```

---

## Configuration

```dart
'auth': {
  'guards': {'api': {'driver': 'bearer'}},
  'endpoints': {'user': '/api/user', 'refresh': '/api/refresh'},
  'token': {'key': 'auth_token', 'header': 'Authorization', 'prefix': 'Bearer'},
  'auto_refresh': true,
}
```

---

## Protecting Routes

```dart
MagicRoute.page('/dashboard', () => DashboardView())
    .middleware(['auth']);
```
