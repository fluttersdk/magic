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
        // First code point, not first UTF-16 unit, so an emoji-led word does
        // not yield a lone surrogate (Laravel reads it with mb_substr).
        .map((String word) => String.fromCharCode(word.runes.first))
        .join();

    return capitalize ? upper(result, locale: locale) : result;
  }

  /// Strips [before] from the start of [value] and [after] (default
  /// [before]) from its end, each independently.
  ///
  /// Mirrors Laravel's `Str::unwrap`: a prefix match and a suffix match are
  /// each checked and stripped on their own, so `'"x'` (prefix only) loses
  /// the leading quote and keeps the string unbalanced rather than being
  /// left alone.
  static String unwrap(String value, String before, [String? after]) {
    final String suffix = after ?? before;
    String result = value;

    if (result.startsWith(before)) {
      result = result.substring(before.length);
    }

    if (result.endsWith(suffix)) {
      result = result.substring(0, result.length - suffix.length);
    }

    return result;
  }

  /// [value] with every Latin letter [_latinFolding] covers (Latin-1
  /// Supplement, Latin Extended-A, the Romanian comma-below letters `Ș ș Ț
  /// ț`, `ẞ`, and the Angstrom sign U+212B) folded to its plain ASCII base,
  /// case PRESERVED; every other rune left untouched, including a Latin
  /// letter outside that coverage (Vietnamese and the rest of Latin
  /// Extended-B/Additional) and every other script (Cyrillic, Greek,
  /// Arabic, CJK, ...). Combining marks (U+0300-U+036F) are always dropped,
  /// whatever letter they decorate, so decomposed non-Latin text loses its
  /// marks here too.
  ///
  /// Diverges from Laravel's `Str::ascii`, which transliterates every
  /// script it has a table for: magic folds Latin only, so a search key
  /// built from [ascii] keeps a non-Latin word searchable by its own exact
  /// letters instead of collapsing it to `?` or a phonetic guess.
  static String ascii(String value) {
    final StringBuffer folded = StringBuffer();

    for (final int rune in value.runes) {
      if (rune >= 0x300 && rune <= 0x36F) continue;

      folded.write(_latinFolding[rune] ?? String.fromCharCode(rune));
    }

    return folded.toString();
  }

  /// [value] trimmed, with every run of whitespace collapsed to one space.
  ///
  /// Mirrors Laravel's `Str::squish`: the whitespace class is Dart's `\s`
  /// (every Unicode space separator and line terminator) plus the two
  /// Hangul filler code points (U+3164, U+1160) a rendered blank can carry
  /// without registering as `\s`.
  ///
  /// Trims with the same regex class rather than `String.trim()`, which
  /// follows Unicode's broader `White_Space` property and additionally
  /// strips U+0085 (NEL): a boundary and a middle occurrence of the same
  /// code point must fold the same way, or the two ends of [value] disagree
  /// about what counts as whitespace.
  static String squish(String value) {
    return value
        .replaceAll(_leadingOrTrailingSquishable, '')
        .replaceAll(_squishable, ' ');
  }

  /// The whitespace class [squish] collapses.
  static final RegExp _squishable = RegExp('[\\s\u3164\u1160]+');

  /// [_squishable]'s pattern anchored to either end, for trimming.
  static final RegExp _leadingOrTrailingSquishable = RegExp(
    '^[\\s\u3164\u1160]+|[\\s\u3164\u1160]+\$',
  );

  /// Accented Latin letters (and a handful of Latin letters with no accent
  /// but no ASCII base of their own) to their plain letter, keyed by rune,
  /// case preserved.
  ///
  /// Built from grouped strings rather than entry by entry, so the coverage
  /// of each base letter is readable at a glance and a missing accent is
  /// visible rather than buried in sixty lines of map literal. Covers every
  /// letter in Latin-1 Supplement and Latin Extended-A, plus the Romanian
  /// letters with a comma below (`Ș ș Ț ț`, Latin Extended-B) and `ẞ`
  /// (U+1E9E, capital sharp s). The Angstrom sign (U+212B) is added below
  /// rather than into the `A` group: a font renders it identically to the
  /// `Å` (U+00C5) already there, and the two glyphs side by side in one
  /// string would read as an accidental duplicate.
  static final Map<int, String> _latinFolding =
      _buildFolding(<String, String>{
          'A': 'ÀÁÂÃÄÅĀĂĄ',
          'a': 'àáâãäåāăąª',
          'C': 'ÇĆĈĊČ',
          'c': 'çćĉċč',
          'D': 'ÐĎĐ',
          'd': 'ðďđ',
          'E': 'ÈÉÊËĒĔĖĘĚ',
          'e': 'èéêëēĕėęě',
          'G': 'ĜĞĠĢ',
          'g': 'ĝğġģ',
          'H': 'ĤĦ',
          'h': 'ĥħ',
          'I': 'ÌÍÎÏĨĪĬĮİ',
          'i': 'ìíîïĩīĭįı',
          'J': 'Ĵ',
          'j': 'ĵ',
          'K': 'Ķ',
          'k': 'ķĸ',
          'L': 'ĹĻĽĿŁ',
          'l': 'ĺļľŀł',
          'N': 'ÑŃŅŇŊ',
          'n': 'ñńņňŉŋ',
          'O': 'ÒÓÔÕÖØŌŎŐ',
          'o': 'òóôõöøōŏőº',
          'R': 'ŔŖŘ',
          'r': 'ŕŗř',
          'S': 'ŚŜŞŠȘ',
          's': 'śŝşšſș',
          'T': 'ŢŤŦȚ',
          't': 'ţťŧț',
          'U': 'ÙÚÛÜŨŪŬŮŰŲ',
          'u': 'ùúûüũūŭůűųµ',
          'W': 'Ŵ',
          'w': 'ŵ',
          'Y': 'ÝŶŸ',
          'y': 'ýÿŷ',
          'Z': 'ŹŻŽ',
          'z': 'źżž',
          'AE': 'ÆǼ',
          'ae': 'æǽ',
          'OE': 'Œ',
          'oe': 'œ',
          'SS': 'ẞ',
          'ss': 'ß',
          'TH': 'Þ',
          'th': 'þ',
          // The two ligatures, the only entries whose base is two letters and so
          // the only ones that cannot join a group above. The kra, the eng and
          // the long s were missing for the same reason and are folded into `k`,
          // `N`/`n` and `s` rather than added here: a repeated key in a Dart map
          // literal takes the LAST value, so a fresh `'n': 'ŋ'` would have
          // silently replaced the five accented n's above it.
          'IJ': 'Ĳ',
          'ij': 'ĳ',
        })
        // The Angstrom sign (U+212B): canonically equivalent to Å but a
        // distinct code point, kept out of the `A` group string above (see
        // the doc comment) because a font renders the two identically.
        ..[0x212B] = 'A';

  /// Inverts the grouped folding table into a rune-keyed lookup.
  static Map<int, String> _buildFolding(Map<String, String> groups) {
    final Map<int, String> table = <int, String>{};

    groups.forEach((String base, String accented) {
      for (final int rune in accented.runes) {
        table[rune] = base;
      }
    });

    return table;
  }
}
