import '../security/magic_vault_service.dart';

/// A record of a vault operation for test assertions.
typedef VaultOperation = ({String operation, String key});

/// In-memory fake implementation of [MagicVaultService] for testing.
///
/// Replaces [FlutterSecureStorage] with a simple [Map] so tests run
/// without platform channels.
///
/// ## Usage
///
/// ```dart
/// final fake = Vault.fake({'token': 'abc123'});
/// await Vault.put('key', 'value');
/// fake.assertWritten('key');
/// fake.assertContains('key');
/// Vault.unfake();
/// ```
class FakeVaultService extends MagicVaultService {
  final Map<String, String> _store = {};
  final List<VaultOperation> _recorded = [];

  /// Error [get] throws instead of returning a value, or null to behave
  /// normally. Set via [throwOnGet], cleared via [reset].
  Object? _getError;

  /// Error [put] throws instead of storing a value, or null to behave
  /// normally. Set via [throwOnPut], cleared via [reset].
  Object? _putError;

  /// Error [remove] throws instead of deleting a value, or null to behave
  /// normally. Set via [throwOnRemove], cleared via [reset].
  Object? _removeError;

  /// Error [flush] throws instead of clearing the store, or null to behave
  /// normally. Set via [throwOnFlush], cleared via [reset].
  Object? _flushError;

  /// Creates a [FakeVaultService] with optional [initialValues].
  FakeVaultService([Map<String, String> initialValues = const {}])
    : super.forTesting() {
    _store.addAll(initialValues);
  }

  /// All recorded operations in the order they were performed.
  List<VaultOperation> get recorded => List.unmodifiable(_recorded);

  // ---------------------------------------------------------------------------
  // MagicVaultService overrides
  // ---------------------------------------------------------------------------

  @override
  Future<void> put(String key, String value) async {
    if (_putError != null) {
      throw _putError!;
    }
    _store[key] = value;
    _recorded.add((operation: 'put', key: key));
  }

  @override
  Future<String?> get(String key) async {
    if (_getError != null) {
      throw _getError!;
    }
    _recorded.add((operation: 'get', key: key));
    return _store[key];
  }

  @override
  Future<void> remove(String key) async {
    if (_removeError != null) {
      throw _removeError!;
    }
    _store.remove(key);
    _recorded.add((operation: 'remove', key: key));
  }

  @override
  Future<void> flush() async {
    if (_flushError != null) {
      throw _flushError!;
    }
    _store.clear();
    _recorded.add((operation: 'flush', key: ''));
  }

  // ---------------------------------------------------------------------------
  // Assertions
  // ---------------------------------------------------------------------------

  /// Assert that [key] was written (via [put]) at least once.
  void assertWritten(String key) {
    final wasWritten = _recorded.any(
      (r) => r.operation == 'put' && r.key == key,
    );
    if (!wasWritten) {
      throw AssertionError(
        'Expected vault key "$key" to have been written, but it was not.',
      );
    }
  }

  /// Assert that [key] was deleted (via [remove]) at least once.
  void assertDeleted(String key) {
    final wasDeleted = _recorded.any(
      (r) => r.operation == 'remove' && r.key == key,
    );
    if (!wasDeleted) {
      throw AssertionError(
        'Expected vault key "$key" to have been deleted, but it was not.',
      );
    }
  }

  /// Assert that [key] currently exists in the store.
  void assertContains(String key) {
    if (!_store.containsKey(key)) {
      throw AssertionError(
        'Expected vault to contain key "$key", but it was missing.',
      );
    }
  }

  /// Assert that [key] does not currently exist in the store.
  void assertMissing(String key) {
    if (_store.containsKey(key)) {
      throw AssertionError(
        'Expected vault key "$key" to be missing, but it was present.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Failure simulation
  // ---------------------------------------------------------------------------

  /// Makes [get] throw [error] instead of returning a value, until [reset]
  /// clears it. Defaults to a [MagicVaultException], the type
  /// [MagicVaultService.get] itself throws when the platform channel fails
  /// (`magic_vault_service.dart:48-54`), so a consumer's `catch` clause sees
  /// the shape it would see from a real keychain read failure.
  void throwOnGet([Object? error]) {
    _getError = error ?? MagicVaultException('Simulated vault get failure');
  }

  /// Makes [put] throw [error] instead of storing the value, until [reset]
  /// clears it. Defaults to a [MagicVaultException], for the same reason as
  /// [throwOnGet].
  void throwOnPut([Object? error]) {
    _putError = error ?? MagicVaultException('Simulated vault put failure');
  }

  /// Makes [remove] throw [error] instead of deleting the value, until
  /// [reset] clears it. Defaults to a [MagicVaultException], for the same
  /// reason as [throwOnGet].
  ///
  /// This is the hook a sign-out path needs. A consumer that deletes the
  /// stored credential first and clears its in-memory session afterwards
  /// has two branches through one keychain call, and the failing one is the
  /// branch that decides whether the user is told the secret is still on
  /// the device or is shown a sign-out that did nothing.
  ///
  /// The throw is armed for every key, so a test that needs one key to fail
  /// while its neighbours succeed still needs its own subclass; this
  /// repository's `test/auth/logout_partial_failure_test.dart` is that
  /// case. Recording the attempt before the throw would let a filter live
  /// here instead, and it would also make [assertWritten] pass for a [put]
  /// that threw, so the record stays a log of what happened rather than of
  /// what was tried.
  void throwOnRemove([Object? error]) {
    _removeError =
        error ?? MagicVaultException('Simulated vault remove failure');
  }

  /// Makes [flush] throw [error] instead of clearing the store, until
  /// [reset] clears it. Defaults to a [MagicVaultException], for the same
  /// reason as [throwOnGet].
  void throwOnFlush([Object? error]) {
    _flushError = error ?? MagicVaultException('Simulated vault flush failure');
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Clear the in-memory store, the recorded operations list, and every
  /// configured throw.
  void reset() {
    _store.clear();
    _recorded.clear();
    _getError = null;
    _putError = null;
    _removeError = null;
    _flushError = null;
  }
}
