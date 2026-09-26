import 'dart:async';

import '../facades/log.dart';
import '../foundation/magic.dart';

/// The three ways a [Poll.until] run can end.
sealed class PollOutcome<T> {
  const PollOutcome();
}

/// [PollHandle.result] settles here when [Poll.until]'s `done` callback
/// accepts a read within its attempt budget.
final class PollSettled<T> extends PollOutcome<T> {
  /// The value `done` accepted.
  final T value;

  const PollSettled(this.value);
}

/// [PollHandle.result] settles here when every attempt ran out without
/// `done` ever accepting a read.
final class PollExhausted<T> extends PollOutcome<T> {
  /// The last value read, or null when the last read answered null too.
  final T? lastValue;

  const PollExhausted(this.lastValue);
}

/// [PollHandle.result] settles here when [PollHandle.cancel] ran before
/// `done` accepted a read or the attempt budget ran out.
final class PollCancelled<T> extends PollOutcome<T> {
  const PollCancelled();
}

/// The live handle [Poll.until] hands back: [result] is the eventual
/// [PollOutcome], and [cancel] stops the pending read early.
class PollHandle<T> {
  final Completer<PollOutcome<T>> _completer;
  final void Function() _cancel;

  PollHandle._(this._completer, this._cancel);

  /// The poll's eventual outcome: [PollSettled], [PollExhausted] or
  /// [PollCancelled].
  Future<PollOutcome<T>> get result => _completer.future;

  /// Stops the pending timer and settles [result] with [PollCancelled], if it
  /// has not already settled. A no-op once the poll has already settled.
  void cancel() => _cancel();
}

/// Re-reads on a fixed interval until a value is accepted or an attempt
/// budget runs out, replacing the `Timer`-per-field polling loops
/// `MonitorController` hand-rolled for a manual check's result and an
/// analyze run's progress (`monitor_controller.dart:816-850, :1629-1672`).
abstract final class Poll {
  /// Reads via [read] every [every], stopping the first time [done] accepts
  /// a non-null value or after [maxAttempts] reads, whichever comes first.
  ///
  /// The first read runs only after one [every] interval, never immediately:
  /// the caller already has whatever state it polled before starting, so the
  /// first useful answer is the first one that could plausibly have changed.
  /// A null [read] result is treated as "not landed yet" and never reaches
  /// [done].
  static PollHandle<T> until<T>({
    required Future<T?> Function() read,
    required bool Function(T value) done,
    required Duration every,
    required int maxAttempts,
  }) {
    final Completer<PollOutcome<T>> completer = Completer<PollOutcome<T>>();
    Timer? timer;
    bool cancelled = false;
    int attempts = 0;
    T? lastValue;

    void settle(PollOutcome<T> outcome) {
      timer?.cancel();
      if (!completer.isCompleted) completer.complete(outcome);
    }

    void scheduleNext() {
      timer = Timer(every, () async {
        if (cancelled) return;

        attempts++;
        // A read that throws spends its attempt like a read that answered
        // nothing: the handle must still settle, and an escaping error here
        // would be an unhandled async error with the poll left open forever.
        T? value;
        try {
          value = await read();
        } catch (error) {
          if (Magic.bound('log')) {
            Log.warning('[Poll] read failed, counted as a miss: $error');
          }
        }
        if (cancelled) return;

        lastValue = value;
        if (value != null && done(value)) {
          settle(PollSettled<T>(value));
          return;
        }

        if (attempts >= maxAttempts) {
          settle(PollExhausted<T>(lastValue));
          return;
        }

        scheduleNext();
      });
    }

    scheduleNext();

    return PollHandle<T>._(completer, () {
      if (cancelled || completer.isCompleted) return;

      cancelled = true;
      timer?.cancel();
      completer.complete(PollCancelled<T>());
    });
  }
}
