import 'package:intl/intl.dart';

import '../facades/lang.dart';

/// Locale-aware number formatting, modelled on Laravel's `Number` helper
/// (`Illuminate\Support\Number`).
///
/// Every method resolves its locale ONCE per call: [locale] when given,
/// otherwise `Lang.current` (a [Locale], read as `Lang.current.toString()`).
/// The resolved tag is verified against intl's own locale table through
/// `Intl.verifiedLocale`, so a locale intl does not ship (`'zz'`, which
/// `NumberFormat` would otherwise throw on) silently falls back to `'en'`
/// instead of crashing inside a `build` method.
abstract final class Number {
  Number._();

  /// Resolves [locale] (or `Lang.current`) to a tag intl recognises,
  /// falling back to `'en'` for anything intl has no data for.
  static String _resolveLocale(String? locale) {
    final String requested = locale ?? Lang.current.toString();
    return Intl.verifiedLocale(
          requested,
          NumberFormat.localeExists,
          onFailure: (_) => 'en',
        ) ??
        'en';
  }

  /// Formats [value] with the locale's grouping and decimal marks.
  ///
  /// [precision] fixes the fraction digits exactly; [maxPrecision] caps them
  /// while allowing fewer; passing neither uses intl's own default. Passing
  /// `grouped: false` drops the thousands separator entirely (no grouping
  /// character is introduced), which is the mode a caller doing its own
  /// magnitude handling (an abbreviated metric, for example) wants.
  ///
  /// ```dart
  /// Number.format(1234567.891, maxPrecision: 3, locale: 'tr'); // '1.234.567,891'
  /// Number.format(1234567.891, maxPrecision: 3, locale: 'en'); // '1,234,567.891'
  /// ```
  static String format(
    num value, {
    int? precision,
    int? maxPrecision,
    bool grouped = true,
    String? locale,
  }) {
    final NumberFormat formatter = NumberFormat.decimalPattern(
      _resolveLocale(locale),
    );
    _applyPrecision(
      formatter,
      precision: precision,
      maxPrecision: maxPrecision,
    );
    if (!grouped) {
      formatter.turnOffGrouping();
    }
    return formatter.format(value);
  }

  /// Formats [amount] as currency in [code], built on
  /// `NumberFormat.simpleCurrency` rather than `NumberFormat.currency`: the
  /// latter renders the bare ISO code with no symbol and no space
  /// (`'TRY1.234,50'`), while `simpleCurrency` resolves the locale's own
  /// symbol (`'₺1.234,50'`). The symbol comes from intl's CLDR data, so it
  /// follows the intl version the app resolves: intl 0.20.2 renders the lira
  /// as `TL`, 0.20.3 and later as `₺`.
  ///
  /// ```dart
  /// Number.currency(1234.5, code: 'TRY', locale: 'tr'); // '₺1.234,50'
  /// Number.currency(1234.5, code: 'USD', locale: 'en'); // '$1,234.50'
  /// ```
  static String currency(
    num amount, {
    String code = 'USD',
    int? precision,
    String? locale,
  }) {
    final NumberFormat formatter = NumberFormat.simpleCurrency(
      locale: _resolveLocale(locale),
      name: code,
    );
    if (precision != null) {
      formatter.minimumFractionDigits = precision;
      formatter.maximumFractionDigits = precision;
    }
    return formatter.format(amount);
  }

  /// Formats [value] as a percentage, taking a 0-100 input like Laravel's
  /// `Number::percentage()` rather than intl's native 0-1 fraction: the
  /// division happens internally so a caller never has to remember to divide
  /// by 100 first, and never gets `%100` for a 99.95% reading.
  ///
  /// [precision] fixes the fraction digits; [maxPrecision] caps them while
  /// allowing fewer.
  ///
  /// ```dart
  /// Number.percentage(99.95, precision: 2, locale: 'tr'); // '%99,95'
  /// Number.percentage(99.95, precision: 2, locale: 'en'); // '99.95%'
  /// ```
  static String percentage(
    num value, {
    int precision = 0,
    int? maxPrecision,
    String? locale,
  }) {
    final NumberFormat formatter = NumberFormat.percentPattern(
      _resolveLocale(locale),
    );
    _applyPrecision(
      formatter,
      precision: precision,
      maxPrecision: maxPrecision,
    );
    return formatter.format(value / 100);
  }

  /// Formats [bytes] as a human-readable file size (B, KB, MB, GB, TB, PB),
  /// stepping by 1024 like Laravel's `Number::fileSize()`. The final number
  /// still goes through [format], so the decimal mark is locale-correct.
  ///
  /// ```dart
  /// Number.fileSize(1536, maxPrecision: 1, locale: 'en'); // '1.5 KB'
  /// ```
  static String fileSize(
    num bytes, {
    int precision = 0,
    int? maxPrecision,
    String? locale,
  }) {
    const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB', 'PB'];

    num size = bytes;
    int unitIndex = 0;
    while (size.abs() / 1024 > 0.9 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    final String formatted = format(
      size,
      precision: precision,
      maxPrecision: maxPrecision,
      locale: locale,
    );
    return '$formatted ${units[unitIndex]}';
  }

  /// Abbreviates [value] with the locale's compact unit letters (`Mn`, `B`
  /// for Turkish; `M`, `K` for English), built on `NumberFormat.compact`.
  ///
  /// ```dart
  /// Number.abbreviate(1500000, maxPrecision: 1, locale: 'tr'); // '1,5 Mn'
  /// Number.abbreviate(1500000, maxPrecision: 1, locale: 'en'); // '1.5M'
  /// ```
  static String abbreviate(
    num value, {
    int precision = 0,
    int? maxPrecision,
    String? locale,
  }) {
    final NumberFormat formatter = NumberFormat.compact(
      locale: _resolveLocale(locale),
    );
    _applyPrecision(
      formatter,
      precision: precision,
      maxPrecision: maxPrecision,
    );
    return formatter.format(value);
  }

  /// Sets [formatter]'s fraction digits from [precision]/[maxPrecision]
  /// following the same rule across every method above: [precision] fixes
  /// minimum and maximum to the same value, [maxPrecision] alone leaves the
  /// minimum at 0 and caps the maximum, and neither leaves intl's default.
  static void _applyPrecision(
    NumberFormat formatter, {
    int? precision,
    int? maxPrecision,
  }) {
    if (maxPrecision != null) {
      formatter.minimumFractionDigits = 0;
      formatter.maximumFractionDigits = maxPrecision;
    } else if (precision != null) {
      formatter.minimumFractionDigits = precision;
      formatter.maximumFractionDigits = precision;
    }
  }
}
