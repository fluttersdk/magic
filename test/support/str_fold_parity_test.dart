import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/support/str.dart';

/// A verbatim copy of the app-side search fold that [Str.ascii] +
/// [Str.squish] were extracted from, kept here only as the parity oracle: an
/// app that stored search keys folded by it must be able to tell exactly
/// which inputs now fold differently. The copy is intentionally NOT
/// refactored to match this file's own style, so a diff against the original
/// stays trivial.
abstract final class _OldFold {
  static final RegExp _turkishI = RegExp('[İIı]');

  static const Map<String, String> _accented = <String, String>{
    'a': 'àáâãäåāăą',
    'ae': 'æ',
    'c': 'çćĉċč',
    'd': 'ďđ',
    'e': 'èéêëēĕėęě',
    'g': 'ĝğġģ',
    'h': 'ĥħ',
    'i': 'ìíîïĩīĭį',
    'j': 'ĵ',
    'k': 'ķ',
    'l': 'ĺļľŀł',
    'n': 'ñńņň',
    'o': 'òóôõöøōŏő',
    'oe': 'œ',
    'r': 'ŕŗř',
    's': 'śŝşšș',
    'ss': 'ß',
    't': 'ţťŧț',
    'u': 'ùúûüũūŭůűų',
    'w': 'ŵ',
    'y': 'ýÿŷ',
    'z': 'źżž',
  };

  static final Map<int, String> _plain = <int, String>{
    for (final MapEntry<String, String> group in _accented.entries)
      for (final int rune in group.value.runes) rune: group.key,
  };

  static String fold(String value) {
    final String lower = value.replaceAll(_turkishI, 'i').toLowerCase();
    final StringBuffer folded = StringBuffer();
    bool pendingSpace = false;

    for (final int rune in lower.runes) {
      if (_isSpace(rune)) {
        pendingSpace = folded.isNotEmpty;
        continue;
      }

      // U+0300 to U+036F: a decomposed accent, or the dot `toLowerCase` hangs
      // on an `i` it was handed as `İ` from somewhere other than [_turkishI].
      if (rune >= 0x300 && rune <= 0x36F) continue;

      if (pendingSpace) {
        folded.write(' ');
        pendingSpace = false;
      }

      folded.write(_plain[rune] ?? String.fromCharCode(rune));
    }

    return folded.toString();
  }

  static bool _isSpace(int rune) =>
      rune == 0x20 || rune == 0xA0 || (rune >= 0x09 && rune <= 0x0D);
}

/// Whitespace-class code points where [Str.ascii] and [Str.squish] together
/// treat the rune as space (Dart's `\s` regex class, plus the two Hangul
/// filler additions [Str.squish] documents) while [_OldFold]'s narrow
/// `_isSpace` (0x20, 0xA0, 0x09-0x0D only, built for a search index over a
/// Turkish/Western-European catalogue) leaves it as a literal, lowercased
/// character. Intended: `Str` uses Unicode's actual space-separator and
/// line-terminator set, matching Laravel's own `squish`.
const Set<int> _whitespaceDivergence = <int>{
  0x1680,
  0x2000,
  0x2001,
  0x2002,
  0x2003,
  0x2004,
  0x2005,
  0x2006,
  0x2007,
  0x2008,
  0x2009,
  0x200A,
  0x2028,
  0x2029,
  0x202F,
  0x205F,
  0x3000,
  0xFEFF,
  0x3164,
  0x1160,
};

/// Letters only `Str`'s own folding table (`_latinFolding` in
/// `lib/src/support/str.dart`) carries; [_OldFold]'s `_accented` table, built
/// for a Turkish/Western-European catalogue, has no entry for any of them and
/// leaves each as a lowercased literal.
const Set<int> _extraLetterDivergence = <int>{
  0x00AA, // ª feminine ordinal indicator
  0x00B5, // µ micro sign
  0x00BA, // º masculine ordinal indicator
  0x00D0, // Ð capital eth
  0x00DE, // Þ capital thorn
  0x00F0, // ð small eth
  0x00FE, // þ small thorn
  0x0132, // Ĳ capital ligature IJ
  0x0133, // ĳ small ligature ij
  0x0138, // ĸ small kra
  0x0149, // ŉ small n preceded by apostrophe
  0x014A, // Ŋ capital eng
  0x014B, // ŋ small eng
  0x017F, // ſ small long s
  0x01FC, // Ǽ capital AE with acute
  0x01FD, // ǽ small ae with acute
};

/// The union of both allow-listed divergence classes: a rune here is exempt
/// from the parity assertion, everything else must match [_OldFold] exactly.
final Set<int> _allowedDivergence = _whitespaceDivergence.union(
  _extraLetterDivergence,
);

void main() {
  test('Str.squish(Str.ascii(s)).toLowerCase() matches the old fold '
      'for every BMP code point, outside the allow-listed divergences', () {
    final List<String> unexpected = <String>[];

    // A plain loop over the whole BMP rather than per-codepoint `test()`
    // registration, so 65 thousand-odd cases stay one fast assertion
    // instead of 65 thousand slow ones.
    for (int rune = 0x0000; rune <= 0xFFFF; rune++) {
      // Lone surrogate halves are not valid standalone code points.
      if (rune >= 0xD800 && rune <= 0xDFFF) continue;

      final String c = String.fromCharCode(rune);

      for (final String subject in <String>[c, 'a${c}b', ' $c ']) {
        final String actual = Str.squish(Str.ascii(subject)).toLowerCase();
        final String expected = _OldFold.fold(subject);

        if (actual == expected) continue;
        if (_allowedDivergence.contains(rune)) continue;

        unexpected.add(
          'U+${rune.toRadixString(16).toUpperCase().padLeft(4, '0')} '
          '(subject: ${subject == c
              ? 'alone'
              : subject == 'a${c}b'
              ? 'a_b'
              : '_ _'}): '
          'got `$actual`, old fold gave `$expected`',
        );
      }
    }

    expect(
      unexpected,
      isEmpty,
      reason:
          'divergence outside the two allow-listed classes '
          '(unexpected count: ${unexpected.length})',
    );
  });
}
