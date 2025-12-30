import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

/// Exception thrown when a Vault operation fails.
class MagicVaultException implements Exception {
  final String message;
  final dynamic originalError;

  MagicVaultException(this.message, [this.originalError]);

  @override
  String toString() =>
      'MagicVaultException: $message ${originalError != null ? "($originalError)" : ""}';
}

/// The Magic Vault Service.
///
/// Provides a secure, hardware-backed storage for sensitive data using
/// [FlutterSecureStorage].
class MagicVaultService {
  late final FlutterSecureStorage _storage;

  MagicVaultService() {
    _storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
          // encryptedSharedPreferences: true, // Deprecated in v10
          ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
      ),
    );
  }

  /// Store a value in the vault.
  Future<void> put(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } on PlatformException catch (e) {
      throw MagicVaultException('Failed to write to vault', e);
    }
  }

  /// Retrieve a value from the vault.
  Future<String?> get(String key) async {
    try {
      return await _storage.read(key: key);
    } on PlatformException catch (e) {
      throw MagicVaultException('Failed to read from vault', e);
    }
  }

  /// Remove a value from the vault.
  Future<void> remove(String key) async {
    try {
      await _storage.delete(key: key);
    } on PlatformException catch (e) {
      throw MagicVaultException('Failed to remove from vault', e);
    }
  }

  /// Flush all values from the vault.
  Future<void> flush() async {
    try {
      await _storage.deleteAll();
    } on PlatformException catch (e) {
      throw MagicVaultException('Failed to flush vault', e);
    }
  }
}
