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

    /// Seeds `lib/_previews.g.dart` so preview auto-detection sees an
    /// existing catalogue (the default assumption for tests that predate
    /// detection and still expect a preview file).
    void seedPreviewCatalogue() {
      final libDir = Directory(p.join(projectRoot.path, 'lib'))
        ..createSync(recursive: true);
      File(p.join(libDir.path, '_previews.g.dart')).writeAsStringSync(
        "List<Object> previewEntries() => const <Object>[];\n",
      );
    }

    setUp(() {
      projectRoot = Directory.systemTemp.createTempSync('make_component_');
      // The real stubs ship in magic's assets/stubs/; point the generator at
      // them via the env override the StubLoader honours.
      stubsDir = p.join(Directory.current.path, 'assets', 'stubs');
      // The generator always attempts to write the matching widget test,
      // which reads the target project's package name from pubspec.yaml.
      File(
        p.join(projectRoot.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: app\n');
    });

    tearDown(() {
      if (projectRoot.existsSync()) projectRoot.deleteSync(recursive: true);
    });

    test('scaffolds the 4-file atomic component folder', () async {
      seedPreviewCatalogue();
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
      seedPreviewCatalogue();
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

    group('preview auto-detection', () {
      String avatarPreviewPath() => p.join(
        projectRoot.path,
        'lib',
        'ui',
        'components',
        'avatar',
        'avatar.preview.dart',
      );

      test('writes no preview and no _previews.g.dart when lib/ carries no '
          'catalogue', () async {
        final cmd = MakeComponentCommand(testRoot: projectRoot.path);
        final output = BufferedOutput();
        final parser = ArgParser();
        cmd.configure(parser);
        final input = ArgvInput.parse(parser, <String>[
          'Avatar',
          '--stubs-dir=$stubsDir',
        ]);
        final code = await cmd.handle(ArtisanContext.bare(input, output));

        expect(code, 0);
        expect(File(avatarPreviewPath()).existsSync(), isFalse);
        expect(
          File(
            p.join(projectRoot.path, 'lib', '_previews.g.dart'),
          ).existsSync(),
          isFalse,
        );
        expect(output.content, contains('Preview: skipped'));
      });

      test(
        'writes a preview when lib/_previews.g.dart already exists',
        () async {
          seedPreviewCatalogue();
          final cmd = MakeComponentCommand(testRoot: projectRoot.path);
          final output = BufferedOutput();
          final parser = ArgParser();
          cmd.configure(parser);
          final input = ArgvInput.parse(parser, <String>[
            'Avatar',
            '--stubs-dir=$stubsDir',
          ]);
          final code = await cmd.handle(ArtisanContext.bare(input, output));

          expect(code, 0);
          expect(File(avatarPreviewPath()).existsSync(), isTrue);
          expect(output.content, contains('Preview: written'));
        },
      );

      test(
        'writes a preview when a nested *.preview.dart file already exists',
        () async {
          final nested = Directory(
            p.join(projectRoot.path, 'lib', 'ui', 'components', 'other'),
          )..createSync(recursive: true);
          File(p.join(nested.path, 'other.preview.dart')).writeAsStringSync('''
import 'package:flutter/widgets.dart';

class OtherPreview extends StatelessWidget {
  const OtherPreview({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
''');

          final cmd = MakeComponentCommand(testRoot: projectRoot.path);
          final code = await cmd.handle(
            _ctx(cmd, <String>['Avatar', '--stubs-dir=$stubsDir']),
          );

          expect(code, 0);
          expect(File(avatarPreviewPath()).existsSync(), isTrue);
        },
      );

      test('--no-preview beats an existing catalogue', () async {
        seedPreviewCatalogue();
        final cmd = MakeComponentCommand(testRoot: projectRoot.path);
        final output = BufferedOutput();
        final parser = ArgParser();
        cmd.configure(parser);
        final input = ArgvInput.parse(parser, <String>[
          'Avatar',
          '--no-preview',
          '--stubs-dir=$stubsDir',
        ]);
        final code = await cmd.handle(ArtisanContext.bare(input, output));

        expect(code, 0);
        expect(File(avatarPreviewPath()).existsSync(), isFalse);
        expect(output.content, contains('Preview: skipped'));
        expect(output.content, contains('--no-preview'));
      });

      test('--preview beats an absent catalogue', () async {
        final cmd = MakeComponentCommand(testRoot: projectRoot.path);
        final output = BufferedOutput();
        final parser = ArgParser();
        cmd.configure(parser);
        final input = ArgvInput.parse(parser, <String>[
          'Avatar',
          '--preview',
          '--stubs-dir=$stubsDir',
        ]);
        final code = await cmd.handle(ArtisanContext.bare(input, output));

        expect(code, 0);
        expect(File(avatarPreviewPath()).existsSync(), isTrue);
        expect(output.content, contains('Preview: written'));
        expect(output.content, contains('--preview'));
      });
    });

    group('matching widget test', () {
      String testFilePath() => p.join(
        projectRoot.path,
        'test',
        'ui',
        'components',
        'avatar',
        'avatar_test.dart',
      );

      test('writes test/ui/components/<name>/<name>_test.dart importing '
          'packageName', () async {
        final cmd = MakeComponentCommand(testRoot: projectRoot.path);
        final code = await cmd.handle(
          _ctx(cmd, <String>['Avatar', '--stubs-dir=$stubsDir']),
        );

        expect(code, 0);
        final file = File(testFilePath());
        expect(file.existsSync(), isTrue);
        final content = file.readAsStringSync();
        expect(
          content,
          contains("package:app/ui/components/avatar/index.dart"),
        );
        expect(content, contains('Avatar'));
      });

      test('refuses a kept test without --force and writes nothing', () async {
        File(testFilePath())
          ..createSync(recursive: true)
          ..writeAsStringSync('// filled in by hand\n');

        final cmd = MakeComponentCommand(testRoot: projectRoot.path);
        final code = await cmd.handle(
          _ctx(cmd, <String>['Avatar', '--stubs-dir=$stubsDir']),
        );

        expect(code, 1);
        expect(
          File(testFilePath()).readAsStringSync(),
          '// filled in by hand\n',
        );
        expect(
          File(
            p.join(
              projectRoot.path,
              'lib',
              'ui',
              'components',
              'avatar',
              'avatar.dart',
            ),
          ).existsSync(),
          isFalse,
        );
      });

      test('--force overwrites a kept test', () async {
        File(testFilePath())
          ..createSync(recursive: true)
          ..writeAsStringSync('// filled in by hand\n');

        final cmd = MakeComponentCommand(testRoot: projectRoot.path);
        final code = await cmd.handle(
          _ctx(cmd, <String>['Avatar', '--force', '--stubs-dir=$stubsDir']),
        );

        expect(code, 0);
        expect(
          File(testFilePath()).readAsStringSync(),
          contains('package:app/ui/components/avatar/index.dart'),
        );
      });

      test('works for a --slots component too', () async {
        final cmd = MakeComponentCommand(testRoot: projectRoot.path);
        final code = await cmd.handle(
          _ctx(cmd, <String>['Avatar', '--slots', '--stubs-dir=$stubsDir']),
        );

        expect(code, 0);
        expect(File(testFilePath()).existsSync(), isTrue);
      });

      test(
        'skips the test file with a printed note when pubspec.yaml is absent',
        () async {
          File(p.join(projectRoot.path, 'pubspec.yaml')).deleteSync();

          final cmd = MakeComponentCommand(testRoot: projectRoot.path);
          final output = BufferedOutput();
          final parser = ArgParser();
          cmd.configure(parser);
          final input = ArgvInput.parse(parser, <String>[
            'Avatar',
            '--stubs-dir=$stubsDir',
          ]);
          final code = await cmd.handle(ArtisanContext.bare(input, output));

          expect(code, 0);
          expect(File(testFilePath()).existsSync(), isFalse);
          expect(output.content, contains('pubspec.yaml'));
        },
      );
    });
  });
}
