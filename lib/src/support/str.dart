import '../facades/lang.dart';

/// Locale-aware string casing and initials, Laravel's `Str` helper ported to
/// the subset magic needs.
///
/// `String.toUpperCase()`/`toLowerCase()` are locale-independent and get
/// Turkish and Azerbaijani wrong: their alphabet distinguishes a dotted `i`
/// from a dotless `ı`, a pair Dart's mapping conflates. Every method here
/// defaults its locale to [Lang.current.languageCode].
abstract final class Str {
  /// Language codes whose alphabet distinguishes a dotted from a dotless `i`.
  static const Set<String> _dottedILanguages = <String>{'tr', 'az'};

  /// Uppercases [value] under [locale] (default: [Lang.current]).
  ///
  /// In `tr`/`az`, `i` is mapped to `İ` and `ı` to `I` before the general
  /// uppercase call; every other letter (`ş`, `ğ`, `ö`, `ü`, `ç`) casts
  /// correctly on its own.
  static String upper(String value, {String? locale}) {
    if (!_usesDottedI(locale)) return value.toUpperCase();

    return value.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
  }

  /// Lowercases [value] under [locale] (default: [Lang.current]).
  ///
  /// `İ` is mapped to a plain `i` first in EVERY locale, not only `tr`/`az`:
  /// on the web the JS engine lowercases `İ` to `i` plus a combining dot
  /// (U+0307), which is invisible but changes the string's length. In
  /// `tr`/`az`, `I` is additionally mapped to `ı` before the general
  /// lowercase call, and that swap has to run AFTER the `İ` swap and BEFORE
  /// `toLowerCase()`: reversing either order turns `İ` into `ı` instead of
  /// `i`, or leaves `I` indistinguishable from an `i` that never needed
  /// correcting.
  static String lower(String value, {String? locale}) {
    String prepared = value.replaceAll('İ', 'i');
    if (_usesDottedI(locale)) {
      prepared = prepared.replaceAll('I', 'ı');
    }

    return prepared.toLowerCase();
  }

  /// Whether [locale] (a language code or a full tag such as `tr_TR` or
  /// `tr-TR`; default [Lang.current]) belongs to a dotted-i language.
  static bool _usesDottedI(String? locale) {
    final String tag = locale ?? Lang.current.languageCode;

    return _dottedILanguages.contains(tag.split(RegExp('[_-]')).first);
  }

  /// The first letter of each whitespace-separated word in [value].
  ///
  /// Mirrors Laravel's `Str::initials($value, $capitalize)`: [limit] (when
  /// greater than 0, an addition Laravel has no equivalent for) keeps only
  /// the first [limit] words, and [capitalize] uppercases the result through
  /// [upper] under [locale]. An empty or null [value] returns `''`.
  static String initials(
    String? value, {
    int limit = 0,
    bool capitalize = false,
    String? locale,
  }) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return '';

    List<String> words = trimmed.split(RegExp(r'\s+'));
    if (limit > 0 && words.length > limit) {
      words = words.sublist(0, limit);
    }

    final String result = words
        .where((String word) => word.isNotEmpty)
        .map((String word) => word[0])
        .join();

    return capitalize ? upper(result, locale: locale) : result;
  }
}
