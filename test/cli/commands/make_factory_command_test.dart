import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_artisan/artisan.dart';
import 'package:magic/src/cli/commands/make_factory_command.dart';
import 'package:path/path.dart' as p;

import '_harness.dart';

void main() {
  group('MakeFactoryCommand metadata', () {
    final cmd = MakeFactoryCommand();

    test('declares name make:factory', () {
      expect(cmd.name, 'make:factory');
    });

    test('extends ArtisanGeneratorCommand', () {
      expect(cmd, isA<ArtisanGeneratorCommand>());
    });

    test('declares CommandBoot.none', () {
      expect(cmd.boot, CommandBoot.none);
    });
  });

  group('MakeFactoryCommand.handle()', () {
    late Directory projectRoot;

    setUp(() {
      projectRoot = Directory.systemTemp.createTempSync('make_factory_');
    });

    tearDown(() {
      if (projectRoot.existsSync()) projectRoot.deleteSync(recursive: true);
    });

    test('scaffolds at the default path with newFactory()', () async {
      final cmd = MakeFactoryCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Monitor']),
      );

      expect(code, 0);
      final file = File(
        p.join(
          projectRoot.path,
          'lib',
          'database',
          'factories',
          'monitor_factory.dart',
        ),
      );
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('class MonitorFactory extends Factory<Model>'));
      expect(
        content,
        contains('Factory<Model> newFactory() => MonitorFactory();'),
      );
    });

    test('resolves a nested name to a nested path', () async {
      final cmd = MakeFactoryCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Admin/Monitor']),
      );

      expect(code, 0);
      final file = File(
        p.join(
          projectRoot.path,
          'lib',
          'database',
          'factories',
          'admin',
          'monitor_factory.dart',
        ),
      );
      expect(file.existsSync(), isTrue);
      expect(
        file.readAsStringSync(),
        contains('Factory<Model> newFactory() => MonitorFactory();'),
      );
    });

    test('returns 1 when the name argument is missing', () async {
      final cmd = MakeFactoryCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(buildCommandContext(cmd, <String>[]));
      expect(code, 1);
    });

    test('returns 1 when the file already exists without --force', () async {
      final cmd = MakeFactoryCommand(testRoot: projectRoot.path);
      await cmd.handle(buildCommandContext(cmd, <String>['Monitor']));
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Monitor']),
      );
      expect(code, 1);
    });
  });
}
