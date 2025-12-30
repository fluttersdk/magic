# Secure Storage (Vault)

## Introduction

While the Cache system is great for storing temporary data, it is not suitable for sensitive information like authentication tokens, API keys, or biometric secrets.

Magic provides a `Vault` facade that interfaces with the device's hardware-backed secure storage:

- **iOS**: Keychain
- **Android**: EncryptedSharedPreferences (Jetpack Security)

Values stored in the Vault are encrypted by the operating system and persisted even if the app is closed or the device is restarted.

## Enabling Vault Support

By default, the Vault service provider is **not enabled**. You can enable it using the Magic CLI:

```bash
magic init:vault
```

> **Note**  
> When you run `magic init:auth` or `magic init --auth`, the Vault is **automatically enabled** since the authentication system requires it for secure token storage.

### Manual Setup

Alternatively, add the provider manually to your `config/app.dart`:

```dart
'providers': [
  (app) => VaultServiceProvider(app),
],
```

## Storing Items

```dart
await Vault.put('api_key', 'sk_live_123456');
```

> **Note**  
> The Vault is slower than the Cache. Only use it for small, sensitive pieces of data. For large JSON blobs, encrypt them using `Crypt` and store in the database.

## Retrieving Items

```dart
final token = await Vault.get('api_key');

if (token != null) {
  // Use the token
}
```

## Removing Items

```dart
// Remove single item
await Vault.delete('api_key');

// Wipe entire Vault (e.g., on logout)
await Vault.flush();
```
