/// A stateless, single-purpose write unit (Fortify's `Actions\*`).
///
/// Subclass with the input and output types the write needs:
///
/// ```dart
/// class PauseMonitor extends MagicAction<String, void> {
///   const PauseMonitor();
///
///   @override
///   Future<void> handle(String monitorId) async {
///     final monitor = await Monitor.find(monitorId);
///     if (monitor == null) {
///       throw ValidationException({'id': 'Monitor not found.'});
///     }
///     monitor.status = 'paused';
///     await monitor.save();
///   }
/// }
/// ```
///
/// Resolve through [resolve] rather than constructing directly, so a test
/// can swap the implementation via [bind] without the call site changing
/// (mirrors Fortify's `Fortify::updateUserPasswordsUsing`):
///
/// ```dart
/// await MagicAction.resolve(PauseMonitor.new).handle(monitorId);
/// ```
///
/// An action throws on failure rather than answering a bool: a
/// [ValidationException] for a 422 from the backend or a failed client rule,
/// any other exception for a transport or unexpected failure.
/// [RunsActions.runAction] is the standard caller and already knows what to
/// do with both.
abstract class MagicAction<I, O> {
  const MagicAction();

  /// Runs this action against [input]. Throws on failure; see the class doc.
  Future<O> handle(I input);

  /// Overrides bound by concrete action type, keyed by that type.
  static final Map<Type, MagicAction Function()> _bindings = {};

  /// Registers [factory] as the implementation [resolve] returns for [A].
  ///
  /// A test binds a fake in `setUp` and calls [flush] in `tearDown`; nothing
  /// else needs to know the swap happened.
  ///
  /// [A] must be given explicitly: `MagicAction.bind<PauseMonitor>(() =>
  /// FakePauseMonitor())`. Left off, Dart infers [A] from the closure's
  /// RETURN type (`FakePauseMonitor`, not `PauseMonitor`), so the binding is
  /// keyed under the fake's own type. [resolve] then never finds it, since it
  /// looks the binding up under the type the CALL SITE names, and the
  /// override silently never applies: no error, the fallback just keeps
  /// running.
  static void bind<A extends MagicAction>(A Function() factory) {
    _bindings[A] = factory;
  }

  /// Resolves the action bound for [A] via [bind], or [fallback] when
  /// nothing is bound.
  ///
  /// ```dart
  /// MagicAction.resolve(PauseMonitor.new).handle(id);
  /// ```
  static A resolve<A extends MagicAction>(A Function() fallback) {
    final bound = _bindings[A];
    if (bound == null) return fallback();
    return bound() as A;
  }

  /// Clears every override registered via [bind].
  static void flush() {
    _bindings.clear();
  }
}
