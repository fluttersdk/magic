# Security: Vault

- [Introduction](#introduction)
- [Storing Items](#storing-items)
- [Retrieving Items](#retrieving-items)
- [Removing Items](#removing-items)

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
