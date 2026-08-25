import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';

import 'exceptions.dart';

/// The Magic Encrypter Service.
///
/// A convenient interface for encrypting and decrypting text with AES-256-CBC.
///
/// ## What this does NOT give you
///
/// Ciphertexts produced here are **not authenticated**. There is no MAC, and
/// this is where Magic diverges from Laravel's `Encrypter`, which appends an
/// HMAC-SHA256 over the IV and the ciphertext and refuses a payload whose MAC
/// does not verify.
///
/// Two consequences to design around, rather than assume away:
///
/// - **CBC is malleable.** Someone who can modify a stored payload can flip
///   bits in the IV and flip the corresponding bits of the first plaintext
///   block, predictably. Decryption will succeed and hand back a value the
///   attacker chose part of.
/// - **A decryption failure is observable**, so a caller that reports it back
///   to whoever supplied the payload builds a padding oracle.
///
/// So: use this to keep a value opaque at rest on the device, and do not use
/// it as evidence that a value has not been tampered with. Anything whose
/// integrity matters (a token, an amount, an identity) has to be verified by
/// the server that issued it, which is the layer that can hold a secret this
/// one cannot.
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
      final Uint8List bytes;
      try {
        bytes = base64.decode(appKey.substring('base64:'.length));
      } on FormatException catch (e) {
        // base64.decode throws a terse low-level FormatException; rethrow with
        // an actionable message since every app key now flows through here.
        throw Exception(
          'App Key has a "base64:" prefix but the value is not valid base64 '
          '(${e.message}). Re-run `magic key:generate`.',
        );
      }
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
  /// The [payload] must be in the format `base64(iv):base64(value)`. A
  /// malformed payload, or one that does not decrypt under this key, throws
  /// [MagicDecryptException].
  ///
  /// There is no MAC check, so a payload that decrypts is NOT thereby proven
  /// untampered; see the class docs. Do not surface the failure to whoever
  /// supplied the payload, since distinguishable failures are what a padding
  /// oracle is built from.
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
