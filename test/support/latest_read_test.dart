import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/support/latest_read.dart';

/// What this pins: [LatestRead] hands out an ever-increasing token per key so
/// an async read can tell whether it is still the newest one in flight for
/// that key, and a stale answer that lands after a newer read started reads
/// as no longer current instead of being painted over the fresher one.
void main() {
  group('LatestRead.begin / isCurrent', () {
    test('the first token issued for a key is current', () {
      final LatestRead read = LatestRead();
      final int token = read.begin('checks');

      expect(read.isCurrent(token, 'checks'), isTrue);
    });

    test('a newer token for the same key supersedes the older one', () {
      final LatestRead read = LatestRead();
      final int stale = read.begin('checks');
      final int fresh = read.begin('checks');

      expect(read.isCurrent(stale, 'checks'), isFalse);
      expect(read.isCurrent(fresh, 'checks'), isTrue);
    });

    test('tokens for different keys never interfere', () {
      final LatestRead read = LatestRead();
      read.begin('checks');
      final int checksToken = read.begin('checks');
      final int seriesToken = read.begin('series');

      expect(read.isCurrent(checksToken, 'checks'), isTrue);
      expect(read.isCurrent(seriesToken, 'series'), isTrue);
      // 'checks' is on its second token (2) while 'series' is on its first
      // (1); reading checksToken against 'series' must not coincide.
      expect(read.isCurrent(checksToken, 'series'), isFalse);
    });

    test('the default key tracks its own counter with no key argument', () {
      final LatestRead read = LatestRead();
      final int stale = read.begin();
      final int fresh = read.begin();

      expect(read.isCurrent(stale), isFalse);
      expect(read.isCurrent(fresh), isTrue);
    });
  });

  group('LatestRead.invalidate', () {
    test('drops whatever token is currently in flight for the key', () {
      final LatestRead read = LatestRead();
      final int token = read.begin('checks');
      expect(read.isCurrent(token, 'checks'), isTrue);

      read.invalidate('checks');

      expect(read.isCurrent(token, 'checks'), isFalse);
    });

    test('a read started after invalidate is current again', () {
      final LatestRead read = LatestRead();
      read.begin('checks');
      read.invalidate('checks');
      final int next = read.begin('checks');

      expect(read.isCurrent(next, 'checks'), isTrue);
    });
  });
}
