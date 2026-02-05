# Encryption

- [Introduction](#introduction)
- [Configuration](#configuration)
- [Using The Encrypter](#using-the-encrypter)
- [Vault (Secure Storage)](#vault-secure-storage)

<a name="introduction"></a>
## Introduction

Magic provides encryption services for securing sensitive data. The `Crypt` facade provides easy-to-use encryption and decryption methods, while the `Vault` facade provides secure storage using the platform's native secure storage (Keychain on iOS, Keystore on Android).

<a name="configuration"></a>
## Configuration

### Application Key

Magic's encrypter uses the application key defined in your `.env` file:

```env
APP_KEY=base64:your-32-character-random-key-here
```

Generate a new key using the CLI:

```bash
magic key:generate
```

> [!WARNING]
> Never commit your `APP_KEY` to version control. Always use environment variables.

<a name="using-the-encrypter"></a>
## Using The Encrypter

### Encrypting Values

```dart
final encrypted = Crypt.encrypt('my secret data');
// Returns encrypted string
```

### Decrypting Values

```dart
final decrypted = Crypt.decrypt(encrypted);
// Returns: 'my secret data'
```

### Encrypting Objects

You can encrypt any JSON-serializable data:

```dart
final encrypted = Crypt.encrypt({
  'user_id': 1,
  'permissions': ['read', 'write'],
  'expires': Carbon.now().addHours(1).toIso8601String(),
});

final data = Crypt.decrypt(encrypted);
// Returns the original Map
```

### Error Handling

```dart
try {
  final decrypted = Crypt.decrypt(invalidString);
} catch (e) {
  // Handle decryption failure
  print('Failed to decrypt: $e');
}
```

<a name="vault-secure-storage"></a>
## Vault (Secure Storage)

The `Vault` facade provides secure storage using the platform's native secure storage mechanisms:

- **iOS**: Keychain
- **Android**: Keystore / EncryptedSharedPreferences
- **Web**: Encrypted localStorage (less secure)

### Storing Values

```dart
await Vault.put('api_token', 'secret-token-value');
await Vault.put('refresh_token', 'refresh-token-value');
```

### Retrieving Values

```dart
final token = await Vault.get('api_token');

if (token != null) {
  // Use the token
}
```

### Checking Existence

```dart
if (await Vault.has('api_token')) {
  // Token exists
}
```

### Deleting Values

```dart
await Vault.delete('api_token');
```

### Clearing All Values

```dart
await Vault.deleteAll();
```

### Use Cases

**Authentication Tokens:**

```dart
class AuthService {
  Future<void> storeTokens(String token, String refreshToken) async {
    await Vault.put('auth_token', token);
    await Vault.put('refresh_token', refreshToken);
  }

  Future<String?> getToken() async {
    return await Vault.get('auth_token');
  }

  Future<void> clearTokens() async {
    await Vault.delete('auth_token');
    await Vault.delete('refresh_token');
  }
}
```

**Sensitive User Data:**

```dart
// Store sensitive settings
await Vault.put('pin_code', hashedPin);
await Vault.put('biometric_key', biometricData);

// API keys
await Vault.put('stripe_key', stripePublishableKey);
```

> [!IMPORTANT]
> Always use `Vault` for sensitive data like tokens, API keys, and credentials. Never store sensitive data in `SharedPreferences` or `Cache`.

## Encryption vs Vault

| Feature | Crypt | Vault |
|---------|-------|-------|
| Use Case | Encrypt data for transmission | Store secrets locally |
| Persistence | None (just transforms data) | Persistent secure storage |
| Platform | Cross-platform | Platform-specific secure storage |
| Example | Encrypt payload before API call | Store auth tokens |
