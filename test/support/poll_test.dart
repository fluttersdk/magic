import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/support/poll.dart';

/// What this pins: [Poll.until] re-reads on a fixed interval until [done]
/// accepts a value or the attempt budget runs out, the FIRST read happens
/// only after one interval (never immediately), and [PollHandle.cancel] stops
/// the timer and settles [PollHandle.result] with [PollCancelled] rather than
/// leaving it hanging.
///
/// No `package:fake_async` dev dependency is present, so these run against
/// real millisecond-scale timers instead of a virtual clock.
void main() {
  group('Poll.until, settles', () {
    test('settles with the first value done accepts', () async {
      int reads = 0;
      final PollHandle<int> handle = Poll.until<int>(
        read: () async {
          reads++;
          return reads;
        },
        done: (int value) => value >= 2,
        every: const Duration(milliseconds: 10),
        maxAttempts: 5,
      );

      final PollOutcome<int> outcome = await handle.result;

      expect(outcome, isA<PollSettled<int>>());
      expect((outcome as PollSettled<int>).value, equals(2));
      expect(reads, equals(2));
    });

    test('the first read runs only after one interval elapses', () async {
      final List<int> readTimestamps = [];
      final Stopwatch stopwatch = Stopwatch()..start();

      final PollHandle<int> handle = Poll.until<int>(
        read: () async {
          readTimestamps.add(stopwatch.elapsedMilliseconds);
          return 1;
        },
        done: (int value) => value == 1,
        every: const Duration(milliseconds: 30),
        maxAttempts: 3,
      );

      await handle.result;

      expect(readTimestamps, hasLength(1));
      expect(readTimestamps.single, greaterThanOrEqualTo(25));
    });
  });

  group('Poll.until, exhausts', () {
    test(
      'a done that never holds exhausts at exactly maxAttempts reads',
      () async {
        int reads = 0;
        final PollHandle<int> handle = Poll.until<int>(
          read: () async {
            reads++;
            return reads;
          },
          done: (int value) => false,
          every: const Duration(milliseconds: 10),
          maxAttempts: 3,
        );

        final PollOutcome<int> outcome = await handle.result;

        expect(reads, equals(3));
        expect(outcome, isA<PollExhausted<int>>());
        expect((outcome as PollExhausted<int>).lastValue, equals(3));
      },
    );

    test('a read that never lands (null) still exhausts on schedule', () async {
      int reads = 0;
      final PollHandle<int?> handle = Poll.until<int?>(
        read: () async {
          reads++;
          return null;
        },
        done: (int? value) => value != null,
        every: const Duration(milliseconds: 10),
        maxAttempts: 2,
      );

      final PollOutcome<int?> outcome = await handle.result;

      expect(reads, equals(2));
      expect(outcome, isA<PollExhausted<int?>>());
      expect((outcome as PollExhausted<int?>).lastValue, isNull);
    });

    test(
      'a read that throws counts as a missed read and still exhausts',
      () async {
        int reads = 0;
        final PollHandle<int> handle = Poll.until<int>(
          read: () async {
            reads++;
            throw StateError('network down');
          },
          done: (int value) => true,
          every: const Duration(milliseconds: 10),
          maxAttempts: 2,
        );

        final PollOutcome<int> outcome = await handle.result;

        expect(reads, equals(2));
        expect(outcome, isA<PollExhausted<int>>());
      },
    );
  });

  group('Poll.until, cancel', () {
    test('cancel before any read settles with PollCancelled', () async {
      int reads = 0;
      final PollHandle<int> handle = Poll.until<int>(
        read: () async {
          reads++;
          return reads;
        },
        done: (int value) => true,
        every: const Duration(milliseconds: 50),
        maxAttempts: 5,
      );

      handle.cancel();
      final PollOutcome<int> outcome = await handle.result;

      expect(outcome, isA<PollCancelled<int>>());
      expect(reads, equals(0));
    });

    test('cancel after settling is a no-op', () async {
      final PollHandle<int> handle = Poll.until<int>(
        read: () async => 1,
        done: (int value) => value == 1,
        every: const Duration(milliseconds: 10),
        maxAttempts: 2,
      );

      final PollOutcome<int> outcome = await handle.result;
      expect(outcome, isA<PollSettled<int>>());

      expect(handle.cancel, returnsNormally);
    });
  });
}
