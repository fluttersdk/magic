import 'dart:async';

/// Coalesces repeated calls under the same key into one delayed run,
/// generalising the single-purpose reload debounce `RealtimeService` used to
/// hand-roll for itself (`realtime_service.dart:252-256`).
///
/// Each call to [run] for a given key cancels that key's still-pending timer
/// and arms a fresh one, so several calls inside [Duration] of each other
/// collapse into a single run of the LAST callback given.
class Debouncer {
  /// The pending timer per key.
  final Map<Object, Timer> _timers = {};

  /// Arms [key]'s timer to run [fn] after [duration], cancelling whatever
  /// [key] already had pending.
  void run(Object key, Duration duration, void Function() fn) {
    _timers[key]?.cancel();
    _timers[key] = Timer(duration, () {
      _timers.remove(key);
      fn();
    });
  }

  /// Cancels every pending run without firing any of them.
  void cancelAll() {
    for (final Timer timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}
