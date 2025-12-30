import 'dart:math';

import '../foundation/magic.dart';
import '../encryption/magic_encrypter.dart';
import 'vault.dart';

/// The Encryption Facade.
///
/// The `Crypt` facade provides a simple way to encrypt and decrypt strings
/// using the AES-256-CBC cipher. It proxies calls to the underlying
/// [MagicEncrypter] service resolved from the container.
///
/// ## Config-Based Encryption
///
/// Uses the `app.key` from your configuration:
/// ```dart
/// final secret = Crypt.encrypt('my-secret-value');
/// final value = Crypt.decrypt(secret);
/// ```
///
/// ## Device-Based Encryption
///
/// Uses a device-specific key stored securely in Vault:
/// ```dart
/// final secret = await Crypt.encryptWithDeviceKey('my-secret-value');
/// final value = await Crypt.decryptWithDeviceKey(secret);
/// ```
class Crypt {
  /// The Vault key for storing the device encryption key.
  static const String _deviceKeyName = 'magic:device_encryption_key';

  /// Cached device encrypter instance.
  static MagicEncrypter? _deviceEncrypter;

  /// The singleton accessor for the config-based encrypter.
  static MagicEncrypter get _service => Magic.make<MagicEncrypter>('encrypter');

  // ---------------------------------------------------------------------------
  // Config-Based Encryption (uses app.key)
  // ---------------------------------------------------------------------------

  /// Encrypt a value using the config-based app key.
  ///
  /// Example:
  /// ```dart
  /// final secret = Crypt.encrypt('my-secret-value');
  /// ```
  static String encrypt(String value) {
    return _service.encrypt(value);
  }

  /// Decrypt a value using the config-based app key.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final value = Crypt.decrypt(encryptedPayload);
  /// } on MagicDecryptException {
  ///   // Handle error...
  /// }
  /// ```
  static String decrypt(String value) {
    return _service.decrypt(value);
  }

  // ---------------------------------------------------------------------------
  // Device-Based Encryption (uses Vault-stored key)
  // ---------------------------------------------------------------------------

  /// Encrypt a value using the device-specific key.
  ///
  /// The device key is automatically generated on first use and stored
  /// securely in Vault. This key is unique to each device installation.
  ///
  /// Example:
  /// ```dart
  /// final secret = await Crypt.encryptWithDeviceKey('sensitive-data');
  /// ```
  static Future<String> encryptWithDeviceKey(String value) async {
    final encrypter = await _getDeviceEncrypter();
    return encrypter.encrypt(value);
  }

  /// Decrypt a value using the device-specific key.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final value = await Crypt.decryptWithDeviceKey(encryptedPayload);
  /// } on MagicDecryptException {
  ///   // Handle error...
  /// }
  /// ```
  static Future<String> decryptWithDeviceKey(String value) async {
    final encrypter = await _getDeviceEncrypter();
    return encrypter.decrypt(value);
  }

  /// Check if a device key exists.
  ///
  /// Returns `true` if a device encryption key has been generated.
  static Future<bool> hasDeviceKey() async {
    final key = await Vault.get(_deviceKeyName);
    return key != null;
  }

  /// Generate a new device key.
  ///
  /// This will replace any existing device key. Data encrypted with the
  /// old key will not be recoverable.
  ///
  /// > **Warning**
  /// > Calling this will invalidate all previously encrypted device data.
  static Future<void> generateDeviceKey() async {
    final newKey = _generateRandomKey();
    await Vault.put(_deviceKeyName, newKey);
    _deviceEncrypter = MagicEncrypter(newKey);
  }

  /// Clear the device key.
  ///
  /// Removes the device encryption key from Vault. Data encrypted with
  /// this key will no longer be recoverable.
  static Future<void> clearDeviceKey() async {
    await Vault.delete(_deviceKeyName);
    _deviceEncrypter = null;
  }

  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------

  /// Get or create the device encrypter.
  static Future<MagicEncrypter> _getDeviceEncrypter() async {
    if (_deviceEncrypter != null) return _deviceEncrypter!;

    var key = await Vault.get(_deviceKeyName);

    // Generate key on first use
    if (key == null) {
      key = _generateRandomKey();
      await Vault.put(_deviceKeyName, key);
    }

    _deviceEncrypter = MagicEncrypter(key);
    return _deviceEncrypter!;
  }

  /// Generate a cryptographically secure 32-character random key.
  static String _generateRandomKey() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
