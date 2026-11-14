import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../facades/log.dart';
import '../foundation/magic.dart';

/// Exception thrown when a Vault operation fails.
class MagicVaultException implements Exception {
  /// `errSecMissingEntitlement`: the macOS Security framework refused a data
  /// protection keychain operation because the app carries no
  /// `keychain-access-groups` entitlement, which an ad-hoc or unprofiled
  /// build cannot have.
  static const int missingEntitlementStatus = -34018;

  final String message;
  final dynamic originalError;

  MagicVaultException(this.message, [this.originalError]);

  /// The platform status behind this failure, or `null` when the wrapped
  /// error carries none.
  ///
  /// On macOS and iOS this is the `OSStatus` the Security framework
  /// returned (`flutter_secure_storage_darwin` puts it in
  /// `PlatformException.details`; the exception `code` is the same fixed
  /// string for every status, so it cannot tell two failures apart).
  int? get statusCode {
    if (originalError case PlatformException(details: final int status)) {
      return status;
    }

    return null;
  }

  /// Whether the keychain refused the operation for want of the
  /// `keychain-access-groups` entitlement ([missingEntitlementStatus]).
  bool get isMissingEntitlement => statusCode == missingEntitlementStatus;

  @override
  String toString() =>
      'MagicVaultException: $message ${originalError != null ? "($originalError)" : ""}';
}

/// The Magic Vault Service.
///
/// Provides a secure, hardware-backed storage for sensitive data using
/// [FlutterSecureStorage].
class MagicVaultService {
  /// An item the probe writes and removes again; never read by anyone.
  static const String _probeKey = 'magic.vault.keychain_probe';

  /// The macOS keychain this instance was told to use, or `null` to let it
  /// choose on first use (see the constructor).
  final bool? macOsUsesDataProtectionKeychain;

  FlutterSecureStorage? _storage;
  Future<FlutterSecureStorage>? _resolving;
  bool? _usesDataProtection;

  /// Creates the service.
  ///
  /// [macOsUsesDataProtectionKeychain] chooses which of macOS's two
  /// keychains the items live in. Left `null`, the service decides on its
  /// first operation: it tries the data protection keychain (what
  /// `flutter_secure_storage` itself defaults to, `macos_options.dart:24`)
  /// with one write and delete of a throwaway item, and falls back to the
  /// legacy login keychain, with one warning in the log, when the keychain
  /// answers `errSecMissingEntitlement` (-34018). That is the answer an
  /// ad-hoc build or one without a provisioning profile gets, because the
  /// data protection keychain requires the restricted
  /// `keychain-access-groups` entitlement and therefore an App ID.
  ///
  /// The probe has to write: on such a build a READ of the data protection
  /// keychain does not fail, it finds nothing (`errSecItemNotFound`,
  /// measured), exactly as it would for an item never stored.
  ///
  /// Pass a value to skip the probe and force one keychain. Do that when an
  /// app already holds items in one of them and must keep reading them:
  /// THERE IS NO MIGRATION BETWEEN THE TWO. An item written to one is not
  /// visible from the other, and a miss is indistinguishable from "never
  /// stored" to every caller, including any caller that keeps an encryption
  /// key here and generates a fresh one on a null read, which thereby makes
  /// everything previously encrypted with the old key permanently unreadable. The same split opens when an app that fell back
  /// to the legacy keychain is later signed with a profile: the probe then
  /// picks the data protection keychain and the old items are not there.
  ///
  /// `false` does not set `kSecUseDataProtectionKeychain` to false, it OMITS
  /// the key from the query entirely (`flutter_secure_storage_darwin`
  /// `FlutterSecureStorage.swift:227-231`, guarded by
  /// `params.usesDataProtectionKeychain`), which lands the item in the
  /// legacy login keychain, and that one needs no entitlement.
  MagicVaultService({this.macOsUsesDataProtectionKeychain});

  /// Named constructor for testing: skips [FlutterSecureStorage] initialisation.
  ///
  /// Use this as the `super` constructor in [FakeVaultService] so that the
  /// `_storage` field is never assigned and therefore never accessed.
  MagicVaultService.forTesting() : macOsUsesDataProtectionKeychain = null;

  /// The macOS keychain in use: the constructor's value when one was given,
  /// otherwise what the probe found.
  ///
  /// `null` until the first operation has resolved it, after a probe that
  /// failed for another reason (the next operation probes again), and on
  /// every platform other than macOS when no value was given.
  bool? get usesDataProtectionKeychain => _usesDataProtection;

