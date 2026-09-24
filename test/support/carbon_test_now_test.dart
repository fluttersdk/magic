import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/support/carbon.dart';

void main() {
  group('Carbon.setTestNow', () {
    tearDown(() {
      // Never leak a frozen clock into an unrelated test.
      Carbon.setTestNow();
    });

    test('now() returns the set instant', () {
      final frozen = Carbon.create(
        year: 2024,
        month: 3,
        day: 15,
        hour: 10,
        minute: 30,
      );

      Carbon.setTestNow(frozen);

      final now = Carbon.now();
      expect(now.year, 2024);
      expect(now.month, 3);
      expect(now.day, 15);
      expect(now.hour, 10);
      expect(now.minute, 30);
    });

    test('hasTestNow() reports whether a frozen instant is set', () {
      expect(Carbon.hasTestNow(), isFalse);

      Carbon.setTestNow(Carbon.create(year: 2024));
      expect(Carbon.hasTestNow(), isTrue);

      Carbon.setTestNow();
      expect(Carbon.hasTestNow(), isFalse);
    });

    test('setTestNow() with no argument clears the frozen instant', () {
      Carbon.setTestNow(Carbon.create(year: 2024, month: 3, day: 15));

      Carbon.setTestNow();

      final now = Carbon.now();
      final dartNow = DateTime.now();
      expect(now.year, dartNow.year);
      expect(now.month, dartNow.month);
      expect(now.day, dartNow.day);
    });

    test('setTestNow() is safe to call when nothing was set', () {
      expect(Carbon.hasTestNow(), isFalse);
      expect(() => Carbon.setTestNow(), returnsNormally);
      expect(Carbon.hasTestNow(), isFalse);
    });

    test('timezone variant respects the frozen instant', () {
      final frozen = Carbon.create(year: 2024, month: 6, day: 1, hour: 12);
      Carbon.setTestNow(frozen);

      final inTokyo = Carbon.now('Asia/Tokyo');

      expect(inTokyo.year, 2024);
      expect(inTokyo.month, 6);
      // Asia/Tokyo (UTC+9) is ahead of the frozen local instant's implied UTC.
      expect(inTokyo.hour, isNot(equals(0)));
    });
  });
}
