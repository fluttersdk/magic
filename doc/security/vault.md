# Security: Vault

The `Vault` facade provides a simple interface for reading and writing sensitive data to the platform's native secure storage, with a fake implementation for testing.

- [Introduction](#introduction)
- [Storing Items](#storing-items)
- [Retrieving Items](#retrieving-items)
- [Removing Items](#removing-items)
- [Testing](#testing)

<a name="introduction"></a>
## Introduction

The `Vault` facade provides a simple interface for securely storing sensitive data on the device. It uses the platform's native secure storage mechanisms:
- **iOS**: Keychain
- **Android**: EncryptedSharedPreferences
- **macOS**: Keychain
- **Windows**: Windows Credential Locker

<a name="storing-items"></a>
## Storing Items

To store a value in the vault:

```dart
await Vault.put('api_token', 'super-secret-token');
```

<a name="retrieving-items"></a>
## Retrieving Items

To retrieve a value:

```dart
final token = await Vault.get('api_token');

if (token != null) {
  // Use token...
}
```

<a name="removing-items"></a>
## Removing Items

To remove a specific item:

```dart
await Vault.delete('api_token');
```

To wipe all data from the vault (use with caution):

```dart
await Vault.flush();
```

<a name="testing"></a>
## Testing

Replace the real vault service with a `FakeVaultService` using `Vault.fake()`. The fake stores values in memory so tests run without platform channels.

```dart
import 'package:magic/testing.dart';

void main() {
  tearDown(() => Vault.unfake());

  test('stores and reads a token', () async {
    final fake = Vault.fake({'existing': 'seed'});

    await Vault.put('token', 'abc123');

    fake.assertWritten('token');
    fake.assertContains('token');
    expect(await Vault.get('token'), 'abc123');
  });

  test('delete removes the key', () async {
    final fake = Vault.fake({'token': 'abc123'});

    await Vault.delete('token');

    fake.assertDeleted('token');
    fake.assertMissing('token');
  });
}
```

Pass an optional map of initial values to `Vault.fake()` to pre-seed the store.

### FakeVaultService Assertions

| Method | Description |
|--------|-------------|
| `fake.assertWritten(key)` | Fails if `Vault.put(key, ...)` was never called. |
| `fake.assertDeleted(key)` | Fails if `Vault.delete(key)` was never called. |
| `fake.assertContains(key)` | Fails if `key` is not currently in the store. |
| `fake.assertMissing(key)` | Fails if `key` is currently in the store. |
| `fake.reset()` | Clears the in-memory store and operation history. |

Call `Vault.unfake()` in `tearDown()` to restore the real vault binding after each test.
