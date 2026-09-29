import 'dart:async';

import 'package:flutter/foundation.dart';

import '../actions/action_outcome.dart';
import '../http/magic_controller.dart';

/// The path a [ControllerNotified] notification ran inside.
enum MagicNotifyCause {
  /// A `MagicStateMixin.setState` (and so every `setSuccess`, `setError`,
  /// `setLoading` and `setEmpty`).
  setState,

  /// A [RepositoryQuery] forwarding a repository or paginator change.
  repositoryQuery,

  /// A [Countdown] tick, a [Debouncer] fire or a [Poll] read.
  timerTick,

  /// A [BroadcastListeners] fan-out of one realtime message.
  broadcast,

  /// None of the above: a `refreshUI()` the app called on its own.
  direct,
}

/// One observation [MagicPerfHooks.sink] receives.
///
/// Every timestamp is [FlutterTimeline.now], in microseconds on the same
/// clock the engine stamps frame timings with, so a consumer can place an
/// event inside the frame it delayed. A subtype is only ever constructed
/// behind a `MagicPerfHooks.sink != null` check.
sealed class MagicPerfEvent {
  MagicPerfEvent() {
    assert(() {
      debugEventsConstructed++;
      return true;
    }());
  }

  /// How many events have been constructed since the last reset; a test
  /// holds it at zero to prove an uninstalled sink costs no allocation.
  @visibleForTesting
  static int debugEventsConstructed = 0;
}

/// A [MagicController] ran `refreshUI()`.
final class ControllerNotified extends MagicPerfEvent {
  ControllerNotified(this.controller, this.cause);

  final MagicController controller;

  /// The instrumented path the notification ran inside; see
  /// [MagicPerfHooks.runWithCause] and [MagicPerfHooks.runWithRootCause].
  final MagicNotifyCause cause;
}

/// A [Repository] merged [count] rows of model [type] from a list or show
/// read.
final class RepositoryUpserted extends MagicPerfEvent {
  RepositoryUpserted(this.type, this.count);

  final Type type;

  final int count;
}

/// A [RepositoryQuery] over model [type] settled a reload.
final class QueryReloaded extends MagicPerfEvent {
  QueryReloaded(this.type, this.startUs, this.endUs, this.fromCache);

  final Type type;

  final int startUs;

  final int endUs;

  /// True when `ensureFresh` joined a first load already in flight instead
  /// of issuing a request of its own.
  final bool fromCache;
}

/// `RunsActions.runAction` ran an action of [type] to [outcome].
final class ActionRan extends MagicPerfEvent {
  ActionRan(this.type, this.startUs, this.endUs, this.outcome);

  final Type type;

  final int startUs;

  final int endUs;

  /// [ActionSucceeded] or [ActionFailed]; a refused re-entry never runs the
  /// action and is not reported.
  final ActionOutcome<Object?> outcome;
}

/// The event dispatcher delivered an event of [type] to [listenerCount]
/// typed and wildcard listeners.
final class EventDispatched extends MagicPerfEvent {
  EventDispatched(this.type, this.listenerCount, this.startUs, this.endUs);

  final Type type;

  final int listenerCount;

  final int startUs;

  final int endUs;
}

/// `Model.getAttribute` computed a cast. A memoised read is not a cast and
/// is not reported.
final class AttributeCast extends MagicPerfEvent {
  AttributeCast(this.castType);

  /// The built-in cast name (`datetime`, `json`, ...) or the runtime type
  /// name of a `CastsAttributes` instance.
  final String castType;
}

/// A timer owned by [ownerType] ([Countdown], [Debouncer] or [Poll]) fired.
final class TimerTicked extends MagicPerfEvent {
  TimerTicked(this.ownerType);

  final Type ownerType;
}

/// [BroadcastListeners] received a realtime message named [event].
final class BroadcastReceived extends MagicPerfEvent {
  BroadcastReceived(this.event);

  final String event;
}

