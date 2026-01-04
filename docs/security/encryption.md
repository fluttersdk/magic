# Security: Encryption

- [Introduction](#introduction)
- [Configuration](#configuration)
- [Using The Encrypter](#using-the-encrypter)
    - [Config-Based Encryption](#config-based-encryption)
    - [Device-Based Encryption](#device-based-encryption)
- [Managing Keys](#managing-keys)

<a name="introduction"></a>
## Introduction

Magic's encrypter provides a simple, convenient interface for encrypting and decrypting text. All encrypted values are signed using a message authentication code (MAC) so that their underlying value can not be modified or tampered with once encrypted.

Magic uses the AES-256-CBC cipher for all encryption operations.

<a name="configuration"></a>
## Configuration

Magic offers two encryption strategies:

1. **Config-Based**: Uses the global `APP_KEY` from your `.env` or configuration. Useful for server-side compatibility or shared keys.
2. **Device-Based**: Uses a unique, randomly generated key stored securely on the user's device via [Vault](/security/vault). This is recommended for storing sensitive user data locally.

<a name="using-the-encrypter"></a>
## Using The Encrypter

<a name="config-based-encryption"></a>
### Config-Based Encryption

To encrypt a value using your application's global key:

```dart
final secret = Crypt.encrypt('my-secret-value');
```

To decrypt a value:

```dart
try {
  final value = Crypt.decrypt(secret);
} on MagicDecryptException {
  // The value was invalid or tampered with
}
```

<a name="device-based-encryption"></a>
### Device-Based Encryption

For local data that should only be accessible on the current device, use device-based encryption. This keys is unique per installation.

```dart
// Encrypt
final secret = await Crypt.encryptWithDeviceKey('my-user-token');

// Decrypt
final value = await Crypt.decryptWithDeviceKey(secret);
```

> [!IMPORTANT]
> Device-based encryption is asynchronous (`Future`) because it retrieves the key from secure storage.

<a name="managing-keys"></a>
## Managing Keys

You can check if a device-specific key has already been generated:

```dart
if (await Crypt.hasDeviceKey()) {
  // Key exists
}
```

To generate a new device key (Warning: specific to the device encrypter):

```dart
// WARNING: This renders previously encrypted data unrecoverable!
await Crypt.generateDeviceKey();
```

To remove the key entirely:

```dart
await Crypt.clearDeviceKey();
```
