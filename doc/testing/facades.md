# Facade Testing

- [Introduction](#introduction)
- [Auth.fake()](#auth-fake)
- [Cache.fake()](#cache-fake)
- [Vault.fake()](#vault-fake)
- [Log.fake()](#log-fake)
- [Full Example](#full-example)
- [Unfaking](#unfaking)

<a name="introduction"></a>
## Introduction

Magic provides a first-class facade faking API for Auth, Cache, Vault, and Log. Each facade exposes a `fake()` static method that swaps the IoC-bound service with an in-memory implementation for the duration of a test. No real credentials, storage, or output is touched.

Call `fake()` in `setUp` and `unfake()` in `tearDown`:

```dart
setUp(() {
  MagicApp.reset();
  Magic.flush();

  final authFake = Auth.fake();
  final cacheFake = Cache.fake();
  final vaultFake = Vault.fake();
  final logFake = Log.fake();
});

tearDown(() {
  Auth.unfake();
  Cache.unfake();
  Vault.unfake();
  Log.unfake();
});
```

Each `fake()` call returns its fake instance so you can run assertions after the code under test executes.

<a name="auth-fake"></a>
## Auth.fake()

`Auth.fake()` replaces the real `AuthManager` with a `FakeAuthManager` that routes all guard operations through an in-memory `_FakeGuard`. No platform channels, no secure storage, no token refresh calls.

**Signature:**

```dart
static FakeAuthManager fake({Authenticatable? user})
```

Pass `user` to pre-authenticate before the test body runs.

### Basic Usage

```dart
test('dashboard redirects guests to login', () {
  Auth.fake(); // No user — guest state

  expect(Auth.check(), isFalse);
  expect(Auth.guest, isTrue);
});

test('user is pre-authenticated', () {
  final user = User()..fill({'id': 1, 'name': 'Alice'});
  Auth.fake(user: user);

  expect(Auth.check(), isTrue);
  expect(Auth.user<User>()?.name, 'Alice');
});
```

### Assertions

| Method | Description |
|--------|-------------|
| `fake.assertLoggedIn()` | Assert a user is currently authenticated. |
| `fake.assertLoggedOut()` | Assert no user is currently authenticated. |
| `fake.assertLoginAttempted()` | Assert at least one login call was made. |
| `fake.assertLoginCount(int expected)` | Assert an exact number of login calls. |

```dart
test('controller logs in user on success', () async {
  final user = User()..fill({'id': 1, 'name': 'Alice'});
  final fake = Auth.fake();

  await Auth.login({'token': 'test-token'}, user);

  fake.assertLoggedIn();
  fake.assertLoginAttempted();
  fake.assertLoginCount(1);
});

test('controller logs out user', () async {
  final user = User()..fill({'id': 1, 'name': 'Alice'});
  final fake = Auth.fake(user: user);

  await Auth.logout();

  fake.assertLoggedOut();
});
```

### Resetting State

Call `fake.reset()` to clear the current user, token, and login attempt records without restoring the real driver:

```dart
fake.reset(); // Clears user, token, and login attempt history
```

<a name="cache-fake"></a>
## Cache.fake()

`Cache.fake()` replaces the real `CacheManager` with a `FakeCacheManager` backed by a plain `Map`. All operations are synchronous and in-memory. Every `put`, `get`, and `forget` call is recorded in `fake.recorded`.

**Signature:**

```dart
static FakeCacheManager fake()
```

### Basic Usage

```dart
test('controller caches user list', () async {
  final fake = Cache.fake();

  await Cache.put('users', ['Alice', 'Bob'], ttl: Duration(minutes: 5));

  expect(Cache.has('users'), isTrue);
  expect(Cache.get('users'), equals(['Alice', 'Bob']));
});
```

### Assertions

| Method | Description |
|--------|-------------|
| `fake.assertHas(String key)` | Assert that the key currently exists in the cache. |
| `fake.assertMissing(String key)` | Assert that the key does not exist in the cache. |
| `fake.assertPut(String key)` | Assert that the key was stored via `put` at least once. |

```dart
test('user list is cached after fetch', () async {
  final fake = Cache.fake();

  await Cache.put('users', ['Alice', 'Bob']);

  fake.assertHas('users');
  fake.assertPut('users');
});

test('cache is cleared after flush', () async {
  final fake = Cache.fake();

  await Cache.put('users', ['Alice']);
  await Cache.flush();

  fake.assertMissing('users');
});
```

### Recorded Operations

Access `fake.recorded` for a full chronological list of cache operations:

```dart
final fake = Cache.fake();

await Cache.put('a', 1);
await Cache.get('a');
await Cache.forget('a');

expect(fake.recorded[0].operation, 'put');
expect(fake.recorded[1].operation, 'get');
expect(fake.recorded[2].operation, 'forget');
```

Each entry is a `CacheRecord` record type: `({String operation, String key, dynamic value})`.

### Resetting State

Call `fake.reset()` to clear both the in-memory store and the recorded operations list:

```dart
fake.reset();
```

<a name="vault-fake"></a>
## Vault.fake()

`Vault.fake()` replaces the real `MagicVaultService` (backed by `flutter_secure_storage`) with a `FakeVaultService` that stores data in a plain `Map`. No platform channels are invoked.

**Signature:**

```dart
static FakeVaultService fake([Map<String, String> initialValues = const {}])
```

Pass `initialValues` to pre-seed the vault before the test body runs.

### Basic Usage

```dart
test('controller reads token from vault', () async {
  Vault.fake({'auth_token': 'seed-token'});

  final token = await Vault.get('auth_token');

  expect(token, 'seed-token');
});

test('controller writes token to vault', () async {
  final fake = Vault.fake();

  await Vault.put('auth_token', 'abc123');

  expect(await Vault.get('auth_token'), 'abc123');
});
```

### Assertions

| Method | Description |
|--------|-------------|
| `fake.assertWritten(String key)` | Assert that `key` was written via `put` at least once. |
| `fake.assertDeleted(String key)` | Assert that `key` was deleted via `delete` at least once. |
| `fake.assertContains(String key)` | Assert that `key` currently exists in the store. |
| `fake.assertMissing(String key)` | Assert that `key` does not currently exist in the store. |

```dart
test('logout clears auth token', () async {
  final fake = Vault.fake({'auth_token': 'abc123'});

  await Vault.delete('auth_token');

  fake.assertDeleted('auth_token');
  fake.assertMissing('auth_token');
});

test('login stores token in vault', () async {
  final fake = Vault.fake();

  await Vault.put('auth_token', 'new-token');

  fake.assertWritten('auth_token');
  fake.assertContains('auth_token');
});
```

### Recorded Operations

Access `fake.recorded` for a full list of vault operations:

```dart
final fake = Vault.fake();

await Vault.put('token', 'abc');
await Vault.get('token');
await Vault.delete('token');

expect(fake.recorded[0].operation, 'put');
expect(fake.recorded[1].operation, 'get');
expect(fake.recorded[2].operation, 'remove');
```

Each entry is a `VaultOperation` record type: `({String operation, String key})`.

### Resetting State

Call `fake.reset()` to clear the in-memory store and recorded operations:

```dart
fake.reset();
```

<a name="log-fake"></a>
## Log.fake()

`Log.fake()` replaces the real `LogManager` with a `FakeLogManager` that captures all log entries in memory instead of writing to the console.

**Signature:**

```dart
static FakeLogManager fake()
```

### Basic Usage

```dart
test('controller logs error on failure', () async {
  final fake = Log.fake();

  Log.error('Payment failed', {'order': 42});

  fake.assertLoggedError('Payment failed');
});
```

### Assertions

| Method | Description |
|--------|-------------|
| `fake.assertLogged(String level, String message)` | Assert at least one entry matches both level and message. |
| `fake.assertLoggedError(String message)` | Shorthand for `assertLogged('error', message)`. |
| `fake.assertNothingLogged([String? level])` | Assert no entries recorded. If `level` is given, assert no entries at that level. |
| `fake.assertLoggedCount(int expected)` | Assert an exact total number of entries recorded. |

```dart
test('no logs emitted during normal operation', () {
  final fake = Log.fake();

  doNormalWork();

  fake.assertNothingLogged();
});

test('exactly one error is logged', () async {
  final fake = Log.fake();

  Log.error('Something failed');

  fake.assertLoggedCount(1);
  fake.assertLoggedError('Something failed');
});

test('warning is logged at correct level', () {
  final fake = Log.fake();

  Log.warning('Rate limit approaching');

  fake.assertLogged('warning', 'Rate limit approaching');
  fake.assertNothingLogged('error'); // No errors logged
});
```

### Inspecting Entries

Access `fake.entries` for the full list of captured log entries:

```dart
final fake = Log.fake();

Log.info('User logged in', {'id': 1});
Log.error('Token expired');

expect(fake.entries.length, 2);
expect(fake.entries[0].level, 'info');
expect(fake.entries[0].message, 'User logged in');
expect(fake.entries[1].level, 'error');
```

Each entry is a `FakeLogEntry` record type: `({String level, String message, dynamic context})`.

### Resetting State

Call `fake.reset()` to clear all captured entries without restoring the real driver:

```dart
fake.reset();
```

<a name="full-example"></a>
## Full Example

A controller that integrates Auth, Cache, Vault, and Log, with tests covering all four fakes:

```dart
// lib/controllers/session_controller.dart
class SessionController extends MagicController {
  Future<void> login(String token, User user) async {
    await Auth.login({'token': token}, user);
    await Vault.put('auth_token', token);
    await Cache.put('current_user', user.toMap());
    Log.info('User logged in', {'id': user.id});
  }

  Future<void> logout() async {
    await Auth.logout();
    await Vault.delete('auth_token');
    await Cache.forget('current_user');
    Log.info('User logged out');
  }
}

// test/http/session_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

void main() {
  group('SessionController', () {
    late SessionController controller;
    late FakeAuthManager authFake;
    late FakeCacheManager cacheFake;
    late FakeVaultService vaultFake;
    late FakeLogManager logFake;

    setUp(() {
      MagicApp.reset();
      Magic.flush();

      controller = SessionController();
      authFake = Auth.fake();
      cacheFake = Cache.fake();
      vaultFake = Vault.fake();
      logFake = Log.fake();
    });

    tearDown(() {
      Auth.unfake();
      Cache.unfake();
      Vault.unfake();
      Log.unfake();
    });

    test('login authenticates user and stores credentials', () async {
      final user = User()..fill({'id': 1, 'name': 'Alice'});

      await controller.login('token-abc', user);

      authFake.assertLoggedIn();
      authFake.assertLoginCount(1);
      vaultFake.assertWritten('auth_token');
      vaultFake.assertContains('auth_token');
      cacheFake.assertHas('current_user');
      cacheFake.assertPut('current_user');
      logFake.assertLogged('info', 'User logged in');
    });

    test('logout clears all session state', () async {
      final user = User()..fill({'id': 1, 'name': 'Alice'});
      authFake = Auth.fake(user: user);
      vaultFake = Vault.fake({'auth_token': 'token-abc'});

      await controller.logout();

      authFake.assertLoggedOut();
      vaultFake.assertDeleted('auth_token');
      vaultFake.assertMissing('auth_token');
      cacheFake.assertMissing('current_user');
      logFake.assertLogged('info', 'User logged out');
    });
  });
}
```

<a name="unfaking"></a>
## Unfaking

Call `unfake()` in `tearDown` to remove the fake from the IoC container and restore the real service binding for subsequent tests:

```dart
tearDown(() {
  Auth.unfake();
  Cache.unfake();
  Vault.unfake();
  Log.unfake();
});
```

After `unfake()`, the next facade call resolves the original singleton binding as if `fake()` was never called. This is the recommended pattern when each test should start from a clean real-service state.

If you want to reuse the same fake across multiple tests in a group without restoring the real driver, call `fake.reset()` instead:

```dart
final logFake = Log.fake(); // Install once for the group

test('first', () {
  Log.error('a');
  logFake.assertLoggedCount(1);
  logFake.reset(); // Clear for next test — fake remains installed
});

test('second', () {
  Log.error('b');
  logFake.assertLoggedCount(1);
});
```

## See Also

- [HTTP Tests](http-tests.md) — `Http.fake()`, URL pattern stubs, request assertions
