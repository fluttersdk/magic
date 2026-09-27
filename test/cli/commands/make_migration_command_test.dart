import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_artisan/artisan.dart';
import 'package:magic/src/cli/commands/make_migration_command.dart';
import 'package:path/path.dart' as p;

import '_harness.dart';

/// Migration filenames carry a `m_YYYYMMDDHHmmss_` timestamp prefix. Match
/// the shape with a regex, never a fixed timestamp (the QA requirement).
final RegExp _migrationFileNamePattern = RegExp(r'^m_\d{14}_[a-z0-9_]+\.dart$');

void main() {
  group('MakeMigrationCommand metadata', () {
    final cmd = MakeMigrationCommand();

    test('declares name make:migration', () {
      expect(cmd.name, 'make:migration');
    });

    test('extends ArtisanGeneratorCommand', () {
      expect(cmd, isA<ArtisanGeneratorCommand>());
    });

    test('declares CommandBoot.none', () {
      expect(cmd.boot, CommandBoot.none);
    });
  });

  group('MakeMigrationCommand.handle()', () {
    late Directory projectRoot;
    late Directory migrationsDir;

    setUp(() {
      projectRoot = Directory.systemTemp.createTempSync('make_migration_');
      migrationsDir = Directory(
        p.join(projectRoot.path, 'lib', 'database', 'migrations'),
      );
    });

    tearDown(() {
      if (projectRoot.existsSync()) projectRoot.deleteSync(recursive: true);
    });

    /// Returns the single migration file written under [migrationsDir].
    File writtenFile() {
      final files = migrationsDir
          .listSync()
          .whereType<File>()
          .where((f) => p.basename(f.path).endsWith('.dart'))
          .toList();
      expect(files, hasLength(1));
      return files.single;
    }

    test(
      'writes a timestamped file matching the migration name regex',
      () async {
        final cmd = MakeMigrationCommand(testRoot: projectRoot.path);
        final code = await cmd.handle(
          buildCommandContext(cmd, <String>['create_users_table']),
        );

        expect(code, 0);
        final file = writtenFile();
        expect(p.basename(file.path), matches(_migrationFileNamePattern));
        expect(p.basename(file.path), contains('create_users_table'));
      },
    );

    test('--create writes a synchronous Schema.create up()/down()', () async {
      final cmd = MakeMigrationCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>[
          'create_monitors_table',
          '--create=monitors',
        ]),
      );

      expect(code, 0);
      final content = writtenFile().readAsStringSync();
      expect(content, contains('void up() {'));
      expect(content, contains('void down() {'));
      expect(
        content,
        contains("Schema.create('monitors', (Blueprint table) {"),
      );
      expect(content, contains("Schema.dropIfExists('monitors');"));
      expect(content, isNot(contains('Future<void>')));
    });

    test('--table writes a synchronous plain migration', () async {
      final cmd = MakeMigrationCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>[
          'add_region_to_monitors',
          '--table=monitors',
        ]),
      );

      expect(code, 0);
      final content = writtenFile().readAsStringSync();
      expect(content, contains('void up() {'));
      expect(content, contains('void down() {'));
      expect(content, isNot(contains('Schema.create(')));
      expect(content, isNot(contains('Future<void>')));
    });

    test('resolves a nested name to a nested directory', () async {
      final cmd = MakeMigrationCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Admin/create_reports_table']),
      );

      expect(code, 0);
      final nestedDir = Directory(p.join(migrationsDir.path, 'admin'));
      final files = nestedDir.listSync().whereType<File>().toList();
      expect(files, hasLength(1));
      expect(p.basename(files.single.path), matches(_migrationFileNamePattern));
    });

    test('returns 1 when the name argument is missing', () async {
      final cmd = MakeMigrationCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(buildCommandContext(cmd, <String>[]));
      expect(code, 1);
    });

    test('returns 1 when the file already exists without --force', () async {
      final cmd = MakeMigrationCommand(testRoot: projectRoot.path);
      await cmd.handle(
        buildCommandContext(cmd, <String>['create_users_table']),
      );
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['create_users_table']),
      );
      expect(code, 1);
    });
  });
}
