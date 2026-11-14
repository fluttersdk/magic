import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/cli/magic_dowel_provider.dart';

void main() {
  group('MagicDowelProvider', () {
    test('leaves the database generators to magic_local_storage', () {
      // dowel exits on a command-name collision, so core registering any of
      // these would break every app that installs the plugin.
      final names = MagicDowelProvider().commands().map((c) => c.name);

      expect(names, isNot(contains('make:migration')));
      expect(names, isNot(contains('make:seeder')));
      expect(names, isNot(contains('make:factory')));
    });
  });
}
