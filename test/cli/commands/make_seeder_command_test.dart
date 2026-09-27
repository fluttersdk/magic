import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_artisan/artisan.dart';
import 'package:magic/src/cli/commands/make_seeder_command.dart';
import 'package:path/path.dart' as p;

import '_harness.dart';

void main() {
  group('MakeSeederCommand metadata', () {
    final cmd = MakeSeederCommand();

    test('declares name make:seeder', () {
      expect(cmd.name, 'make:seeder');
    });

    test('extends ArtisanGeneratorCommand', () {
      expect(cmd, isA<ArtisanGeneratorCommand>());
    });

    test('declares CommandBoot.none', () {
      expect(cmd.boot, CommandBoot.none);
    });
  });

  group('MakeSeederCommand.handle()', () {
    late Directory projectRoot;

    setUp(() {
      projectRoot = Directory.systemTemp.createTempSync('make_seeder_');
    });

    tearDown(() {
      if (projectRoot.existsSync()) projectRoot.deleteSync(recursive: true);
    });

    test('scaffolds at the default path with the key class line', () async {
      final cmd = MakeSeederCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Monitor']),
      );

      expect(code, 0);
      final file = File(
        p.join(
          projectRoot.path,
          'lib',
          'database',
          'seeders',
          'monitor_seeder.dart',
        ),
      );
      expect(file.existsSync(), isTrue);
      expect(
        file.readAsStringSync(),
        contains('class MonitorSeeder extends Seeder'),
      );
    });

    test('resolves a nested name to a nested path', () async {
      final cmd = MakeSeederCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Admin/Monitor']),
      );

      expect(code, 0);
      final file = File(
        p.join(
          projectRoot.path,
          'lib',
          'database',
          'seeders',
          'admin',
          'monitor_seeder.dart',
        ),
      );
      expect(file.existsSync(), isTrue);
      expect(
        file.readAsStringSync(),
        contains('class MonitorSeeder extends Seeder'),
      );
    });

    test('returns 1 when the name argument is missing', () async {
      final cmd = MakeSeederCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(buildCommandContext(cmd, <String>[]));
      expect(code, 1);
    });

    test('returns 1 when the file already exists without --force', () async {
      final cmd = MakeSeederCommand(testRoot: projectRoot.path);
      await cmd.handle(buildCommandContext(cmd, <String>['Monitor']));
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Monitor']),
      );
      expect(code, 1);
    });
  });
}
