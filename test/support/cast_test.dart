import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/support/cast.dart';

/// What this pins: every [Cast] reader degrades a wrong-typed wire value to
/// its stated fallback instead of throwing, and the one deliberate asymmetry
/// ([Cast.intOr] alone parses a numeric string) holds.
void main() {
  group('Cast.stringOr', () {
    test('reads a String', () {
      expect(Cast.stringOr('hello', 'fallback'), 'hello');
    });

    test('falls back on a non-String', () {
      expect(Cast.stringOr(42, 'fallback'), 'fallback');
      expect(Cast.stringOr(null, 'fallback'), 'fallback');
    });
  });

  group('Cast.stringOrNull', () {
    test('reads a String', () {
      expect(Cast.stringOrNull('hello'), 'hello');
    });

    test('answers null on a non-String', () {
      expect(Cast.stringOrNull(42), isNull);
      expect(Cast.stringOrNull(null), isNull);
    });
  });

  group('Cast.intOr', () {
    test('reads a num', () {
      expect(Cast.intOr(3, 0), 3);
      expect(Cast.intOr(3.9, 0), 3);
    });

    test('parses a numeric string, unlike every other reader here', () {
      expect(Cast.intOr('3', 0), 3);
    });

    test('falls back on an unparseable string or other type', () {
      expect(Cast.intOr('abc', 0), 0);
      expect(Cast.intOr(null, 0), 0);
      expect(Cast.intOr(true, 0), 0);
    });
  });

  group('Cast.intOrNull', () {
    test('reads a num', () {
      expect(Cast.intOrNull(3), 3);
      expect(Cast.intOrNull(3.9), 3);
    });

    test('does NOT parse a numeric string', () {
      expect(Cast.intOrNull('3'), isNull);
    });

    test('answers null on anything else', () {
      expect(Cast.intOrNull(null), isNull);
      expect(Cast.intOrNull(true), isNull);
    });
  });

  group('Cast.numOrNull', () {
    test('reads a num', () {
      expect(Cast.numOrNull(3), 3);
      expect(Cast.numOrNull(3.5), 3.5);
    });

    test('does NOT parse a numeric string', () {
      expect(Cast.numOrNull('3'), isNull);
    });
  });

  group('Cast.doubleOrNull', () {
    test('reads a num and converts to double', () {
      expect(Cast.doubleOrNull(3), 3.0);
      expect(Cast.doubleOrNull(3.5), 3.5);
    });

    test('answers null on a non-num', () {
      expect(Cast.doubleOrNull('3'), isNull);
      expect(Cast.doubleOrNull(null), isNull);
    });
  });

  group('Cast.boolOr', () {
    test('reads a bool', () {
      expect(Cast.boolOr(true, false), isTrue);
    });

    test('falls back on a non-bool', () {
      expect(Cast.boolOr('yes', false), isFalse);
      expect(Cast.boolOr(null, true), isTrue);
    });
  });

  group('Cast.boolOrNull', () {
    test('reads a bool', () {
      expect(Cast.boolOrNull(false), isFalse);
    });

    test('answers null on a non-bool', () {
      expect(Cast.boolOrNull('yes'), isNull);
    });
  });

  group('Cast.idOrNull', () {
    test('reads a String as is', () {
      expect(Cast.idOrNull('abc-123'), 'abc-123');
    });

    test('stringifies a num', () {
      expect(Cast.idOrNull(42), '42');
    });

    test('answers null on anything else', () {
      expect(Cast.idOrNull(null), isNull);
      expect(Cast.idOrNull(true), isNull);
    });
  });
}
