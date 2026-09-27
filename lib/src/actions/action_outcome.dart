/// The three ways a [RunsActions.runAction] call can end.
///
/// Replaces the old `Future<O?>` return, which answered `null` for three
/// different things (a void success, a failure and a refused same-key
/// re-entry) and left a caller that only checked `if (result == null)`
/// treating a refused double-tap as a success.
sealed class ActionOutcome<O> {
  const ActionOutcome();

  /// Whether the action ran to completion. Only [ActionSucceeded] answers
  /// `true`.
  bool get succeeded;

  /// The action's own result on [ActionSucceeded], `null` on [ActionFailed]
  /// or [ActionRefused].
  O? get valueOrNull;
}

/// [RunsActions.runAction] settles here when [MagicAction.handle] ran to
/// completion.
final class ActionSucceeded<O> extends ActionOutcome<O> {
  /// The value [MagicAction.handle] answered.
  final O value;

  const ActionSucceeded(this.value);

  @override
  bool get succeeded => true;

  @override
  O? get valueOrNull => value;
}

/// [RunsActions.runAction] settles here when [MagicAction.handle] threw: a
/// [ValidationException] (a 422 or a failed client rule) or any other
/// exception (a transport or unexpected failure). The caller's feedback (a
/// painted field error, a toast) has already run by the time this is
/// answered; [error] is carried for a caller that wants the raw cause too.
final class ActionFailed<O> extends ActionOutcome<O> {
  /// The exception [MagicAction.handle] threw.
  final Object error;

  const ActionFailed(this.error);

  @override
  bool get succeeded => false;

  @override
  O? get valueOrNull => null;
}

/// [RunsActions.runAction] settles here when [key] (or the shared unkeyed
/// slot) was already running: the action never ran a second time.
final class ActionRefused<O> extends ActionOutcome<O> {
  const ActionRefused();

  @override
  bool get succeeded => false;

  @override
  O? get valueOrNull => null;
}
