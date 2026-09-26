import '../concerns/validates_requests.dart';
import '../facades/lang.dart';
import '../foundation/magic.dart';
import '../http/magic_controller.dart';
import '../validation/exceptions/validation_exception.dart';
import 'magic_action.dart';

/// Runs a [MagicAction] from a controller, translating its two failure
/// modes into UI feedback so a call site never writes its own try/catch.
///
/// ```dart
/// class MonitorController extends MagicController
///     with ValidatesRequests, RunsActions {
///   Future<void> pause(String id) async {
///     await runAction(MagicAction.resolve(PauseMonitor.new), id, key: id);
///   }
/// }
/// ```
///
/// [runAction]:
/// - marks [key] (or a shared default slot when [key] is omitted) running
///   for the call's duration, refusing a second call under the same key
///   while the first is still in flight (returns `null` without running
///   [action] again);
/// - on a [ValidationException], paints its errors onto the host when it is
///   also a [ValidatesRequests] (through `setErrorsFromMap`, so
///   [CollapsesIndexedErrorKeys] applies if mixed in on top);
/// - on any other failure, calls [onFailure] when given (the caller owns the
///   feedback: its own toast, a silent cooldown, nothing at all), otherwise
///   shows a toast titled `trans('common.error_occurred')` with
///   [failureMessage] (or the exception's own text) as the body;
/// - answers `null` on either failure, and [action]'s own result on success.
mixin RunsActions on MagicController {
  /// Keys with an action currently in flight.
  final Set<Object> _runningKeys = {};

  /// Shared slot for a call site that never names a [key], so every unkeyed
  /// [runAction] call guards against itself rather than always answering
  /// `false` for [isRunning].
  final Object _unkeyedSlot = Object();

  /// Whether [key] (or the shared unkeyed slot, when omitted) is currently
  /// running.
  bool isRunning([Object? key]) => _runningKeys.contains(key ?? _unkeyedSlot);

  /// Runs [action] against [input]; see the mixin doc for the full contract.
  Future<O?> runAction<I, O>(
    MagicAction<I, O> action,
    I input, {
    Object? key,
    String? failureMessage,
    void Function(Object error)? onFailure,
  }) async {
    final runKey = key ?? _unkeyedSlot;
    if (_runningKeys.contains(runKey)) return null;

    _runningKeys.add(runKey);
    refreshUI();
    try {
      return await action.handle(input);
    } on ValidationException catch (e) {
      if (this is ValidatesRequests) {
        (this as ValidatesRequests).setErrorsFromMap(
          e.errors.map((field, message) => MapEntry(field, [message])),
        );
      }
      return null;
    } catch (e) {
      if (onFailure != null) {
        onFailure(e);
      } else {
        Magic.error(trans('common.error_occurred'), failureMessage ?? '$e');
      }
      return null;
    } finally {
      _runningKeys.remove(runKey);
      refreshUI();
    }
  }
}
