import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_artisan/artisan.dart';
import 'package:magic/src/cli/commands/make_model_command.dart';
import 'package:path/path.dart' as p;

import '_harness.dart';

void main() {
  group('MakeModelCommand metadata', () {
    final cmd = MakeModelCommand();

    test('declares name make:model', () {
      expect(cmd.name, 'make:model');
    });

    test('extends ArtisanGeneratorCommand', () {
      expect(cmd, isA<ArtisanGeneratorCommand>());
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
      '-a fans out to model, migration, factory, seeder, policy, repository and controller',
      () async {
        final cmd = MakeModelCommand(testRoot: projectRoot.path);
        final code = await cmd.handle(
          buildCommandContext(cmd, <String>['Monitor', '-a']),
        );

        expect(code, 0);

        final modelFile = File(
          p.join(projectRoot.path, 'lib', 'app', 'models', 'monitor.dart'),
        );
        expect(modelFile.existsSync(), isTrue);

        final migrationsDir = Directory(
          p.join(projectRoot.path, 'lib', 'database', 'migrations'),
        );
        final migrationFiles = migrationsDir.existsSync()
            ? migrationsDir.listSync().whereType<File>().toList()
            : <File>[];
        expect(migrationFiles, hasLength(1));

        final factoryFile = File(
          p.join(
            projectRoot.path,
            'lib',
            'database',
            'factories',
            'monitor_factory.dart',
          ),
        );
        expect(factoryFile.existsSync(), isTrue);

        final seederFile = File(
          p.join(
            projectRoot.path,
            'lib',
            'database',
            'seeders',
            'monitor_seeder.dart',
          ),
        );
        expect(seederFile.existsSync(), isTrue);

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
}
