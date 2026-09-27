import 'dart:async';

/// Per-key clock ticking down to zero once a second, replacing the manual
/// per-monitor cooldown timer `MonitorController` used to hand-roll
/// (`monitor_controller.dart:672-728`).
///
/// Each key owns its own remaining-seconds count and [Timer.periodic], so a
/// controller can run several independent countdowns (a "check now" cooldown
/// per monitor id, say) without one key's clock interfering with another's.
/// A key's countdown stops (and forgets its own state) the moment it reaches
/// zero; it never ticks into negative numbers or keeps a finished timer
/// running.
class Countdown {
  /// Seconds remaining per running key.
  final Map<Object, int> _remaining = {};

  /// The ticking [Timer] per running key.
  final Map<Object, Timer> _timers = {};

  /// Fired on every tick, including the tick that reaches zero, with the key
  /// and its seconds still remaining.
  void Function(Object key, int remaining)? onTick;

  /// Starts (or restarts) [key]'s countdown at [seconds], ticking once a
  /// second until it reaches zero.
  void start(Object key, int seconds) {
    _timers[key]?.cancel();
    _remaining[key] = seconds;

    _timers[key] = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      final int next = (_remaining[key] ?? 1) - 1;

      if (next <= 0) {
        timer.cancel();
        _timers.remove(key);
        _remaining.remove(key);
        onTick?.call(key, 0);
        return;
      }

      _remaining[key] = next;
      onTick?.call(key, next);
    });
  }

  /// [key]'s remaining seconds, or null when it is not currently running.
  int? remaining(Object key) => _remaining[key];

  /// Whether [key]'s countdown is currently running.
  bool isRunning(Object key) => _timers.containsKey(key);

  /// Cancels [key]'s countdown and forgets its remaining count, if running.
  void cancel(Object key) {
    _timers.remove(key)?.cancel();
    _remaining.remove(key);
  }

  /// Cancels every currently running countdown.
  void cancelAll() {
    for (final Timer timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _remaining.clear();
  }
}
