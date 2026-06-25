import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/cli/commands/make_component_command.dart';
import 'package:path/path.dart' as p;

/// A bare [ArtisanContext] driving the command with [args].
ArtisanContext _ctx(MakeComponentCommand cmd, List<String> args) {
  final parser = ArgParser();
  cmd.configure(parser);
  final input = ArgvInput.parse(parser, args);
  return ArtisanContext.bare(input, BufferedOutput());
}

void main() {
  group('MakeComponentCommand metadata', () {
    final cmd = MakeComponentCommand();

    test('declares name make:component', () {
      expect(cmd.name, 'make:component');
    });

    test('extends ArtisanGeneratorCommand', () {
      expect(cmd, isA<ArtisanGeneratorCommand>());
    });

    test('declares CommandBoot.none', () {
      expect(cmd.boot, CommandBoot.none);
    });
  });

  group('MakeComponentCommand.handle()', () {
    late Directory projectRoot;
    late String stubsDir;

    setUp(() {
      projectRoot = Directory.systemTemp.createTempSync('make_component_');
      // The real stubs ship in magic's assets/stubs/; point the generator at
      // them via the env override the StubLoader honours.
      stubsDir = p.join(Directory.current.path, 'assets', 'stubs');
    });

    tearDown(() {
      if (projectRoot.existsSync()) projectRoot.deleteSync(recursive: true);
    });

    test('scaffolds the 4-file atomic component folder', () async {
      final cmd = MakeComponentCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        _ctx(cmd, <String>['Avatar', '--stubs-dir=$stubsDir']),
      );

      expect(code, 0);
      final dir = p.join(projectRoot.path, 'lib', 'ui', 'components', 'avatar');
      expect(File(p.join(dir, 'avatar.dart')).existsSync(), isTrue);
      expect(File(p.join(dir, 'avatar.recipe.dart')).existsSync(), isTrue);
      expect(File(p.join(dir, 'avatar.preview.dart')).existsSync(), isTrue);
      expect(File(p.join(dir, 'index.dart')).existsSync(), isTrue);
    });

    test('names the component class unprefixed PascalCase', () async {
      final cmd = MakeComponentCommand(testRoot: projectRoot.path);
      await cmd.handle(_ctx(cmd, <String>['Avatar', '--stubs-dir=$stubsDir']));

      final component = File(
        p.join(
          projectRoot.path,
          'lib',
          'ui',
          'components',
          'avatar',
          'avatar.dart',
        ),
      ).readAsStringSync();
      expect(component, contains('class Avatar'));

      final preview = File(
        p.join(
          projectRoot.path,
          'lib',
          'ui',
          'components',
          'avatar',
          'avatar.preview.dart',
        ),
      ).readAsStringSync();
      expect(preview, contains('class AvatarPreview'));
    });

    test('emits the requested variant axes into the recipe', () async {
      final cmd = MakeComponentCommand(testRoot: projectRoot.path);
      await cmd.handle(
        _ctx(cmd, <String>[
          'Avatar',
          '--variants=intent,size',
          '--stubs-dir=$stubsDir',
        ]),
      );

      final recipe = File(
        p.join(
          projectRoot.path,
          'lib',
          'ui',
          'components',
          'avatar',
          'avatar.recipe.dart',
        ),
      ).readAsStringSync();
      expect(recipe, contains("'intent':"));
      expect(recipe, contains("'size':"));
    });

    test('the index re-exports the component but not the preview', () async {
      final cmd = MakeComponentCommand(testRoot: projectRoot.path);
      await cmd.handle(_ctx(cmd, <String>['Avatar', '--stubs-dir=$stubsDir']));

      final index = File(
        p.join(
          projectRoot.path,
          'lib',
          'ui',
          'components',
          'avatar',
          'index.dart',
        ),
      ).readAsStringSync();
      expect(index, contains("export 'avatar.dart'"));
      expect(index, contains("export 'avatar.recipe.dart'"));
      expect(index, isNot(contains("export 'avatar.preview.dart'")));
    });

    test('returns 1 when the name argument is missing', () async {
      final cmd = MakeComponentCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        _ctx(cmd, <String>['--stubs-dir=$stubsDir']),
      );
      expect(code, 1);
    });

    test(
      'returns 1 when the component already exists without --force',
      () async {
        final cmd = MakeComponentCommand(testRoot: projectRoot.path);
        await cmd.handle(
          _ctx(cmd, <String>['Avatar', '--stubs-dir=$stubsDir']),
        );

        final second = MakeComponentCommand(testRoot: projectRoot.path);
        final code = await second.handle(
          _ctx(second, <String>['Avatar', '--stubs-dir=$stubsDir']),
        );
        expect(code, 1);
      },
    );

    test('--slots scaffolds a WindSlotRecipe shape', () async {
      final cmd = MakeComponentCommand(testRoot: projectRoot.path);
      await cmd.handle(
        _ctx(cmd, <String>['Avatar', '--slots', '--stubs-dir=$stubsDir']),
      );

      final recipe = File(
        p.join(
          projectRoot.path,
          'lib',
          'ui',
          'components',
          'avatar',
          'avatar.recipe.dart',
        ),
      ).readAsStringSync();
      expect(recipe, contains('WindSlotRecipe'));
      expect(recipe, contains("slots: {"));

      final component = File(
        p.join(
          projectRoot.path,
          'lib',
          'ui',
          'components',
          'avatar',
          'avatar.dart',
        ),
      ).readAsStringSync();
      expect(component, contains("slots['root']"));
    });

    test('triggers previews:refresh after scaffolding', () async {
      // Seed an existing preview so the chained refresh has something to emit.
      final existing = Directory(p.join(projectRoot.path, 'lib'))
        ..createSync(recursive: true);
      File(p.join(existing.path, 'seed.preview.dart')).writeAsStringSync('''
import 'package:flutter/widgets.dart';

class SeedPreview extends StatelessWidget {
  const SeedPreview({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
''');

      final cmd = MakeComponentCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        _ctx(cmd, <String>['Avatar', '--stubs-dir=$stubsDir']),
      );

      expect(code, 0);
      // The chained previews:refresh regenerated the index for lib/.
      final generated = File(
        p.join(projectRoot.path, 'lib', '_previews.g.dart'),
      );
      expect(generated.existsSync(), isTrue);
      expect(generated.readAsStringSync(), contains('AvatarPreview'));
    });
  });
}
