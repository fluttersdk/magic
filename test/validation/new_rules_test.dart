import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/validation/rules/array_rule.dart';
import 'package:magic/src/validation/rules/between.dart';
import 'package:magic/src/validation/rules/boolean.dart';
import 'package:magic/src/validation/rules/comparison.dart';
import 'package:magic/src/validation/rules/date.dart';
import 'package:magic/src/validation/rules/integer.dart';
import 'package:magic/src/validation/rules/nullable.dart';
import 'package:magic/src/validation/rules/numeric.dart';
import 'package:magic/src/validation/rules/regex.dart';
import 'package:magic/src/validation/rules/required_if.dart';
import 'package:magic/src/validation/rules/uuid.dart';

/// The rules Laravel's `ValidatesAttributes` ships that this package did not:
/// `Uuid`, `Boolean`, `Numeric`, `Integer`, the four comparison rules,
/// `Between`, `Regex`, `Date`, `Nullable`, `RequiredIf` and `ArrayRule`.
///
/// Each rule is exercised through `passes()` directly, the way `FormValidator`
/// calls it, rather than through the `Validator`/`Lang` message pipeline.
void main() {
  group('Uuid', () {
    test('passes a lowercase RFC 4122 UUID', () {
      expect(
        const Uuid().passes('id', '9d3b2f1a-2e6a-4f0a-9c3d-1b2c3d4e5f6a', {}),
        isTrue,
      );
    });

    test('passes an uppercase UUID (case-insensitive)', () {
      expect(
        const Uuid().passes('id', '9D3B2F1A-2E6A-4F0A-9C3D-1B2C3D4E5F6A', {}),
        isTrue,
      );
    });

    test('fails a malformed string', () {
      expect(const Uuid().passes('id', 'not-a-uuid', {}), isFalse);
    });

    test('null passes (let Required handle null)', () {
      expect(const Uuid().passes('id', null, {}), isTrue);
    });
  });

  group('Boolean', () {
    test('passes true, false, 1, 0, "1", "0"', () {
      const rule = Boolean();
      expect(rule.passes('flag', true, {}), isTrue);
      expect(rule.passes('flag', false, {}), isTrue);
      expect(rule.passes('flag', 1, {}), isTrue);
      expect(rule.passes('flag', 0, {}), isTrue);
      expect(rule.passes('flag', '1', {}), isTrue);
      expect(rule.passes('flag', '0', {}), isTrue);
    });

    test('fails an arbitrary string', () {
      expect(const Boolean().passes('flag', 'yes', {}), isFalse);
    });

    test('null passes (let Required handle null)', () {
      expect(const Boolean().passes('flag', null, {}), isTrue);
    });
  });

  group('Numeric', () {
    test('passes a num and a numeric string', () {
      const rule = Numeric();
      expect(rule.passes('age', 18, {}), isTrue);
      expect(rule.passes('age', '18.5', {}), isTrue);
    });

    test('fails a non-numeric string', () {
      expect(const Numeric().passes('age', 'abc', {}), isFalse);
    });

    test('null passes (let Required handle null)', () {
      expect(const Numeric().passes('age', null, {}), isTrue);
    });
  });

  group('Integer', () {
    test('passes an int and an integer-looking string', () {
      const rule = Integer();
      expect(rule.passes('count', 5, {}), isTrue);
      expect(rule.passes('count', '5', {}), isTrue);
    });

    test('fails a decimal string', () {
      expect(const Integer().passes('count', '5.5', {}), isFalse);
    });

    test('null passes (let Required handle null)', () {
      expect(const Integer().passes('count', null, {}), isTrue);
    });
  });

  group('Gt', () {
    test('passes when the numeric value is greater than the threshold', () {
      expect(Gt(10).passes('age', 11, {}), isTrue);
    });

    test('fails when the string length is not greater than the threshold', () {
      expect(Gt(5).passes('name', 'abcde', {}), isFalse);
    });

    test('null passes (let Required handle null)', () {
      expect(Gt(10).passes('age', null, {}), isTrue);
    });
  });

  group('Gte', () {
    test('passes when the numeric value equals the threshold', () {
      expect(Gte(10).passes('age', 10, {}), isTrue);
    });

    test('fails when the list length is below the threshold', () {
      expect(Gte(3).passes('items', [1, 2], {}), isFalse);
    });
  });

  group('Lt', () {
    test('passes when the numeric value is less than the threshold', () {
      expect(Lt(10).passes('age', 9, {}), isTrue);
    });

    test('fails when the numeric value equals the threshold', () {
      expect(Lt(10).passes('age', 10, {}), isFalse);
    });
  });

  group('Lte', () {
    test('passes when the numeric value equals the threshold', () {
      expect(Lte(10).passes('age', 10, {}), isTrue);
    });

    test('fails when the numeric value exceeds the threshold', () {
      expect(Lte(10).passes('age', 11, {}), isFalse);
    });
  });

  group('Between', () {
    test('passes a numeric value inside the range', () {
      expect(Between(1, 10).passes('age', 5, {}), isTrue);
    });

    test('fails a string whose length falls outside the range', () {
      expect(Between(3, 5).passes('name', 'ab', {}), isFalse);
    });

    test('null passes (let Required handle null)', () {
      expect(Between(1, 10).passes('age', null, {}), isTrue);
    });
  });

  group('Regex', () {
    test('passes a string matching the pattern', () {
      expect(Regex(r'^[A-Z]{3}$').passes('code', 'ABC', {}), isTrue);
    });

    test('fails a string not matching the pattern', () {
      expect(Regex(r'^[A-Z]{3}$').passes('code', 'abcd', {}), isFalse);
    });

    test('null passes (let Required handle null)', () {
      expect(Regex(r'^[A-Z]{3}$').passes('code', null, {}), isTrue);
    });
  });

  group('Date', () {
    test('passes a DateTime instance', () {
      expect(const Date().passes('due', DateTime.now(), {}), isTrue);
    });

    test('passes a string DateTime.tryParse accepts', () {
      expect(const Date().passes('due', '2026-01-15', {}), isTrue);
    });

    test('fails an unparsable string', () {
      expect(const Date().passes('due', 'not a date', {}), isFalse);
    });

    test('null passes (let Required handle null)', () {
      expect(const Date().passes('due', null, {}), isTrue);
    });
  });

  group('Nullable', () {
    test('always passes, including for a non-null value', () {
      expect(const Nullable().passes('note', 'anything', {}), isTrue);
      expect(const Nullable().passes('note', null, {}), isTrue);
    });

    test('a null skips Numeric when both are applied to the same field', () {
      const rules = [Nullable(), Numeric()];
      for (final rule in rules) {
        expect(rule.passes('score', null, {}), isTrue);
      }
    });
  });

  group('RequiredIf', () {
    test('fails when absent and the other field matches the given value', () {
      expect(
        RequiredIf(
          'type',
          'company',
        ).passes('vatId', null, {'type': 'company'}),
        isFalse,
      );
    });

    test('passes when the other field does not match the given value', () {
      expect(
        RequiredIf(
          'type',
          'company',
        ).passes('vatId', null, {'type': 'individual'}),
        isTrue,
      );
    });

    test('passes when the other field matches and the value is present', () {
      expect(
        RequiredIf(
          'type',
          'company',
        ).passes('vatId', 'DE123', {'type': 'company'}),
        isTrue,
      );
    });
  });

  group('ArrayRule', () {
    test('passes a List', () {
      expect(const ArrayRule().passes('tags', ['a', 'b'], {}), isTrue);
    });

    test('fails a non-List value', () {
      expect(const ArrayRule().passes('tags', 'a,b', {}), isFalse);
    });

    test('null passes (let Required handle null)', () {
      expect(const ArrayRule().passes('tags', null, {}), isTrue);
    });
  });
}
