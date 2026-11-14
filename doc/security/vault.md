# Security: Vault

The `Vault` facade provides a simple interface for reading and writing sensitive data to the platform's native secure storage, with a fake implementation for testing.

- [Introduction](#introduction)
- [macOS: Which Keychain](#macos-which-keychain)
- [Storing Items](#storing-items)
- [Retrieving Items](#retrieving-items)
- [Removing Items](#removing-items)
- [Testing](#testing)
- [Encrypting Values](#encrypting-values)

<a name="introduction"></a>
## Introduction

The `Vault` facade provides a simple interface for securely storing sensitive data on the device. It uses the platform's native secure storage mechanisms:
- **iOS**: Keychain
- **Android**: EncryptedSharedPreferences
- **macOS**: Keychain, the data protection one wherever the build may use it and the legacy login keychain where it may not. The vault chooses on first use; see below.
- **Windows**: Windows Credential Locker

<a name="macos-which-keychain"></a>
## macOS: Which Keychain

macOS has two keychains and the vault writes to one of them. The data protection keychain is `flutter_secure_storage`'s own default and what every signed build already uses. The legacy login keychain needs no entitlement.

The data protection keychain requires the `keychain-access-groups` entitlement. That entitlement is restricted, so the build has to be signed with an App ID and carry a provisioning profile. On an ad-hoc build, or one signed without a profile (a debug build from a machine with no certificate, or a release build you made to try locally), **every write to it fails** with `errSecMissingEntitlement` (-34018).

So the vault probes, and you configure nothing. On its first operation it writes and deletes a throwaway item in the data protection keychain:

- If that works, the vault uses the data protection keychain.
- If the keychain answers -34018, the vault uses the legacy keychain instead and logs one warning.
- Any other failure of the probe (a locked keychain, say) says nothing about the entitlement. It is raised as a `MagicVaultException` and the next operation probes again.

The probe writes because a read cannot tell the two cases apart: on a build with no entitlement a read of the data protection keychain does not fail, it finds nothing, which is exactly what an item never stored looks like.

Once the first operation has run, the choice is readable:

```dart
final vault = Magic.make<MagicVaultService>('vault');

vault.usesDataProtectionKeychain; // true, false, or null before the first operation
```

A failed write names its cause. `MagicVaultException.statusCode` carries the `OSStatus` the keychain returned, and `isMissingEntitlement` is true for -34018, so a screen can say "this build cannot store a sign-in" instead of a generic failure.

To skip the probe and force one keychain, use one config key:

```dart
// lib/config/security.dart
final securityConfig = <String, dynamic>{
  // The domain key, like every config map in this framework: `appConfig` is
  // `{'app': {...}}` and `defaultCacheConfig` is `{'cache': {...}}`.
  // `MagicApp.init` merges each entry verbatim and derives no name from
  // anywhere, so a map without it lands at the top level and the provider,
  // which reads `security.vault.macos_data_protection_keychain`, never sees it.
  'security': <String, dynamic>{
    'vault': <String, dynamic>{
      // Only consulted on macOS. Leave it out to let the vault probe. A bare
      // `false` literal, not the string `'false'`: `Config.get<bool>` returns
      // its default on a type mismatch as well as on a missing key, so a
      // quoted value reads exactly like no value at all.
      'macos_data_protection_keychain': false,
    },
  },
};
```

The file is not loaded by being there. Hand it to `Magic.init` like every other config domain, or the key is absent and the vault probes with nothing to say the setting was ignored:

```dart
await Magic.init(
  configFactories: [
    () => appConfig,
    () => securityConfig,
  ],
);
```

Or, when you construct the service yourself:

```dart
app.singleton('vault', () => MagicVaultService(macOsUsesDataProtectionKeychain: false));
```

**There is no migration between the two keychains, in either direction.** An item written to one is invisible from the other, and every caller reads that as "never stored" rather than as an error. Two consequences, both silent:

- The `magic_encryption` plugin's device-key encryption generates a **new** device key on a null read, so anything encrypted under the old one becomes permanently unreadable while the old key sits unreachable in the other keychain.
- `BaseGuard` loses the stored token the same way, which logs the user out.

The probe can open the same split without anyone changing a setting. An app that fell back to the legacy keychain and is later signed with a provisioning profile picks the data protection keychain, and the items it stored before are not there. Pin `false` for an app that already holds items in the legacy keychain and must keep reading them, and move them across deliberately: read them under the old setting, switch, and write them back.

Two more consequences of the fallback:

- A release build with no provisioning profile now stores in the legacy keychain, with one warning in the log, where it used to fail every write. If that is not what you ship, give the build its profile, or set `macos_data_protection_keychain` to `true` so that a missing entitlement fails loudly.
- The legacy keychain ties an item's access rule to the code signature that wrote it. An ad-hoc signature differs on every build, so after a rebuild each stored item can raise a system keychain prompt on the next launch, and the app waits behind it until someone answers. Sign local builds with a stable identity (an Apple Development certificate) and rebuilds read their items without a prompt.

The vault also passes `first_unlock_this_device` accessibility on macOS: readable after the first unlock, so a refresh on launch works before anyone has touched the machine, and never restored onto a different Mac from a backup. That attribute belongs to the data protection keychain, so it has no effect on the legacy one.

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

<a name="encrypting-values"></a>
## Encrypting Values

AES-256-CBC encryption of strings, with a config-based key or a per-device key held in the vault, moved out of core into the `magic_encryption` plugin (the `Crypt` facade, `EncryptionServiceProvider` and `key:generate`). Install it with `flutter pub add magic_encryption`, then `dart run magic:dowel plugin:install magic_encryption`. Ciphertext written by earlier core versions stays readable.
