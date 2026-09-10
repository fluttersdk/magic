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
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      // `usesDataProtectionKeychain: false` does not set the underlying
      // `kSecUseDataProtectionKeychain` flag to false: it OMITS the key from
      // the query entirely (flutter_secure_storage_darwin
      // FlutterSecureStorage.swift:227-231, guarded by
      // `params.usesDataProtectionKeychain`), so the item is written to the
      // legacy login keychain instead. That keychain needs no
      // `keychain-access-groups` entitlement, which is what makes it usable
      // from an unsigned or ad-hoc macOS build: the data protection keychain
      // returns `errSecMissingEntitlement` (-34018) without one, measured on
      // this app's own build.
      //
      // The cost: there is no migration between the two keychains. A
      // consumer that starts unsigned, stores a secret, then gains a
      // signing identity and rebuilds with the default `true` reads from
      // the data protection keychain and finds nothing, silently, because
      // the old item is still sitting in the legacy keychain under the same
      // key. `first_unlock_this_device` (rather than the default
      // `first_unlock`) keeps the item device-bound, matching the intent of
      // a credential that should not roam via iCloud Keychain sync.
      mOptions: MacOsOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
        usesDataProtectionKeychain: false,
      ),
    );
  }

  /// Named constructor for testing — skips [FlutterSecureStorage] initialisation.
  ///
  /// Use this as the `super` constructor in [FakeVaultService] so that the
  /// `late final _storage` field is never assigned and therefore never accessed.
  MagicVaultService.forTesting();

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
