import '../foundation/magic.dart';
import '../security/magic_vault_service.dart';

/// The Vault Facade.
///
/// Provides static access to the [MagicVaultService] for secure storage operations.
class Vault {
  /// The singleton accessor.
  static MagicVaultService get _service =>
      Magic.make<MagicVaultService>('vault');

  /// Store a value in the vault.
  ///
  /// [key] The key to store the value under.
  /// [value] The value to store.
  static Future<void> put(String key, String value) async {
    return _service.put(key, value);
  }

  /// Retrieve a value from the vault.
  ///
  /// Returns `null` if the key does not exist.
  static Future<String?> get(String key) async {
    return _service.get(key);
  }

  /// Remove a value from the vault.
  static Future<void> delete(String key) async {
    return _service.remove(key);
  }

  /// Flush all values from the vault.
  ///
  /// WARNING: This deletes ALL secure storage data for the app.
  static Future<void> flush() async {
    return _service.flush();
  }
}