  /// Store a value in the vault.
  Future<void> put(String key, String value) => _run(
    'Failed to write to vault',
    (storage) => storage.write(key: key, value: value),
  );

  /// Retrieve a value from the vault.
  Future<String?> get(String key) =>
      _run('Failed to read from vault', (storage) => storage.read(key: key));

  /// Remove a value from the vault.
  Future<void> remove(String key) => _run(
    'Failed to remove from vault',
    (storage) => storage.delete(key: key),
  );

  /// Flush all values from the vault.
  Future<void> flush() =>
      _run('Failed to flush vault', (storage) => storage.deleteAll());

  Future<T> _run<T>(
    String failure,
    Future<T> Function(FlutterSecureStorage storage) operation,
  ) async {
    final storage = await _ready();

    try {
      return await operation(storage);
    } on PlatformException catch (e) {
      throw MagicVaultException(_explain(failure, e), e);
    }
  }

  /// Names the cause when the keychain refused for want of an entitlement,
  /// which is otherwise a generic failure the caller cannot act on.
  String _explain(String failure, PlatformException error) {
    final bool onMacOs =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
    if (!onMacOs ||
        error.details != MagicVaultException.missingEntitlementStatus) {
      return failure;
    }

    return '$failure: the macOS data protection keychain needs the '
        'keychain-access-groups entitlement and a provisioning profile. Remove '
        'security.vault.macos_data_protection_keychain (or the '
        'macOsUsesDataProtectionKeychain argument) so the vault falls back to '
        'the legacy keychain on an unsigned build.';
  }

  /// The storage every operation goes through, resolved once.
  ///
  /// A failed resolution is not remembered: the next operation probes again.
  Future<FlutterSecureStorage> _ready() async {
    final ready = _storage;
    if (ready != null) {
      return ready;
    }

    final pending = _resolving ??= _resolve();

    try {
      return _storage = await pending;
    } finally {
      _resolving = null;
    }
  }

  Future<FlutterSecureStorage> _resolve() async {
    // 1. A value passed to the constructor is the caller's decision.
    final explicit = macOsUsesDataProtectionKeychain;
    if (explicit != null) {
      _usesDataProtection = explicit;

      return _build(dataProtection: explicit);
    }

    // 2. Only macOS has two keychains to choose between.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) {
      return _build(dataProtection: true);
    }

    // 3. Prefer the data protection keychain when this build may use it.
    final dataProtection = _build(dataProtection: true);
    if (await _acceptsItems(dataProtection)) {
      _usesDataProtection = true;

      return dataProtection;
    }

    // 4. Otherwise the legacy keychain, which needs no entitlement. The
    // warning is guarded because `Log` throws for an unbound `log`
    // (`application.dart:269-274`), which a service used before
    // `Magic.init` has booted would otherwise let escape in place of the
    // decision it is reporting.
    if (Magic.bound('log')) {
      Log.warning(
        'Vault: the macOS data protection keychain refused a write '
        '(errSecMissingEntitlement): this build has no keychain-access-groups '
        'entitlement. Using the legacy keychain instead; items stored in the '
        'other keychain are not visible from it.',
      );
    }
    _usesDataProtection = false;

    return _build(dataProtection: false);
  }

  /// Whether [storage] can hold an item, tried with one write and delete.
  ///
  /// Only `errSecMissingEntitlement` answers `false`. Any other failure (a
  /// locked keychain, say) says nothing about the entitlement, so it
  /// surfaces instead of silently choosing the legacy keychain.
  Future<bool> _acceptsItems(FlutterSecureStorage storage) async {
    try {
      await storage.write(key: _probeKey, value: 'probe');
    } on PlatformException catch (e) {
      final failure = MagicVaultException(
        'Failed to probe the macOS keychain',
        e,
      );
      if (failure.isMissingEntitlement) {
        return false;
      }

      throw failure;
    }

    try {
      await storage.delete(key: _probeKey);
    } on PlatformException catch (e) {
      throw MagicVaultException('Failed to remove the keychain probe', e);
    }

    return true;
  }

  FlutterSecureStorage _build({required bool dataProtection}) {
    return FlutterSecureStorage(
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
        usesDataProtectionKeychain: dataProtection,
      ),
    );
  }
}
