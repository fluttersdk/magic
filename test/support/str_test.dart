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

  group('Str.ascii', () {
    test('folds Latin diacritics while preserving case', () {
      expect(Str.ascii('Çağrı İşık Şeyma'), 'Cagri Isik Seyma');
    });

    test('folds ß to ss and its capital ẞ to SS', () {
      expect(Str.ascii('Straße'), 'Strasse');
      expect(Str.ascii('ẞ'), 'SS');
    });

    test('folds the Romanian s/t-with-comma letters (U+0219/U+021B)', () {
      expect(Str.ascii('Ștefan'), 'Stefan');
    });

    test('leaves non-Latin scripts untouched', () {
      expect(Str.ascii('Москва'), 'Москва');
    });

    test('folds the Turkish i family, matching Str.lower/Str.upper naming', () {
      expect(Str.ascii('İ'), 'I');
      expect(Str.ascii('ı'), 'i');
    });

    test('folds the ligatures and the Angstrom sign to a plain letter', () {
      expect(Str.ascii('æ'), 'ae');
      expect(Str.ascii('œ'), 'oe');
      expect(Str.ascii('Å'), 'A');
    });

    test('strips a combining mark that survived without composing', () {
      expect(Str.ascii('é'), 'e');
    });
  });

  group('Str.squish', () {
    test('trims and collapses runs of whitespace to one space', () {
      expect(Str.squish('  a \t\n b  '), 'a b');
    });

    test('collapses the two Hangul filler code points as whitespace too', () {
      expect(Str.squish('aㅤᅠb'), 'a b');
    });
  });

  group('Str.unwrap', () {
    test('strips a matching before/after pair', () {
      expect(Str.unwrap('"x"', '"'), 'x');
      expect(Str.unwrap('[x]', '[', ']'), 'x');
    });

    test(
      'strips the prefix alone when the suffix does not match (Laravel parity)',
      () {
        expect(Str.unwrap('"x', '"'), 'x');
      },
    );

    test('leaves a value with neither the prefix nor the suffix unchanged', () {
      expect(Str.unwrap('x', '"'), 'x');
    });
  });
}
