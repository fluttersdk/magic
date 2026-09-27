import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/cli/commands/make_repository_command.dart';
import 'package:path/path.dart' as p;

import '_harness.dart';

void main() {
  group('MakeRepositoryCommand metadata', () {
    final cmd = MakeRepositoryCommand();

    test('declares name make:repository', () {
      expect(cmd.name, 'make:repository');
    });

    test('extends ArtisanGeneratorCommand', () {
      expect(cmd, isA<ArtisanGeneratorCommand>());
    });

    test('declares CommandBoot.none', () {
      expect(cmd.boot, CommandBoot.none);
    });
  });

  group('MakeRepositoryCommand.handle()', () {
    late Directory projectRoot;

    setUp(() {
      projectRoot = Directory.systemTemp.createTempSync('make_repository_');
    });

    tearDown(() {
      if (projectRoot.existsSync()) projectRoot.deleteSync(recursive: true);
    });

    test('scaffolds a repository extending Repository<Model>', () async {
      final cmd = MakeRepositoryCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Monitor']),
      );

      expect(code, 0);
      final file = File(
        p.join(
          projectRoot.path,
          'lib',
          'app',
          'repositories',
          'monitor_repository.dart',
        ),
      );
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, contains("import '../models/monitor.dart';"));
      expect(
        content,
        contains('class MonitorRepository extends Repository<Monitor>'),
      );
      expect(content, contains("String get resource => 'monitors';"));
      expect(
        content,
        contains(
          'Monitor Function(Map<String, dynamic>) get fromMap => Monitor.fromMap;',
        ),
      );
      expect(content, contains('static MonitorRepository get instance'));
      expect(content, isNot(contains('Magic.put(')));
    });

    test('does not double-suffix when Repository is already present', () async {
      final cmd = MakeRepositoryCommand(testRoot: projectRoot.path);
      await cmd.handle(buildCommandContext(cmd, <String>['MonitorRepository']));

      final file = File(
        p.join(
          projectRoot.path,
          'lib',
          'app',
          'repositories',
          'monitor_repository.dart',
        ),
      );
      expect(file.existsSync(), isTrue);
    });

    test('returns 1 when the name argument is missing', () async {
      final cmd = MakeRepositoryCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(buildCommandContext(cmd, <String>[]));
      expect(code, 1);
    });

    test('--test chains make:test --kind=repository', () async {
      final cmd = MakeRepositoryCommand(testRoot: projectRoot.path);
      File(
        p.join(projectRoot.path, 'pubspec.yaml'),
      ).createSync(recursive: true);
      File(
        p.join(projectRoot.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: fixture_app\n');

      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Monitor', '--test']),
      );

      expect(code, 0);
      final testFile = File(
        p.join(
          projectRoot.path,
          'test',
          'app',
          'repositories',
          'monitor_repository_test.dart',
        ),
      );
      expect(testFile.existsSync(), isTrue);
    });
  });
}
