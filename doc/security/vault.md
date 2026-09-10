# Security: Vault

The `Vault` facade provides a simple interface for reading and writing sensitive data to the platform's native secure storage, with a fake implementation for testing.

- [Introduction](#introduction)
- [macOS: Which Keychain](#macos-which-keychain)
- [Storing Items](#storing-items)
- [Retrieving Items](#retrieving-items)
- [Removing Items](#removing-items)
- [Testing](#testing)

<a name="introduction"></a>
## Introduction

The `Vault` facade provides a simple interface for securely storing sensitive data on the device. It uses the platform's native secure storage mechanisms:
- **iOS**: Keychain
- **Android**: EncryptedSharedPreferences
- **macOS**: Keychain, the data protection one by default. See below; it is the one platform where you may have to choose.
- **Windows**: Windows Credential Locker

<a name="macos-which-keychain"></a>
## macOS: Which Keychain

macOS has two keychains and the vault can write to either. The default is the data protection keychain, which is `flutter_secure_storage`'s own default and what every existing build already uses.

The data protection keychain requires the `keychain-access-groups` entitlement. That entitlement is restricted, so the build has to be signed with an App ID rather than ad hoc, and on a build with no signing identity **every write fails** with `PlatformException(-34018, errSecMissingEntitlement)`. That is the whole reason the choice exists: a contributor with no certificate installed cannot store anything at all.

Point the vault at the legacy login keychain, which needs no entitlement, with one config key:

```dart
// lib/config/security.dart
final securityConfig = <String, dynamic>{
  'vault': <String, dynamic>{
    // Only consulted on macOS. Leave it out on a signed build.
    'macos_data_protection_keychain': false,
  },
};
```

Or, when you construct the service yourself:

```dart
app.singleton('vault', () => MagicVaultService(macOsUsesDataProtectionKeychain: false));
```

**There is no migration between the two keychains, in either direction.** An item written to one is invisible from the other, and every caller reads that as "never stored" rather than as an error. Two consequences, both silent:

- `Crypt.encryptWithDeviceKey` generates a **new** device key on a null read, so anything encrypted under the old one becomes permanently unreadable while the old key sits unreachable in the other keychain.
- `BaseGuard` loses the stored token the same way, which logs the user out.

So flip this once, before the app stores anything, and not as a way out of a `-34018` on a build that has already been storing secrets. To move existing items, read them under the old setting, flip, and write them back.

The vault also passes `first_unlock_this_device` accessibility on macOS: readable after the first unlock, so a refresh on launch works before anyone has touched the machine, and never restored onto a different Mac from a backup. That attribute belongs to the data protection keychain, so it has no effect once the key above is `false`.

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
| `fake.reset()` | Clears the in-memory store, the operation history, and any configured throw below. |

Call `Vault.unfake()` in `tearDown()` to restore the real vault binding after each test.

### Simulating a vault failure

`fake.throwOnGet([error])` and `fake.throwOnPut([error])` make the fake throw instead of completing normally, for testing a vault-failure branch a consumer's own code has for `Vault.get` or `Vault.put`. Each defaults to a `MagicVaultException` and only affects its own operation:

```dart
test('a get failure surfaces as MagicVaultException', () async {
  final fake = Vault.fake();
  fake.throwOnGet();

  await expectLater(Vault.get('token'), throwsA(isA<MagicVaultException>()));
});
```

Pass a custom error to `throwOnGet`/`throwOnPut` to assert on a specific message. `fake.reset()` clears a configured throw along with the store.
