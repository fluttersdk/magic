# Encryption

## Introduction

Magic's encryption services provide a simple, convenient interface for encrypting and decrypting text via AES-256 encryption. All encrypted values are signed using a message authentication code (MAC) so that their underlying value cannot be modified or tampered with once encrypted.

Magic supports two encryption modes:
- **Config-Based**: Uses the `app.key` from configuration (shared across all devices)
- **Device-Based**: Uses a device-specific key stored in Vault (unique per device)

## Configuration

Before using Magic's config-based encrypter, you must set an `app.key` option in your configuration. Use the `key:generate` command to generate a secure key:

```bash
magic key:generate
```

> **Warning**  
> If you do not configure this value, config-based encrypted values will be insecure.

## Config-Based Encryption

Uses the `app.key` from your configuration. Data encrypted with this key can be decrypted on any device that has the same key.

### Encrypting A Value

```dart
final encrypted = Crypt.encrypt('Sensitive Data');
```

### Decrypting A Value

```dart
try {
  final decrypted = Crypt.decrypt(encryptedValue);
} on MagicDecryptException catch (e) {
  // Handle invalid data
}
```

## Device-Based Encryption

Uses a device-specific key stored securely in Vault. The key is automatically generated on first use and persists on the device. This is ideal for encrypting data that should only be readable on this specific device.

> **Note**  
> Device-based encryption requires Vault to be enabled. See [Vault documentation](vault.md) for setup.

### Encrypting With Device Key

```dart
final encrypted = await Crypt.encryptWithDeviceKey('Sensitive Data');
```

### Decrypting With Device Key

```dart
try {
  final decrypted = await Crypt.decryptWithDeviceKey(encryptedValue);
} on MagicDecryptException catch (e) {
  // Handle invalid data
}
```

### Key Management

Check if a device key exists:

```dart
if (await Crypt.hasDeviceKey()) {
  // Device key is ready
}
```

Force regenerate the device key (invalidates all previously encrypted data):

```dart
await Crypt.generateDeviceKey();
```

Clear the device key (e.g., on logout or data reset):

```dart
await Crypt.clearDeviceKey();
```

> **Warning**  
> Calling `generateDeviceKey()` or `clearDeviceKey()` will make any data encrypted with the previous key unrecoverable.

## When To Use Each

| Use Case | Encryption Type |
|----------|-----------------|
| Data synced across devices | Config-Based (`Crypt.encrypt`) |
| Local-only sensitive data | Device-Based (`Crypt.encryptWithDeviceKey`) |
| Offline-first apps | Device-Based |
| Shared configuration values | Config-Based |
