import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/http/magic_controller.dart';
import 'package:magic/src/http/owns_timers.dart';
import 'package:magic/src/support/countdown.dart';
import 'package:magic/src/support/debouncer.dart';
import 'package:magic/src/support/poll.dart';

/// A minimal controller exercising [OwnsTimers] on its own, with no other
/// mixin in the way.
class _TimedController extends MagicController with OwnsTimers {}

/// What this pins: [OwnsTimers.own] hands the caller back whatever it was
/// given, cancels every owned poll/countdown/debouncer/timer/subscription
/// from [MagicController.onClose] (so a disposed controller never leaves one
/// ticking against a tenant it no longer represents), and refuses to arm a
/// new one once the controller is already disposed.
void main() {
  group('OwnsTimers.own', () {
    test('returns the cancellable it was given', () {
      final _TimedController controller = _TimedController();
      final Debouncer debouncer = Debouncer();

      expect(controller.own(debouncer), same(debouncer));
    });

    test('throws StateError when the controller is already disposed', () {
      final _TimedController controller = _TimedController();
      controller.dispose();

      expect(() => controller.own(Debouncer()), throwsA(isA<StateError>()));
    });
  });

  group('OwnsTimers.onClose cancels every owned resource', () {
    test('an owned poll is cancelled and settles with PollCancelled', () async {
      final _TimedController controller = _TimedController();
      int reads = 0;
      final PollHandle<int> handle = controller.own(
        Poll.until<int>(
          read: () async {
            reads++;
            return reads;
          },
          done: (int value) => true,
          every: const Duration(milliseconds: 50),
          maxAttempts: 5,
        ),
      );

      controller.dispose();
      final PollOutcome<int> outcome = await handle.result;

      expect(outcome, isA<PollCancelled<int>>());
      expect(reads, equals(0));
    });

    test('an owned countdown stops ticking', () async {
      final _TimedController controller = _TimedController();
      final Countdown countdown = controller.own(Countdown());
      countdown.start('retry', 5);

      controller.dispose();

      expect(countdown.isRunning('retry'), isFalse);
    });

    test('an owned debouncer never fires its pending run', () async {
      final _TimedController controller = _TimedController();
      final Debouncer debouncer = controller.own(Debouncer());
      int fired = 0;
      debouncer.run('reload', const Duration(milliseconds: 20), () => fired++);

      controller.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(fired, equals(0));
    });

    test('an owned bare Timer is cancelled', () {
      final _TimedController controller = _TimedController();
      bool fired = false;
      final Timer timer = controller.own(
        Timer(const Duration(milliseconds: 20), () => fired = true),
      );

      controller.dispose();

      expect(timer.isActive, isFalse);
      expect(fired, isFalse);
    });

    test('an owned StreamSubscription is cancelled', () async {
      final _TimedController controller = _TimedController();
      final StreamController<int> source = StreamController<int>();
      bool received = false;
      controller.own(source.stream.listen((int _) => received = true));

      controller.dispose();
      source.add(1);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(received, isFalse);
      await source.close();
    });
  });
}
