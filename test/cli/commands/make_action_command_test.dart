import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/cli/commands/make_action_command.dart';
import 'package:path/path.dart' as p;

import '_harness.dart';

void main() {
  group('MakeActionCommand metadata', () {
    final cmd = MakeActionCommand();

    test('declares name make:action', () {
      expect(cmd.name, 'make:action');
    });

    test('extends ArtisanGeneratorCommand', () {
      expect(cmd, isA<ArtisanGeneratorCommand>());
    });

    test('declares CommandBoot.none', () {
      expect(cmd.boot, CommandBoot.none);
    });
  });

  group('MakeActionCommand.handle()', () {
    late Directory projectRoot;

    setUp(() {
      projectRoot = Directory.systemTemp.createTempSync('make_action_');
    });

    tearDown(() {
      if (projectRoot.existsSync()) projectRoot.deleteSync(recursive: true);
    });

    test('scaffolds an action extending MagicAction<Object?, void>', () async {
      final cmd = MakeActionCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['PauseMonitor']),
      );

      expect(code, 0);
      final file = File(
        p.join(projectRoot.path, 'lib', 'app', 'actions', 'pause_monitor.dart'),
      );
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(
        content,
        contains('class PauseMonitor extends MagicAction<Object?, void>'),
      );
      expect(content, contains('Future<void> handle(Object? input)'));
    });

    test('supports a nested name', () async {
      final cmd = MakeActionCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Monitors/PauseMonitor']),
      );

      expect(code, 0);
      final file = File(
        p.join(
          projectRoot.path,
          'lib',
          'app',
          'actions',
          'monitors',
          'pause_monitor.dart',
        ),
      );
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), contains('class PauseMonitor'));
    });

    test('returns 1 when the name argument is missing', () async {
      final cmd = MakeActionCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(buildCommandContext(cmd, <String>[]));
      expect(code, 1);
    });

    test('returns 1 when the file already exists without --force', () async {
      final cmd = MakeActionCommand(testRoot: projectRoot.path);
      await cmd.handle(buildCommandContext(cmd, <String>['PauseMonitor']));

      final second = MakeActionCommand(testRoot: projectRoot.path);
      final code = await second.handle(
        buildCommandContext(second, <String>['PauseMonitor']),
      );
      expect(code, 1);
    });

    test('--kind=create --model wires a typed create action', () async {
      final cmd = MakeActionCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>[
          'Monitors/CreateMonitor',
          '--kind=create',
          '--model=Monitor',
        ]),
      );

      expect(code, 0);
      final content = File(
        p.join(
          projectRoot.path,
          'lib',
          'app',
          'actions',
          'monitors',
          'create_monitor.dart',
        ),
      ).readAsStringSync();

      expect(content, contains("import '../../models/monitor.dart';"));
      expect(
        content,
        contains(
          'class CreateMonitor extends MagicAction<Map<String, dynamic>, Monitor>',
        ),
      );
      expect(
        content,
        contains('Future<Monitor> handle(Map<String, dynamic> fields)'),
      );
      expect(content, contains('ActionRequestFailed.refusalOf('));
      expect(content, contains('monitor.validationErrors'));
    });

    test('--kind=update --model wires a record-input update action', () async {
      final cmd = MakeActionCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>[
          'Monitors/UpdateMonitor',
          '--kind=update',
          '--model=Monitor',
        ]),
      );

      expect(code, 0);
      final content = File(
        p.join(
          projectRoot.path,
          'lib',
          'app',
          'actions',
          'monitors',
          'update_monitor.dart',
        ),
      ).readAsStringSync();

      expect(content, contains("import '../../models/monitor.dart';"));
      expect(
        content,
        contains(
          'extends MagicAction<({String id, Map<String, dynamic> fields}), Monitor?>',
        ),
      );
      expect(content, contains('await Monitor.find(input.id)'));
      expect(
        content,
        contains("import '../../repositories/monitor_repository.dart';"),
      );
      expect(
        content,
        contains('MonitorRepository.instance.upsertFromShow(monitor)'),
      );
      expect(content, contains('ActionRequestFailed.refusalOf('));
    });

    test(
      '--kind=delete --model wires a repository-evicting delete action',
      () async {
        final cmd = MakeActionCommand(testRoot: projectRoot.path);
        final code = await cmd.handle(
          buildCommandContext(cmd, <String>[
            'Monitors/DeleteMonitor',
            '--kind=delete',
            '--model=Monitor',
          ]),
        );

        expect(code, 0);
        final content = File(
          p.join(
            projectRoot.path,
            'lib',
            'app',
            'actions',
            'monitors',
            'delete_monitor.dart',
          ),
        ).readAsStringSync();

        expect(content, contains("import '../../models/monitor.dart';"));
        expect(
          content,
          contains("import '../../repositories/monitor_repository.dart';"),
        );
        expect(
          content,
          contains('class DeleteMonitor extends MagicAction<Monitor, void>'),
        );
        expect(
          content,
          contains("throw ActionRequestFailed('delete \${monitor.id}')"),
        );
        expect(
          content,
          contains("MonitorRepository.instance.evict('\${monitor.id}')"),
        );
      },
    );

    test('returns 1 when --kind is given without --model', () async {
      final cmd = MakeActionCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['CreateMonitor', '--kind=create']),
      );
      expect(code, 1);
    });

    test('returns 1 when --kind is unknown', () async {
      final cmd = MakeActionCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>[
          'CreateMonitor',
          '--kind=bogus',
          '--model=Monitor',
        ]),
      );
      expect(code, 1);
    });

    test('--test chains make:test --kind=action', () async {
      final cmd = MakeActionCommand(testRoot: projectRoot.path);
      File(
        p.join(projectRoot.path, 'pubspec.yaml'),
      ).createSync(recursive: true);
      File(
        p.join(projectRoot.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: fixture_app\n');

      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['PauseMonitor', '--test']),
      );

      expect(code, 0);
      final testFile = File(
        p.join(
          projectRoot.path,
          'test',
          'app',
          'actions',
          'pause_monitor_test.dart',
        ),
      );
      expect(testFile.existsSync(), isTrue);
    });
  });
}
