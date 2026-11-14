import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/cli/helpers/unified_diff.dart';

const String _source = 'lib/main.dart (existing)';
const String _target = 'lib/main.dart (Magic template)';

/// Builds a 30-line document, replacing the 1-based [replaced] lines.
String _document(Map<int, String> replaced) {
  final lines = List<String>.generate(
    30,
    (index) => replaced[index + 1] ?? 'line ${index + 1}',
  );

  return '${lines.join('\n')}\n';
}

String _diff(String existing, String template) => UnifiedDiff.format(
  existing,
  template,
  sourceLabel: _source,
  targetLabel: _target,
);

void main() {
  group('UnifiedDiff.format', () {
    test('two distant changes produce two hunks with 3 lines of context', () {
      final diff = _diff(
        _document({}),
        _document({3: 'CHANGED 3', 25: 'CHANGED 25'}),
      );

      expect(
        diff,
        [
          '--- lib/main.dart (existing)',
          '+++ lib/main.dart (Magic template)',
          '@@ -1,6 +1,6 @@',
          ' line 1',
          ' line 2',
          '-line 3',
          '+CHANGED 3',
          ' line 4',
          ' line 5',
          ' line 6',
          '@@ -22,7 +22,7 @@',
          ' line 22',
          ' line 23',
          ' line 24',
          '-line 25',
          '+CHANGED 25',
          ' line 26',
          ' line 27',
          ' line 28',
        ].join('\n'),
      );
    });

    test('identical inputs still emit the two label lines and no hunks', () {
      final diff = _diff('a\nb\n', 'a\nb\n');

      expect(
        diff,
        '--- lib/main.dart (existing)\n+++ lib/main.dart (Magic template)',
      );
    });

    test('a range of length 1 has no comma', () {
      final diff = _diff('a\n', 'b\n');

      expect(diff, contains('@@ -1 +1 @@'));
    });

    test('a replaced line grows into a multi-line target range', () {
      final diff = _diff(
        'void main() { runApp(const MyApp()); }\n',
        "import 'package:magic/magic.dart';\n"
            'void main() async { await Magic.init(); }\n',
      );

      expect(
        diff,
        [
          '--- lib/main.dart (existing)',
          '+++ lib/main.dart (Magic template)',
          '@@ -1 +1,2 @@',
          '-void main() { runApp(const MyApp()); }',
          "+import 'package:magic/magic.dart';",
          '+void main() async { await Magic.init(); }',
        ].join('\n'),
      );
    });

    test('an empty source prints a zero-length range as 0,0', () {
      final diff = _diff('', 'x\ny\n');

      expect(
        diff,
        [
          '--- lib/main.dart (existing)',
          '+++ lib/main.dart (Magic template)',
          '@@ -0,0 +1,2 @@',
          '+x',
          '+y',
        ].join('\n'),
      );
    });

    test('an empty target prints a zero-length range as 0,0', () {
      final diff = _diff('x\ny\n', '');

      expect(
        diff,
        [
          '--- lib/main.dart (existing)',
          '+++ lib/main.dart (Magic template)',
          '@@ -1,2 +0,0 @@',
          '-x',
          '-y',
        ].join('\n'),
      );
    });

    test('changes 6 unchanged lines apart share one hunk', () {
      final diff = _diff(_document({3: 'C3', 10: 'C10'}), _document({}));

      expect('@@'.allMatches(diff).length, 2, reason: 'one header pair');
      expect(diff, contains('@@ -1,13 +1,13 @@'));
    });

    test('changes 7 unchanged lines apart split into two hunks', () {
      final diff = _diff(_document({3: 'C3', 11: 'C11'}), _document({}));

      expect('@@'.allMatches(diff).length, 4, reason: 'two header pairs');
      expect(diff, contains('@@ -1,6 +1,6 @@'));
      expect(diff, contains('@@ -8,7 +8,7 @@'));
    });
  });
}
