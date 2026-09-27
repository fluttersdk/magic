import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/cli/commands/make_controller_command.dart';
import 'package:path/path.dart' as p;

import '_harness.dart';

void main() {
  group('MakeControllerCommand metadata', () {
    final cmd = MakeControllerCommand();

    test('declares name make:controller', () {
      expect(cmd.name, 'make:controller');
    });

    test('extends ArtisanGeneratorCommand', () {
      expect(cmd, isA<ArtisanGeneratorCommand>());
    });

    test('declares CommandBoot.none', () {
      expect(cmd.boot, CommandBoot.none);
    });
  });

  group('MakeControllerCommand.handle()', () {
    late Directory projectRoot;

    setUp(() {
      projectRoot = Directory.systemTemp.createTempSync('make_controller_');
    });

    tearDown(() {
      if (projectRoot.existsSync()) projectRoot.deleteSync(recursive: true);
    });

    File controllerFile(String fileStem) => File(
      p.join(projectRoot.path, 'lib', 'app', 'controllers', '$fileStem.dart'),
    );

    test(
      'a plain controller implements SessionScoped and owns no Widget methods',
      () async {
        final cmd = MakeControllerCommand(testRoot: projectRoot.path);
        final code = await cmd.handle(
          buildCommandContext(cmd, <String>['Monitor']),
        );

        expect(code, 0);
        final content = controllerFile('monitor_controller').readAsStringSync();
        expect(
          content,
          contains('class MonitorController extends MagicController'),
        );
        expect(content, contains('implements SessionScoped'));
        expect(content, contains('static MonitorController get instance'));
        expect(content, contains('Future<void> resetForSession()'));
        expect(content, isNot(contains('Widget index(')));
        expect(content, isNot(contains('Widget show(')));
      },
    );

    test(
      '--resource --model=Monitor owns a RepositoryQuery<Monitor> and ensureFresh()',
      () async {
        final cmd = MakeControllerCommand(testRoot: projectRoot.path);
        final code = await cmd.handle(
          buildCommandContext(cmd, <String>[
            'Uptime',
            '--resource',
            '--model=Monitor',
          ]),
        );

        expect(code, 0);
        final content = controllerFile('uptime_controller').readAsStringSync();
        expect(content, contains('RepositoryQuery<Monitor>'));
        expect(content, contains('MonitorRepository.instance'));
        expect(
          content,
          contains('Future<void> ensureFresh() => _query.ensureFresh();'),
        );
        expect(content, contains("import '../models/monitor.dart';"));
        expect(
          content,
          contains("import '../repositories/monitor_repository.dart';"),
        );
      },
    );

    test(
      '--resource with no --model defaults the model to the controller name',
      () async {
        final cmd = MakeControllerCommand(testRoot: projectRoot.path);
        final code = await cmd.handle(
          buildCommandContext(cmd, <String>['Monitor', '--resource']),
        );

        expect(code, 0);
        final content = controllerFile('monitor_controller').readAsStringSync();
        expect(content, contains('RepositoryQuery<Monitor>'));
        expect(content, contains("import '../models/monitor.dart';"));
        expect(
          content,
          contains("import '../repositories/monitor_repository.dart';"),
        );
      },
    );

    test('--resource on a nested name imports from the right depth', () async {
      final cmd = MakeControllerCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Admin/Dashboard', '--resource']),
      );

      expect(code, 0);
      final file = File(
        p.join(
          projectRoot.path,
          'lib',
          'app',
          'controllers',
          'admin',
          'dashboard_controller.dart',
        ),
      );
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains("import '../../models/dashboard.dart';"));
      expect(
        content,
        contains("import '../../repositories/dashboard_repository.dart';"),
      );
    });

    test('--actions mixes in RunsActions', () async {
      final cmd = MakeControllerCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Monitor', '--actions']),
      );

      expect(code, 0);
      final content = controllerFile('monitor_controller').readAsStringSync();
      expect(content, contains('with RunsActions'));
    });

    test(
      '--broadcasts mixes in ListensToBroadcasts with an empty listeners map',
      () async {
        final cmd = MakeControllerCommand(testRoot: projectRoot.path);
        final code = await cmd.handle(
          buildCommandContext(cmd, <String>['Monitor', '--broadcasts']),
        );

        expect(code, 0);
        final content = controllerFile('monitor_controller').readAsStringSync();
        expect(content, contains('with ListensToBroadcasts'));
        expect(
          content,
          contains('Map<String, void Function(BroadcastEvent)> get listeners'),
        );
      },
    );

    test('--timers mixes in OwnsTimers', () async {
      final cmd = MakeControllerCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Monitor', '--timers']),
      );

      expect(code, 0);
      final content = controllerFile('monitor_controller').readAsStringSync();
      expect(content, contains('with OwnsTimers'));
    });

    test(
      '--validates mixes in ValidatesRequests and CollapsesIndexedErrorKeys',
      () async {
        final cmd = MakeControllerCommand(testRoot: projectRoot.path);
        final code = await cmd.handle(
          buildCommandContext(cmd, <String>['Monitor', '--validates']),
        );

        expect(code, 0);
        final content = controllerFile('monitor_controller').readAsStringSync();
        expect(
          content,
          contains('with ValidatesRequests, CollapsesIndexedErrorKeys'),
        );
      },
    );

    test(
      'all four mixin flags together produce one with clause in a stable order '
      'regardless of the order they were passed',
      () async {
        final cmd = MakeControllerCommand(testRoot: projectRoot.path);
        final code = await cmd.handle(
          buildCommandContext(cmd, <String>[
            'Monitor',
            '--validates',
            '--actions',
            '--timers',
            '--broadcasts',
          ]),
        );

        expect(code, 0);
        final content = controllerFile('monitor_controller').readAsStringSync();
        expect(
          content,
          contains(
            'with ListensToBroadcasts, OwnsTimers, RunsActions, ValidatesRequests, '
            'CollapsesIndexedErrorKeys',
          ),
        );
      },
    );

    test('--test writes the matching controller test', () async {
      File(
        p.join(projectRoot.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: fixture_app\n');

      final cmd = MakeControllerCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Monitor', '--test']),
      );

      expect(code, 0);
      final testFile = File(
        p.join(
          projectRoot.path,
          'test',
          'app',
          'controllers',
          'monitor_controller_test.dart',
        ),
      );
      expect(testFile.existsSync(), isTrue);
      expect(
        testFile.readAsStringSync(),
        contains(
          "import 'package:fixture_app/app/controllers/monitor_controller.dart';",
        ),
      );
    });

    test('returns 1 when the name argument is missing', () async {
      final cmd = MakeControllerCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(buildCommandContext(cmd, <String>[]));
      expect(code, 1);
    });

    test('returns 1 when the file already exists without --force', () async {
      final cmd = MakeControllerCommand(testRoot: projectRoot.path);
      await cmd.handle(buildCommandContext(cmd, <String>['Monitor']));

      final second = MakeControllerCommand(testRoot: projectRoot.path);
      final code = await second.handle(
        buildCommandContext(second, <String>['Monitor']),
      );
      expect(code, 1);
    });
  });
}
