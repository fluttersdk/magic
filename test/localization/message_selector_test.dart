import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/localization/message_selector.dart';

/// The pipe-separated plural line, ported from Laravel's `MessageSelector`.
///
/// Every expectation here is Laravel's documented behaviour rather than an
/// opinion about English: the point of the port is that a consumer moving a
/// catalogue across writes the same strings and gets the same sentences.
void main() {
  group('inline conditions win over the plural index', () {
    test('an exact condition selects its own segment', () {
      const line =
          '{0} There are none|[1,19] There are some|[20,*] There are many';

      expect(MessageSelector.choose(line, 0, 'en'), 'There are none');
      expect(MessageSelector.choose(line, 5, 'en'), 'There are some');
      expect(MessageSelector.choose(line, 19, 'en'), 'There are some');
      expect(MessageSelector.choose(line, 20, 'en'), 'There are many');
      expect(MessageSelector.choose(line, 2000, 'en'), 'There are many');
    });

    test('a star on the left bound matches everything below the right', () {
      expect(MessageSelector.choose('[*,4] few|[5,*] many', 1, 'en'), 'few');
      expect(MessageSelector.choose('[*,4] few|[5,*] many', 9, 'en'), 'many');
    });

    test('the selected segment is trimmed, as Laravel trims it', () {
      expect(MessageSelector.choose('{1}   one   |{2}   two', 1, 'en'), 'one');
    });

    test(
      'a line whose conditions match nothing falls through to the index',
      () {
        // Not an error and not an empty string: the conditions are stripped and
        // what is left is read positionally.
        //
        // **A half-conditional line therefore shifts its own segments**, which
        // is a trap rather than a feature and is pinned here because Laravel
        // does the same. `{0} none` becomes segment 0 with its condition
        // removed, so English's singular index lands on it at a count of one
        // and the intended singular has moved to index 1, where a count of
        // seven finds it. Write a line that is all conditions or none.
        //
        // The leading space survives too: `choose` trims only the branch that
        // matched a condition, so the stripped segment keeps the space that
        // separated `{0}` from its text.
        expect(MessageSelector.choose('{0} none|one|many', 1, 'en'), ' none');
        expect(MessageSelector.choose('{0} none|one|many', 7, 'en'), 'one');
      },
    );
  });

  group('the plural index, by language', () {
    test(
      'English takes the singular at one and the plural everywhere else',
      () {
        const line = 'one apple|many apples';

        expect(MessageSelector.choose(line, 1, 'en'), 'one apple');
        expect(MessageSelector.choose(line, 0, 'en'), 'many apples');
        expect(MessageSelector.choose(line, 2, 'en'), 'many apples');
      },
    );

    test('Turkish has one form, so every count takes the first segment', () {
      // The case this port exists for. Laravel puts `tr` in the index-0 group
      // beside `ja`, `ko`, `zh` and eleven more: the language does not agree
      // with its number, so a second segment is never reached.
      const line = ':count kanal|:count kanallar';

      expect(MessageSelector.choose(line, 1, 'tr'), ':count kanal');
      expect(MessageSelector.choose(line, 9, 'tr'), ':count kanal');
    });

    test('French counts zero as singular', () {
      const line = 'un pomme|beaucoup de pommes';

      expect(MessageSelector.choose(line, 0, 'fr'), 'un pomme');
      expect(MessageSelector.choose(line, 1, 'fr'), 'un pomme');
      expect(MessageSelector.choose(line, 2, 'fr'), 'beaucoup de pommes');
    });

    test('Russian picks one of three by the last digit', () {
      const line = 'one|few|many';

      expect(MessageSelector.choose(line, 1, 'ru'), 'one');
      expect(MessageSelector.choose(line, 21, 'ru'), 'one');
      expect(MessageSelector.choose(line, 11, 'ru'), 'many');
      expect(MessageSelector.choose(line, 3, 'ru'), 'few');
      expect(MessageSelector.choose(line, 5, 'ru'), 'many');
    });

    test('Arabic picks one of six', () {
      const line = 'zero|one|two|few|many|other';

      expect(MessageSelector.choose(line, 0, 'ar'), 'zero');
      expect(MessageSelector.choose(line, 1, 'ar'), 'one');
      expect(MessageSelector.choose(line, 2, 'ar'), 'two');
      expect(MessageSelector.choose(line, 5, 'ar'), 'few');
      expect(MessageSelector.choose(line, 15, 'ar'), 'many');
      expect(MessageSelector.choose(line, 100, 'ar'), 'other');
    });

    test('a region suffix resolves to its language', () {
      expect(MessageSelector.choose('one|many', 1, 'pt_BR'), 'one');
      expect(MessageSelector.choose('one|many', 9, 'tr_TR'), 'one');
    });

    test('an unknown language takes the first segment, as Laravel does', () {
      // Laravel's `default:` returns 0 rather than the English rule, so an
      // unlisted language reads as "no agreement" rather than as English.
      expect(MessageSelector.choose('one|many', 9, 'xx'), 'one');
    });
  });

  group('lines the selector must not break on', () {
    test('a line with no pipe is returned whole', () {
      expect(
        MessageSelector.choose('just one sentence', 5, 'en'),
        'just one sentence',
      );
    });

    test('a count past the last segment falls back to the first', () {
      // Russian has three forms and this line has two, so index 2 does not
      // exist. Laravel answers segment 0 rather than throwing, and a
      // RangeError here would be a crash in a consumer's UI.
      expect(MessageSelector.choose('one|few', 5, 'ru'), 'one');
    });

    test('an empty line stays empty', () {
      expect(MessageSelector.choose('', 1, 'en'), '');
    });
  });
}
