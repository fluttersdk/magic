import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/support/number.dart';

void main() {
  group('Number.format', () {
    test('applies maxPrecision and the locale grouping/decimal marks (tr)', () {
      expect(
        Number.format(1234567.891, maxPrecision: 3, locale: 'tr'),
        '1.234.567,891',
      );
    });

    test('applies maxPrecision and the locale grouping/decimal marks (en)', () {
      expect(
        Number.format(1234567.891, maxPrecision: 3, locale: 'en'),
        '1,234,567.891',
      );
    });

    test('grouped: false drops the thousands separator', () {
      expect(Number.format(1234, locale: 'tr', grouped: false), '1234');
    });

    test('precision fixes both minimum and maximum fraction digits', () {
      expect(Number.format(0.5, precision: 2, locale: 'tr'), '0,50');
    });
  });

  group('Number.currency', () {
    test(
      'builds on simpleCurrency, not currency, so tr gets a symbol not an ISO code',
      () {
        expect(Number.currency(1234.5, code: 'TRY', locale: 'tr'), '₺1.234,50');
      },
    );
  });

  group('Number.percentage', () {
    test('takes a 0-100 input like Laravel and divides internally (tr)', () {
      expect(Number.percentage(99.95, precision: 2, locale: 'tr'), '%99,95');
    });

    test('takes a 0-100 input like Laravel and divides internally (en)', () {
      expect(Number.percentage(99.95, precision: 2, locale: 'en'), '99.95%');
    });
  });

  group('Number.abbreviate', () {
    test('compacts with the locale unit letters (tr)', () {
      // intl's compact pattern separates the number and unit letter with a
      // non-breaking space (U+00A0), not a regular space.
      expect(
        Number.abbreviate(1500000, maxPrecision: 1, locale: 'tr'),
        '1,5 Mn',
      );
    });
  });

  group('Number.fileSize', () {
    test('steps by 1024 and appends the locale-formatted number', () {
      expect(Number.fileSize(1536, maxPrecision: 1, locale: 'en'), '1.5 KB');
    });
  });

  group('Number locale fallback', () {
    test('an unknown locale falls back to en instead of throwing', () {
      expect(() => Number.format(1, locale: 'zz'), returnsNormally);
    });
  });
}
