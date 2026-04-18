/// In-memory session store backing the [Session] facade.
///
/// Holds two buckets: `_current` (readable by the next view) and `_next`
/// (being collected by the active handler). [tick] promotes `_next` into
/// `_current`, wiping what was there. The typical cycle is:
///
/// 1. Controller fails validation, calls `Session.flash(data)` + `flashErrors(errors)`.
/// 2. Navigation back to the form triggers a [tick], promoting the bucket.
/// 3. Form reads `old('email')` and `error('email')` to repopulate.
/// 4. Next navigation [tick]s again, clearing the flash.
class SessionStore {
  SessionStore();

  Map<String, dynamic> _current = const <String, dynamic>{};
  Map<String, List<String>> _currentErrors = const <String, List<String>>{};

  Map<String, dynamic> _next = <String, dynamic>{};
  Map<String, List<String>> _nextErrors = <String, List<String>>{};

  /// Flash input values. Read on the next view frame via [old].
  void flash(Map<String, dynamic> input) {
    _next.addAll(input);
  }

  /// Flash validation errors. Read on the next view frame via [error].
  void flashErrors(Map<String, List<String>> errors) {
    _nextErrors.addAll(errors);
  }

  /// Read a flashed input value.
  String? old(String field, [String? fallback]) {
    final value = _current[field];
    if (value == null) return fallback;
    return value.toString();
  }

  /// Read the raw flashed value (non-stringified).
  dynamic oldRaw(String field) => _current[field];

  /// Read the first flashed error message for a field.
  String? error(String field) {
    final list = _currentErrors[field];
    if (list == null || list.isEmpty) return null;
    return list.first;
  }

  /// Read all flashed errors for a field (Laravel: `$errors->get('field')`).
  List<String> errors(String field) =>
      List.unmodifiable(_currentErrors[field] ?? const <String>[]);

  /// Whether any flashed input or errors are currently visible.
  bool get hasFlash => _current.isNotEmpty || _currentErrors.isNotEmpty;

  /// Whether a field has a flashed error.
  bool hasError(String field) => _currentErrors.containsKey(field);

  /// Advance the flash bucket: promote `_next` to `_current`, clear `_next`.
  /// Call on every navigation to make flashed data survive exactly one hop.
  void tick() {
    _current = _next;
    _currentErrors = _nextErrors;
    _next = <String, dynamic>{};
    _nextErrors = <String, List<String>>{};
  }

  /// Wipe both buckets. Intended for tests.
  void reset() {
    _current = const <String, dynamic>{};
    _currentErrors = const <String, List<String>>{};
    _next = <String, dynamic>{};
    _nextErrors = <String, List<String>>{};
  }
}
