import 'package:flutter/foundation.dart' show FlutterTimeline;

import '../concerns/validates_requests.dart';
import '../facades/lang.dart';
import '../facades/log.dart';
import '../foundation/magic.dart';
import '../http/magic_controller.dart';
import '../perf/magic_perf_hooks.dart';
import '../validation/exceptions/validation_exception.dart';
import 'action_outcome.dart';
import 'magic_action.dart';

/// Runs a [MagicAction] from a controller, translating its two failure
/// modes into UI feedback so a call site never writes its own try/catch.
///
/// ```dart
/// class MonitorController extends MagicController
///     with ValidatesRequests, RunsActions {
///   Future<void> pause(String id) async {
///     final outcome = await runAction(MagicAction.resolve(PauseMonitor.new), id, key: id);
///     if (!outcome.succeeded) return;
///   }
/// }
/// ```
///
/// [runAction]:
/// - marks [key] (or a shared default slot when [key] is omitted) running
///   for the call's duration, refusing a second call under the same key
///   while the first is still in flight, answering [ActionRefused] without
///   running [action] again;
/// - on a [ValidationException], paints its errors onto the host when it is
///   also a [ValidatesRequests] (through `setErrorsFromMap`, so
///   [CollapsesIndexedErrorKeys] applies if mixed in on top), otherwise
///   routes it through the same fallback feedback as any other failure
///   (since there is no error bag to paint it onto);
/// - on any other failure, calls [onFailure] when given (the caller owns the
///   feedback: its own toast, a silent cooldown, nothing at all), otherwise
///   logs the exception and shows a toast titled `trans('common.error_occurred')`
///   with [failureMessage] (or that same translated fallback, never the
///   exception's own text) as the body;
/// - answers [ActionSucceeded] with [action]'s own result on success,
///   [ActionFailed] on either failure and [ActionRefused] on a same-key
///   re-entry, so a caller can no longer mistake a refused double-tap for a
///   success by checking a `null` result.
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
  Future<ActionOutcome<O>> runAction<I, O>(
    MagicAction<I, O> action,
    I input, {
    Object? key,
    String? failureMessage,
    void Function(Object error)? onFailure,
  }) async {
    final runKey = key ?? _unkeyedSlot;
    if (_runningKeys.contains(runKey)) return ActionRefused<O>();

    _runningKeys.add(runKey);
    refreshUI();
    if (MagicPerfHooks.sink == null) {
      return _settle(action, input, runKey, failureMessage, onFailure);
    }

    final int startUs = FlutterTimeline.now;
    final ActionOutcome<O> outcome = await _settle(
      action,
      input,
      runKey,
      failureMessage,
      onFailure,
    );
    if (MagicPerfHooks.sink != null) {
      MagicPerfHooks.emit(
        ActionRan(action.runtimeType, startUs, FlutterTimeline.now, outcome),
      );
    }
    return outcome;
  }

  /// Runs [action] and translates its failure modes; see the mixin doc.
  Future<ActionOutcome<O>> _settle<I, O>(
    MagicAction<I, O> action,
    I input,
    Object runKey,
    String? failureMessage,
    void Function(Object error)? onFailure,
  ) async {
    try {
      final O value = await action.handle(input);
      return ActionSucceeded<O>(value);
    } on ValidationException catch (e) {
      if (this is ValidatesRequests) {
        (this as ValidatesRequests).setErrorsFromMap(
          e.errors.map((field, message) => MapEntry(field, [message])),
        );
      } else {
        // No error bag to paint this onto: fall back to the same feedback
        // path a non-validation failure gets, rather than swallowing it.
        _reportFailure(e, onFailure, failureMessage);
      }
      return ActionFailed<O>(e);
    } catch (e) {
      _reportFailure(e, onFailure, failureMessage);
      return ActionFailed<O>(e);
    } finally {
      _runningKeys.remove(runKey);
      refreshUI();
    }
  }

  /// Routes a failure to [onFailure] when given (the caller owns the
  /// feedback entirely); otherwise logs [error] (guarded the way
  /// `Poll.until` guards its own `Log.warning`, since a host under test may
  /// have nothing bound under `'log'`) and shows a toast that never repeats
  /// [error]'s own text, which may carry a raw Dio message with an internal
  /// URL in it.
  void _reportFailure(
    Object error,
    void Function(Object error)? onFailure,
    String? failureMessage,
  ) {
    if (onFailure != null) {
      onFailure(error);
      return;
    }

    if (Magic.bound('log')) {
      Log.error('[RunsActions] action failed: $error');
    }
    Magic.error(
      trans('common.error_occurred'),
      failureMessage ?? trans('common.error_occurred'),
    );
  }
}
