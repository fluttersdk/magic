/// A single resolved ability check outcome, cached by [GateManager].
///
/// [GateResult] is the snapshot that [GateManager.lastResult] returns. It
/// records what was asked (`ability`), what was answered (`allowed`), the
/// runtime type of the argument that was passed to the check (or `null`
/// when no argument was supplied), and when the check ran. The class is
/// intentionally a thin value-bag with no behaviour — the cache layer
/// owns retention and eviction.
///
/// The dusk integration's `magicGateResultEnricher` reads this through
/// `Gate.manager.lastResult(...)` to surface the most recent gate decision
/// in the snapshot YAML.
///
/// ## Usage
///
/// ```dart
/// final result = Gate.manager.lastResult('monitors.update');
/// if (result != null && result.allowed) {
///   // The most recent check for this ability passed.
/// }
/// ```
final class GateResult {
  /// The ability name that was checked (e.g. `'monitors.update'`).
  final String ability;

  /// Whether the check resolved as allowed.
  final bool allowed;

  /// The runtime [Type] of the argument passed to the check, or `null`
  /// when the check ran without an argument.
  ///
  /// Stored as a [Type] rather than the argument itself so the cache
  /// never retains references to user-owned objects.
  final Type? argumentType;

  /// The wall-clock instant at which the check was recorded.
  final DateTime checkedAt;

  /// Create a result snapshot.
  const GateResult({
    required this.ability,
    required this.allowed,
    this.argumentType,
    required this.checkedAt,
  });
}
