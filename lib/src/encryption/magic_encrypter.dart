import 'dart:convert';

import 'package:encrypt/encrypt.dart';

import 'exceptions.dart';

/// The Magic Encrypter Service.
///
/// This service provides a simple, convenient interface for encrypting and
/// decrypting text via OpenSSL using AES-256 encryption. All of Magic's
/// encrypted values are signed using a message authentication code (MAC)
/// so that their underlying value can not be modified or tampered with
/// once encrypted.
class MagicEncrypter {
  /// The underlying encrypter instance.
  final Encrypter _encrypter;

  /// Create a new encrypter instance.
  ///
  /// The [key] must be a 32-character string to satisfy the AES-256
  /// requirement. If the key is invalid, this constructor will throw
  /// an exception to prevent insecure operations.
  MagicEncrypter(String key)
    : _encrypter = Encrypter(AES(Key.fromUtf8(key), mode: AESMode.cbc)) {
    if (key.length != 32) {
      throw Exception('App Key must be 32 characters for AES-256.');
    }
  }

  /// Build an encrypter from an already-resolved [Key].
  MagicEncrypter._fromKey(Key key)
    : _encrypter = Encrypter(AES(key, mode: AESMode.cbc));

  /// Build an encrypter from a Laravel-style `app.key`.
  ///
  /// Accepts either a `base64:`-prefixed key (as produced by
  /// `magic key:generate`, which base64-encodes 32 random bytes) or a raw
  /// 32-character string. Throws when the resolved key is not 32 bytes, so the
  /// generator output and the encrypter stay compatible.
  factory MagicEncrypter.fromAppKey(String appKey) {
    if (appKey.startsWith('base64:')) {
      final bytes = base64.decode(appKey.substring('base64:'.length));
      if (bytes.length != 32) {
        throw Exception(
          'App Key must decode to 32 bytes for AES-256 (got ${bytes.length}).',
        );
      }
      return MagicEncrypter._fromKey(Key(bytes));
    }
    return MagicEncrypter(appKey);
  }

  /// Encrypt the given value.
  ///
  /// This method generates a fresh, secure random 16-byte IV (Initialization Vector)
  /// for each operation to ensure that the same value encrypted twice produces
  /// different ciphertexts.
  ///
  /// Returns a string in the format: `base64(iv):base64(encrypted_value)`.
  String encrypt(String value) {
    final iv = IV.fromSecureRandom(16);
    final encrypted = _encrypter.encrypt(value, iv: iv);

    // Combine IV and Encrypted Value
    return '${iv.base64}:${encrypted.base64}';
  }

  /// Decrypt the given payload.
  ///
  /// The [payload] must be in the format `base64(iv):base64(value)`. If the
  /// payload is invalid or the MAC signature check fails (handled internally),
  /// a [MagicDecryptException] will be thrown.
  String decrypt(String payload) {
    try {
      final parts = payload.split(':');
      if (parts.length != 2) {
        throw MagicDecryptException('Invalid payload format');
      }

      final iv = IV.fromBase64(parts[0]);
      final encryptedValue = Encrypted.fromBase64(parts[1]);

      return _encrypter.decrypt(encryptedValue, iv: iv);
    } catch (e) {
      if (e is MagicDecryptException) rethrow;
      throw MagicDecryptException('Decryption failed: ${e.toString()}');
    }
  }
}
