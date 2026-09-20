/// Picks one segment of a pipe-separated translation line for a count.
///
/// A direct port of Laravel's `Illuminate\Translation\MessageSelector`, so a
/// catalogue written for a Laravel backend renders the same sentences here.
/// Two shapes are supported and they compose in one line:
///
/// ```
/// There is one apple|There are many apples
/// {0} There are none|[1,19] There are some|[20,*] There are many
/// ```
///
/// The inline conditions are tried first, in order, and the first that matches
/// the count wins. When none does, the conditions are stripped and the
/// remaining segments are read positionally by [pluralIndexFor].
///
/// **The plural rules are per language and they are not all `n == 1`.** Turkish
/// and fourteen others have a single form, so their second segment is never
/// reached. French counts zero as singular. Russian has three forms and Arabic
/// six. Writing a two-segment line and assuming English is exactly the mistake
/// this class exists to make visible: it answers the language's own index and
/// falls back to segment 0 when the line is too short to carry it.
///
/// The table below is derived from Laravel's own, which carries this notice:
/// "The plural rules are derived from code of the Zend Framework
/// (2010-09-25), which is subject to the new BSD license
/// (https://framework.zend.com/license), Copyright (c) 2005-2010 Zend
/// Technologies USA Inc."
abstract final class MessageSelector {
  /// Selects the segment of [line] that suits [number] in [locale].
  ///
  /// [locale] is a language code, with or without a region: `tr`, `tr_TR` and
  /// `tr-TR` all resolve to Turkish.
  static String choose(String line, int number, String locale) {
    final segments = line.split('|');

    final explicit = _extract(segments, number);
    if (explicit != null) return explicit.trim();

    final stripped = segments.map(_stripCondition).toList();
    final index = pluralIndexFor(locale, number);

    if (stripped.length == 1 || index >= stripped.length) return stripped[0];

    return stripped[index];
  }

  /// The first segment whose inline condition matches [number], or null.
  static String? _extract(List<String> segments, int number) {
    for (final part in segments) {
      final value = _extractFromString(part, number);
      if (value != null) return value;
    }

    return null;
  }

  /// `{0} none` and `[1,19] some`, matched against [number].
  ///
  /// The range form accepts `*` on either bound, so `[5,*]` is five or more
  /// and `[*,4]` is four or fewer. A bound that is not a number makes the
  /// segment unconditional rather than throwing: a catalogue is data, and a
  /// typo in one must not crash the screen rendering it.
  static String? _extractFromString(String part, int number) {
    final match = _condition.firstMatch(part);
    if (match == null) return null;

    final condition = match.group(1)!;
    final value = match.group(2)!;

    if (condition.contains(',')) {
      final bounds = condition.split(',');
      final from = bounds.first.trim();
      final to = bounds.skip(1).join(',').trim();

      if (to == '*') {
        final lower = int.tryParse(from);

        return lower != null && number >= lower ? value : null;
      }

      if (from == '*') {
        final upper = int.tryParse(to);

        return upper != null && number <= upper ? value : null;
      }

      final lower = int.tryParse(from);
      final upper = int.tryParse(to);

      if (lower == null || upper == null) return null;

      return number >= lower && number <= upper ? value : null;
    }

    return int.tryParse(condition.trim()) == number ? value : null;
  }

  /// Removes a leading `{...}` or `[...]` from a segment.
  static String _stripCondition(String part) =>
      part.replaceFirst(_leadingCondition, '');

  /// Which segment [locale] uses for [number], zero-based.
  ///
  /// An unlisted language answers 0, which is Laravel's own `default` and
  /// reads as "this language does not agree with its number" rather than as
  /// English.
  static int pluralIndexFor(String locale, int number) {
    final language = locale.split(RegExp('[_-]')).first.toLowerCase();

    for (final rule in _rules) {
      if (rule.languages.contains(language)) return rule.index(number);
    }

    return 0;
  }

  /// `{0}` or `[1,19]` at the start of a segment, with the rest captured.
  static final RegExp _condition = RegExp(
    r'^[{\[]([^\[\]{}]*)[}\]](.*)',
    dotAll: true,
  );

  /// The same prefix, for stripping.
  static final RegExp _leadingCondition = RegExp(r'^[{\[]([^\[\]{}]*)[}\]]');

