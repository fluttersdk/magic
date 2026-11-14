import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dowel/dowel.dart';
import 'package:magic/src/cli/commands/make_model_command.dart';
import 'package:path/path.dart' as p;

import '_harness.dart';

void main() {
  group('MakeModelCommand metadata', () {
    final cmd = MakeModelCommand();

    test('declares name make:model', () {
      expect(cmd.name, 'make:model');
    });

    test('extends DowelGeneratorCommand', () {
      expect(cmd, isA<DowelGeneratorCommand>());
    });

    test('declares CommandBoot.none', () {
      expect(cmd.boot, CommandBoot.none);
    });
  });

  group('MakeModelCommand.handle()', () {
    late Directory projectRoot;

    setUp(() {
      projectRoot = Directory.systemTemp.createTempSync('make_model_');
    });

    tearDown(() {
      if (projectRoot.existsSync()) projectRoot.deleteSync(recursive: true);
    });

    test(
      'scaffolds table/resource/fillable/casts/fromMap at the default path',
      () async {
        final cmd = MakeModelCommand(testRoot: projectRoot.path);
        final code = await cmd.handle(
          buildCommandContext(cmd, <String>['Monitor']),
        );

        expect(code, 0);
        final file = File(
          p.join(projectRoot.path, 'lib', 'app', 'models', 'monitor.dart'),
        );
        expect(file.existsSync(), isTrue);
        final content = file.readAsStringSync();
        expect(content, contains("String get table => 'monitors';"));
        expect(content, contains("String get resource => 'monitors';"));
        expect(content, contains('List<String> get fillable => [];'));
        expect(content, contains('Map<String, String> get casts => const {};'));
        expect(content, contains('static Monitor fromMap('));
      },
    );

    test('resolves a nested name to a nested path', () async {
      final cmd = MakeModelCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Admin/Monitor']),
      );

      expect(code, 0);
      final file = File(
        p.join(
          projectRoot.path,
          'lib',
          'app',
          'models',
          'admin',
          'monitor.dart',
        ),
      );
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), contains('static Monitor fromMap('));
    });

    test('returns 1 when the name argument is missing', () async {
      final cmd = MakeModelCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(buildCommandContext(cmd, <String>[]));
      expect(code, 1);
    });

    test('returns 1 when the file already exists without --force', () async {
      final cmd = MakeModelCommand(testRoot: projectRoot.path);
      await cmd.handle(buildCommandContext(cmd, <String>['Monitor']));
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Monitor']),
      );
      expect(code, 1);
    });

    test(
      '-a fans out to model, policy, repository and controller, and hints at '
      'the database companions when no plugin registers them',
      () async {
        final cmd = MakeModelCommand(testRoot: projectRoot.path);
        final ctx = buildCommandContext(cmd, <String>['Monitor', '-a']);
        final code = await cmd.handle(ctx);

        expect(code, 0);

        final modelFile = File(
          p.join(projectRoot.path, 'lib', 'app', 'models', 'monitor.dart'),
        );
        expect(modelFile.existsSync(), isTrue);

        expect(
          Directory(p.join(projectRoot.path, 'lib', 'database')).existsSync(),
          isFalse,
        );
        final output = (ctx.output as BufferedOutput).content;
        for (final command in <String>[
          'make:migration',
          'make:factory',
          'make:seeder',
        ]) {
          expect(output, contains('Skipped $command'));
        }

        final policyFile = File(
          p.join(
            projectRoot.path,
            'lib',
            'app',
            'policies',
            'monitor_policy.dart',
          ),
        );
        expect(policyFile.existsSync(), isTrue);

        final repositoryFile = File(
          p.join(
            projectRoot.path,
            'lib',
            'app',
            'repositories',
            'monitor_repository.dart',
          ),
        );
        expect(repositoryFile.existsSync(), isTrue);

        final controllerFile = File(
          p.join(
            projectRoot.path,
            'lib',
            'app',
            'controllers',
            'monitor_controller.dart',
          ),
        );
        expect(controllerFile.existsSync(), isTrue);
      },
    );
  });

  group('MakeModelCommand database companions', () {
    late Directory projectRoot;

    setUp(() {
      projectRoot = Directory.systemTemp.createTempSync('make_model_db_');
    });

    tearDown(() {
      if (projectRoot.existsSync()) projectRoot.deleteSync(recursive: true);
    });

    test('-m -f -s print a hint naming magic_local_storage when the registry '
        'lacks the generators', () async {
      final cmd = MakeModelCommand(testRoot: projectRoot.path);
      final ctx = buildCommandContext(cmd, <String>[
        'Monitor',
        '-m',
        '-f',
        '-s',
      ], registry: DowelRegistry());

      expect(await cmd.handle(ctx), 0);

      final output = (ctx.output as BufferedOutput).content;
      for (final command in <String>[
        'make:migration',
        'make:factory',
        'make:seeder',
      ]) {
        expect(
          output,
          contains('Skipped $command: it ships with magic_local_storage'),
        );
      }
      expect(
        File(p.join(projectRoot.path, 'lib', 'app', 'models', 'monitor.dart'))
            .existsSync(),
        isTrue,
      );
      expect(
        Directory(p.join(projectRoot.path, 'lib', 'database')).existsSync(),
        isFalse,
      );
    });

    test('-m -f -s delegate to the registered generators', () async {
      final migration = RecordingGenerator(
        'make:migration',
        root: projectRoot.path,
      );
      final factory = RecordingGenerator(
        'make:factory',
        root: projectRoot.path,
      );
      final seeder = RecordingGenerator('make:seeder', root: projectRoot.path);
      final registry = DowelRegistry()
        ..registerAll(<DowelCommand>[migration, factory, seeder]);
      final cmd = MakeModelCommand(testRoot: projectRoot.path);
      final ctx = buildCommandContext(cmd, <String>[
        'Monitor',
        '-m',
        '-f',
        '-s',
      ], registry: registry);

      expect(await cmd.handle(ctx), 0);

      expect(migration.runs, <({String? argument, String? create})>[
        (argument: 'create_monitors_table', create: 'monitors'),
      ]);
      expect(factory.runs, <({String? argument, String? create})>[
        (argument: 'Monitor', create: null),
      ]);
      expect(seeder.runs, <({String? argument, String? create})>[
        (argument: 'Monitor', create: null),
      ]);
      expect(
        (ctx.output as BufferedOutput).content,
        isNot(contains('magic_local_storage')),
      );
    });
  });
}
