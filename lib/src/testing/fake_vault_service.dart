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
    _store[key] = value;
    _recorded.add((operation: 'put', key: key));
  }

  @override
  Future<String?> get(String key) async {
    _recorded.add((operation: 'get', key: key));
    return _store[key];
  }

  @override
  Future<void> remove(String key) async {
    _store.remove(key);
    _recorded.add((operation: 'remove', key: key));
  }

  @override
  Future<void> flush() async {
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
  // Helpers
  // ---------------------------------------------------------------------------

  /// Clear the in-memory store and the recorded operations list.
  void reset() {
    _store.clear();
    _recorded.clear();
  }
}