/// The one opt-in seam magic reports its runtime activity through.
///
/// Null by default, and every instrumented site checks [sink] before it
/// builds anything, so an app that never installs one pays a single null
/// check per site and allocates nothing. Magic depends on no tooling
/// package; a diagnostic outside it assigns [sink].
abstract final class MagicPerfHooks {
  /// Receives every [MagicPerfEvent] while set.
  static void Function(MagicPerfEvent event)? sink;

  /// The zone value key a cause scope is stored under.
  static final Object _causeKey = Object();

  /// The cause a [ControllerNotified] built right now would carry: the cause
  /// of the innermost open scope in the current zone, or
  /// [MagicNotifyCause.direct] when there is none.
  static MagicNotifyCause get currentCause {
    final _CauseScope? scope = Zone.current[_causeKey] as _CauseScope?;
    if (scope == null || scope.closed) return MagicNotifyCause.direct;

    return scope.cause;
  }

  /// Delivers [event] to [sink].
  ///
  /// Contained deliberately, not swallowed: the sink is tooling code outside
  /// this package and runs before the notification it observes, so an
  /// unguarded throw would stop the screen repainting. A broken observer
  /// costs its own numbers, never the app's frames.
  static void emit(MagicPerfEvent event) {
    final void Function(MagicPerfEvent event)? target = sink;
    if (target == null) return;

    try {
      target(event);
    } catch (error, stack) {
      debugPrint('MagicPerfHooks.sink threw and was ignored: $error\n$stack');
    }
  }

  /// Runs [body] under the DERIVED [cause]: an open inherited cause is kept,
  /// and [cause] applies only when there is none.
  ///
  /// A `setState` inside a timer tick reports [MagicNotifyCause.timerTick],
  /// because the tick is why the state moved. Call sites reach this only once
  /// they have seen a non-null [sink].
  static R runWithCause<R>(MagicNotifyCause cause, R Function() body) {
    if (currentCause != MagicNotifyCause.direct) return body();

    return _runInScope(cause, body);
  }

  /// Runs [body] under the ROOT [cause], replacing any inherited one.
  ///
  /// A root site is where work starts anew (a timer firing, a realtime
  /// message arriving), so a [Debouncer] armed during a broadcast reports
  /// [MagicNotifyCause.timerTick] when it fires, not the broadcast that armed
  /// it. Call sites reach this only once they have seen a non-null [sink].
  static R runWithRootCause<R>(MagicNotifyCause cause, R Function() body) {
    return _runInScope(cause, body);
  }

  /// Runs [body] in a zone carrying a fresh [_CauseScope] for [cause], so the
  /// cause follows [body] across its awaits.
  ///
  /// The scope closes when [body] returns, or when the Future it returns
  /// completes. A timer or stream subscription registered inside the zone
  /// keeps the zone for good, but a delivery after the close reads
  /// [MagicNotifyCause.direct]: it is not part of the work that opened the
  /// scope. A Future [body] returns is handed back chained through the close,
  /// so its error still reaches whoever awaits it, or the zone when nobody
  /// does, exactly once.
  static R _runInScope<R>(MagicNotifyCause cause, R Function() body) {
    final _CauseScope scope = _CauseScope(cause);

    return runZoned<R>(() {
      bool closesLater = false;
      try {
        final R result = body();
        if (result is Future<Object?>) {
          closesLater = true;
          return result.whenComplete(scope.close) as R;
        }
        return result;
      } finally {
        if (!closesLater) scope.close();
      }
    }, zoneValues: <Object, Object>{_causeKey: scope});
  }

  /// Reports a tick of a timer owned by [ownerType] and runs [fire] under
  /// the root cause [MagicNotifyCause.timerTick]. Call sites reach this only
  /// once they have seen a non-null [sink].
  static R timerTick<R>(Type ownerType, R Function() fire) {
    emit(TimerTicked(ownerType));
    return runWithRootCause(MagicNotifyCause.timerTick, fire);
  }
}

/// The zone value a cause scope stores: [cause] until [close] runs.
final class _CauseScope {
  _CauseScope(this.cause);

  final MagicNotifyCause cause;

  bool closed = false;

  void close() => closed = true;
}