  /// Laravel's `getPluralIndex` switch, one entry per `return`.
  ///
  /// The language sets are extracted from the PHP source rather than typed
  /// out: the original lists 280 locale strings across 15 groups, and one
  /// mistyped code is a language that silently renders the wrong sentence.
  static final List<_PluralRule> _rules = <_PluralRule>[
    _PluralRule(<String>{
      'az',
      'bo',
      'dz',
      'id',
      'ja',
      'jv',
      'ka',
      'km',
      'kn',
      'ko',
      'ms',
      'th',
      'tr',
      'vi',
      'zh',
    }, (int n) => 0),
    _PluralRule(<String>{
      'af',
      'bg',
      'bn',
      'ca',
      'da',
      'de',
      'el',
      'en',
      'eo',
      'es',
      'et',
      'eu',
      'fa',
      'fi',
      'fo',
      'fur',
      'fy',
      'gl',
      'gu',
      'ha',
      'he',
      'hu',
      'is',
      'it',
      'ku',
      'lb',
      'ml',
      'mn',
      'mr',
      'nah',
      'nb',
      'ne',
      'nl',
      'nn',
      'no',
      'om',
      'or',
      'pa',
      'pap',
      'ps',
      'pt',
      'so',
      'sq',
      'sv',
      'sw',
      'ta',
      'te',
      'tk',
      'ur',
      'zu',
    }, (int n) => n == 1 ? 0 : 1),
    _PluralRule(<String>{
      'am',
      'bh',
      'fil',
      'fr',
      'gun',
      'hi',
      'hy',
      'ln',
      'mg',
      'nso',
      'ti',
      'wa',
      'xbr',
    }, (int n) => n == 0 || n == 1 ? 0 : 1),
    _PluralRule(<String>{'be', 'bs', 'hr', 'ru', 'sr', 'uk'}, (int n) {
      if (n % 10 == 1 && n % 100 != 11) return 0;
      if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
        return 1;
      }

      return 2;
    }),
    _PluralRule(<String>{'cs', 'sk'}, (int n) {
      if (n == 1) return 0;

      return n >= 2 && n <= 4 ? 1 : 2;
    }),
    _PluralRule(<String>{'ga'}, (int n) {
      if (n == 1) return 0;

      return n == 2 ? 1 : 2;
    }),
    _PluralRule(<String>{'lt'}, (int n) {
      if (n % 10 == 1 && n % 100 != 11) return 0;
      if (n % 10 >= 2 && (n % 100 < 10 || n % 100 >= 20)) return 1;

      return 2;
    }),
    _PluralRule(<String>{'sl'}, (int n) {
      if (n % 100 == 1) return 0;
      if (n % 100 == 2) return 1;

      return n % 100 == 3 || n % 100 == 4 ? 2 : 3;
    }),
    _PluralRule(<String>{'mk'}, (int n) => n % 10 == 1 ? 0 : 1),
    _PluralRule(<String>{'mt'}, (int n) {
      if (n == 1) return 0;
      if (n == 0 || (n % 100 > 1 && n % 100 < 11)) return 1;

      return n % 100 > 10 && n % 100 < 20 ? 2 : 3;
    }),
    _PluralRule(<String>{'lv'}, (int n) {
      if (n == 0) return 0;

      return n % 10 == 1 && n % 100 != 11 ? 1 : 2;
    }),
    _PluralRule(<String>{'pl'}, (int n) {
      if (n == 1) return 0;

      return n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 12 || n % 100 > 14)
          ? 1
          : 2;
    }),
    _PluralRule(<String>{'cy'}, (int n) {
      if (n == 1) return 0;
      if (n == 2) return 1;

      return n == 8 || n == 11 ? 2 : 3;
    }),
    _PluralRule(<String>{'ro'}, (int n) {
      if (n == 1) return 0;

      return n == 0 || (n % 100 > 0 && n % 100 < 20) ? 1 : 2;
    }),
    _PluralRule(<String>{'ar'}, (int n) {
      if (n == 0) return 0;
      if (n == 1) return 1;
      if (n == 2) return 2;
      if (n % 100 >= 3 && n % 100 <= 10) return 3;

      return n % 100 >= 11 && n % 100 <= 99 ? 4 : 5;
    }),
  ];
}

/// One group of languages and the segment index they share.
class _PluralRule {
  _PluralRule(this.languages, this.index);

  /// Language codes, region stripped.
  final Set<String> languages;

  /// Which segment a count selects.
  final int Function(int) index;
}
