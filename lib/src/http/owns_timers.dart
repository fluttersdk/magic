import 'dart:async';

import '../support/countdown.dart';
import '../support/debouncer.dart';
import '../support/poll.dart';
import 'magic_controller.dart';

/// Cancels timer-shaped resources a controller started, once it closes.
///
/// [own] accepts anything a controller starts and later has to stop
/// ([PollHandle], [Countdown], [Debouncer], a bare [Timer] or a
/// [StreamSubscription]) and cancels every owned one from [onClose], so a
/// controller that polls, counts down or debounces never has to hand-write
/// its own cancellation list (see `monitor_controller.dart`'s
/// `_cooldownTimers`/`_resultWatchTimers`/`_analyzePollTimer` and
/// `realtime_service.dart`'s `_reloadTimer`, each cancelled by hand today).
mixin OwnsTimers on MagicController {
  /// Every cancellable [own] has handed out, in registration order.
  final List<Object> _owned = [];

  /// Registers [cancellable] to be cancelled when this controller closes,
  /// and hands it back so a caller can chain, e.g.
  /// `final poll = own(Poll.until(...));`.
  ///
  /// Throws [StateError] when the controller is already disposed: arming a
  /// new timer past that point would leak, since [onClose] (the only place
  /// this mixin cancels anything) has already run.
  T own<T extends Object>(T cancellable) {
    if (isDisposed) {
      throw StateError(
        'Cannot own a timer on a controller that is already disposed.',
      );
    }

    _owned.add(cancellable);

    return cancellable;
  }

  @override
  void onClose() {
    for (final Object cancellable in _owned) {
      if (cancellable is PollHandle) {
        cancellable.cancel();
      } else if (cancellable is Countdown) {
        cancellable.cancelAll();
      } else if (cancellable is Debouncer) {
        cancellable.cancelAll();
      } else if (cancellable is Timer) {
        cancellable.cancel();
      } else if (cancellable is StreamSubscription) {
        cancellable.cancel();
      }
    }
    _owned.clear();

    super.onClose();
  }
}
