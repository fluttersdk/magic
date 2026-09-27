import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// Serves one catalogue from a map.
class _MapLoader implements TranslationLoader {
  _MapLoader(this._sentences);

  final Map<String, dynamic> _sentences;

  @override
  Future<Map<String, dynamic>> load(Locale locale) async =>
      Map<String, dynamic>.from(_sentences);
}

/// How the size rules measure a string, following Laravel's `getSize`.
///
/// A string is sized by its VALUE only when the same attribute also carries a
/// numeric rule (`Numeric`, `Integer`), and by its LENGTH otherwise. Form
/// input is always a string, so both halves matter: `[Numeric(), Max(100)]`
/// has to refuse `"500"`, and `[Between(8, 64)]` on a password has to accept
/// `"12345678"`, which is numeric but is not a number the user meant.
void main() {
  setUp(() async {
    MagicApp.reset();
    Magic.flush();
    Translator.reset();

    Translator.instance.setLoader(
      _MapLoader(<String, dynamic>{
        'validation.between.numeric':
            ':attribute must be between :min and :max.',
        'validation.between.string':
            ':attribute must be between :min and :max characters.',
      }),
    );

    await Translator.instance.load(const Locale('en'));
  });

  bool passes(Map<String, dynamic> data, Map<String, List<Rule>> rules) {
    return Validator.make(data, rules).passes();
  }

  group('with a numeric rule on the attribute, a string is sized by value', () {
    test('Between refuses "500" outside 1..100', () {
      expect(
        passes(
          <String, dynamic>{'quantity': '500'},
          <String, List<Rule>>{
            'quantity': <Rule>[const Numeric(), Between(1, 100)],
          },
        ),
        isFalse,
      );
    });

    test('Between accepts "50" inside 1..100', () {
      expect(
        passes(
          <String, dynamic>{'quantity': '50'},
          <String, List<Rule>>{
            'quantity': <Rule>[const Numeric(), Between(1, 100)],
          },
        ),
        isTrue,
      );
    });

    test('Max refuses "500" over 100', () {
      expect(
        passes(
          <String, dynamic>{'quantity': '500'},
          <String, List<Rule>>{
            'quantity': <Rule>[const Numeric(), Max(100)],
          },
        ),
        isFalse,
      );
    });

    test('Min accepts "12" at least 3', () {
      expect(
        passes(
          <String, dynamic>{'quantity': '12'},
          <String, List<Rule>>{
            'quantity': <Rule>[const Integer(), Min(3)],
          },
        ),
        isTrue,
      );
    });

    test('the failure message is the numeric one', () {
      final Validator validator = Validator.make(
        <String, dynamic>{'quantity': '500'},
        <String, List<Rule>>{
          'quantity': <Rule>[const Numeric(), Between(1, 100)],
        },
      );

      expect(validator.fails(), isTrue);
      expect(
        validator.errors()['quantity'],
        'quantity must be between 1 and 100.',
      );
    });

    test('FormValidator.rules sizes by value too', () {
      final String? Function(String?) validate = FormValidator.rules<String>(
        <Rule>[const Integer(), Lte(10)],
        field: 'quantity',
      );

      expect(validate('11'), isNotNull);
      expect(validate('10'), isNull);
    });
  });

  group('without a numeric rule, a numeric string is sized by length', () {
    test('Between(8, 64) accepts an eight-digit password', () {
      expect(
        passes(
          <String, dynamic>{'password': '12345678'},
          <String, List<Rule>>{
            'password': <Rule>[const Required(), Between(8, 64)],
          },
        ),
        isTrue,
      );
    });

    test('Gte(8) accepts "00000001", eight characters long', () {
      expect(
        passes(
          <String, dynamic>{'pin': '00000001'},
          <String, List<Rule>>{
            'pin': <Rule>[Gte(8)],
          },
        ),
        isTrue,
      );
    });

    test('Lt called directly sizes "123" by its three characters', () {
      expect(Lt(10).passes('code', '123', <String, dynamic>{}), isTrue);
    });
  });
}
