import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/cli/magic_artisan_provider.dart';
import 'package:path/path.dart' as p;

/// Matches a stated generator count next to the phrase it is documented in,
/// e.g. `20 make:* generators` or `` 20 `make:*` scaffold commands ``.
///
/// Backticks around `make:*` are optional so the same pattern matches plain
/// prose and Markdown code-span formatting alike.
final RegExp _countPhrase = RegExp(
  r'(\d+)\s*`?make:\*`?\s*(?:generators|scaffold commands)',
);

/// `flutter test` runs with the package root as the working directory, so
/// [Directory.current] is the reliable resolution mechanism (mirrors
/// `test/cli/commands/magic_install_command_test.dart`'s `_magicRoot`).
String get _repoRoot => Directory.current.path;

/// Reads [relativePath] (relative to the package root) as a string.
String _read(String relativePath) =>
    File(p.join(_repoRoot, relativePath)).readAsStringSync();

/// Extracts the single generator count [_countPhrase] finds in [content],
/// failing loudly (rather than silently passing on zero matches) when the
/// phrase is missing or stated more than once.
int _statedCount(String content, String label) {
  final matches = _countPhrase.allMatches(content).toList();
  expect(
    matches,
    hasLength(1),
    reason:
        '$label should state the make:* generator count exactly once, '
        'matching "<N> make:* generators" or "<N> `make:*` scaffold commands".',
  );
  return int.parse(matches.single.group(1)!);
}

void main() {
  group('make:* generator count parity', () {
    late int actualCount;

    setUpAll(() {
      final commands = MagicArtisanProvider().commands();
      actualCount = commands.where((c) => c.name.startsWith('make:')).length;
    });

    test('the provider registers at least one make:* command', () {
      expect(actualCount, greaterThan(0));
    });

    test('README.md states the current make:* generator count', () {
      final stated = _statedCount(_read('README.md'), 'README.md');
      expect(stated, actualCount);
    });

    test(
      'doc/packages/magic-cli.md states the current make:* generator count',
      () {
        final stated = _statedCount(
          _read('doc/packages/magic-cli.md'),
          'doc/packages/magic-cli.md',
        );
        expect(stated, actualCount);
      },
    );

    test('the MagicArtisanProvider docblock states the current make:* '
        'generator count', () {
      final stated = _statedCount(
        _read('lib/src/cli/magic_artisan_provider.dart'),
        'lib/src/cli/magic_artisan_provider.dart',
      );
      expect(stated, actualCount);
    });
  });
}
