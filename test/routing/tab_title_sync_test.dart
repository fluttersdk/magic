import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/routing/tab_title_sync.dart';

void main() {
  group('resendTitle', () {
    test('writes a different title and then the real one, in that order', () {
      // Blink only tells the browser about a title that CHANGED, so writing the
      // same text again reaches nobody. The detour is what makes the browser
      // re-read the title for the history entry it just swapped in.
      final List<String> written = <String>[];

      resendTitle(read: () => 'Dashboard | Uptizm', write: written.add);

      expect(written, hasLength(2));
      expect(written.first, isNot('Dashboard | Uptizm'));
      expect(written.first, startsWith('Dashboard | Uptizm'));
      expect(written.last, 'Dashboard | Uptizm');
    });

    test('the detour is not whitespace, which Blink trims away', () {
      // `document.title` collapses and strips ASCII whitespace, so a trailing
      // space would leave the title unchanged and the detour a no-op.
      final List<String> written = <String>[];

      resendTitle(read: () => 'Panel', write: written.add);

      expect(written.first.substring('Panel'.length).trim(), isNotEmpty);
    });

    test('an empty title is left alone', () {
      // Nothing to re-send, and writing a lone detour character would give the
      // tab a title that is not empty.
      final List<String> written = <String>[];

      resendTitle(read: () => '', write: written.add);

      expect(written, isEmpty);
    });
  });
}
