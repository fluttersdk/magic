import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/support/countdown.dart';

/// What this pins: [Countdown] ticks a per-key clock down once a second,
/// notifies [Countdown.onTick] on every tick, and stops (and forgets) the key
/// on its own once it reaches zero, rather than ticking into negative numbers
/// or leaving a finished timer running.
///
/// No `package:fake_async` dev dependency is present, so this waits on real
/// one-second timers; kept to the two shortest counts the assertions need.
void main() {
  group('Countdown.start / remaining / isRunning', () {
    test('start seeds remaining and marks the key running', () {
      final Countdown countdown = Countdown();
      countdown.start('retry', 5);

      expect(countdown.remaining('retry'), equals(5));
      expect(countdown.isRunning('retry'), isTrue);

      countdown.cancelAll();
    });

    test('an unknown key answers null / not running', () {
      final Countdown countdown = Countdown();

      expect(countdown.remaining('missing'), isNull);
      expect(countdown.isRunning('missing'), isFalse);
    });

    test('restarting a key resets its remaining count', () async {
      final Countdown countdown = Countdown();
      countdown.start('retry', 1);
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      expect(countdown.isRunning('retry'), isFalse);

      countdown.start('retry', 5);

      expect(countdown.remaining('retry'), equals(5));
      countdown.cancelAll();
    });
  });

  group('Countdown ticking', () {
    test('onTick fires with the decremented remaining count', () async {
      final Countdown countdown = Countdown();
      final List<int> ticks = [];
      countdown.onTick = (Object key, int remaining) => ticks.add(remaining);

      countdown.start('retry', 2);
      await Future<void>.delayed(const Duration(milliseconds: 2200));

      expect(ticks, equals([1, 0]));
      expect(countdown.isRunning('retry'), isFalse);
      expect(countdown.remaining('retry'), isNull);
    });
  });

  group('Countdown.cancel / cancelAll', () {
    test('cancel stops a specific key without touching others', () {
      final Countdown countdown = Countdown();
      countdown.start('a', 10);
      countdown.start('b', 10);

      countdown.cancel('a');

      expect(countdown.isRunning('a'), isFalse);
      expect(countdown.isRunning('b'), isTrue);

      countdown.cancelAll();
    });

    test('cancelAll stops every running key', () {
      final Countdown countdown = Countdown();
      countdown.start('a', 10);
      countdown.start('b', 10);

      countdown.cancelAll();

      expect(countdown.isRunning('a'), isFalse);
      expect(countdown.isRunning('b'), isFalse);
    });
  });
}
