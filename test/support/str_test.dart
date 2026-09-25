import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/support/str.dart';

void main() {
  group('Str.upper', () {
    test('tr maps the dotted and dotless i before uppercasing', () {
      expect(
        Str.upper('çalışan izleyiciler', locale: 'tr'),
        'ÇALIŞAN İZLEYİCİLER',
      );
    });

    test('en uppercases plainly, with no Turkish dotting', () {
      expect(Str.upper('istanbul', locale: 'en'), 'ISTANBUL');
    });
  });

  group('Str.lower', () {
    test('tr maps I to dotless ı before lowercasing', () {
      expect(Str.lower('İSTANBUL', locale: 'tr'), 'istanbul');
    });

    test('tr lowercases a dotless I run correctly', () {
      expect(Str.lower('IŞIK', locale: 'tr'), 'ışık');
    });

    test('every locale maps İ to a plain i with no combining mark', () {
      final String result = Str.lower('İ', locale: 'en');
      expect(result, 'i');
      expect(result.length, 1);
    });
  });

  group('Str.initials', () {
    test(
      'limit keeps only the first N words and capitalize routes through Str.upper',
      () {
        expect(
          Str.initials('ismail kaya', limit: 2, capitalize: true, locale: 'tr'),
          'İK',
        );
      },
    );

    test('a blank value returns an empty string', () {
      expect(Str.initials('  '), '');
    });
  });

  test('initials read a whole code point, so an emoji stays intact', () {
    expect(Str.initials('😀 team'), '😀t');
  });

  test('a full locale tag resolves to its language code', () {
    expect(Str.upper('istanbul', locale: 'tr_TR'), 'İSTANBUL');
    expect(Str.lower('IŞIK', locale: 'tr-TR'), 'ışık');
  });
}
