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

  /// Which macOS keychain this instance reads and writes, as resolved at
  /// construction. Readable so a consumer can assert what its configuration
  /// produced, since the choice is invisible in the behaviour of every
  /// operation until an item goes missing.
  final bool macOsUsesDataProtectionKeychain;

  /// Creates the service.
  ///
  /// [macOsUsesDataProtectionKeychain] chooses which of macOS's two
  /// keychains the items live in, and it defaults to `true`, which is what
  /// `flutter_secure_storage` itself defaults to
  /// (`macos_options.dart:24`). Leave it alone unless you know you need the
  /// other one: THERE IS NO MIGRATION BETWEEN THE TWO. An item written to
  /// one is not visible from the other, and a miss is indistinguishable
  /// from "never stored" to every caller, including
  /// `Crypt.encryptWithDeviceKey`, which generates a fresh device key on a
  /// null read (`crypt.dart:141-147`) and thereby makes everything
  /// previously encrypted with the old one permanently unreadable.
  ///
  /// Pass `false` when the build has no signing identity. The data
  /// protection keychain requires the restricted `keychain-access-groups`
  /// entitlement, and therefore an App ID, so every write from an unsigned
  /// or ad-hoc macOS build fails with `errSecMissingEntitlement` (-34018);
  /// measured on a consumer app's own build. `false` does not set
  /// `kSecUseDataProtectionKeychain` to false, it OMITS the key from the
  /// query entirely (`flutter_secure_storage_darwin`
  /// `FlutterSecureStorage.swift:227-231`, guarded by
  /// `params.usesDataProtectionKeychain`), which lands the item in the
  /// legacy login keychain, and that one needs no entitlement.
  MagicVaultService({this.macOsUsesDataProtectionKeychain = true}) {
    _storage = FlutterSecureStorage(
      aOptions: const AndroidOptions(
        // encryptedSharedPreferences: true, // Deprecated in v10
      ),
      iOptions: const IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
      ),
      // `first_unlock_this_device` rather than the package default
      // `unlocked` (`apple_options.dart:72`), for the same reason iOS
      // passes `first_unlock`: a read that happens while the screen is
      // locked, such as a refresh on launch before anyone has touched the
      // machine, succeeds under `first_unlock` and fails under `unlocked`.
      // The `ThisDeviceOnly` half means the item does not come back from a
      // backup on a new Mac, which is the right trade for a secret the user
      // can re-enter.
      //
      // It only bites on the data protection path. `kSecAttrAccessible` is
      // a data protection keychain attribute, so once the key above is
      // omitted the class is close to inert; iCloud Keychain roaming is
      // governed by `kSecAttrSynchronizable`, which is a separate option
      // this service does not pass.
      mOptions: MacOsOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
        usesDataProtectionKeychain: macOsUsesDataProtectionKeychain,
      ),
    );
  }

  /// Named constructor for testing — skips [FlutterSecureStorage] initialisation.
  ///
  /// Use this as the `super` constructor in [FakeVaultService] so that the
  /// `late final _storage` field is never assigned and therefore never accessed.
  MagicVaultService.forTesting() : macOsUsesDataProtectionKeychain = true;

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
