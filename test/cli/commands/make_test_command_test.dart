import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/cli/commands/make_test_command.dart';
import 'package:path/path.dart' as p;

import '_harness.dart';

void main() {
  group('MakeTestCommand metadata', () {
    final cmd = MakeTestCommand();

    test('declares name make:test', () {
      expect(cmd.name, 'make:test');
    });

    test('extends ArtisanGeneratorCommand', () {
      expect(cmd, isA<ArtisanGeneratorCommand>());
    });

    test('declares CommandBoot.none', () {
      expect(cmd.boot, CommandBoot.none);
    });
  });

  group('MakeTestCommand.handle()', () {
    late Directory projectRoot;

    setUp(() {
      projectRoot = Directory.systemTemp.createTempSync('make_test_');
      File(
        p.join(projectRoot.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: fixture_app\n');
    });

    tearDown(() {
      if (projectRoot.existsSync()) projectRoot.deleteSync(recursive: true);
    });

    test('scaffolds a controller test mirroring the controller path', () async {
      final cmd = MakeTestCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Monitor', '--kind=controller']),
      );

      expect(code, 0);
      final file = File(
        p.join(
          projectRoot.path,
          'test',
          'app',
          'controllers',
          'monitor_controller_test.dart',
        ),
      );
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(
        content,
        contains(
          "import 'package:fixture_app/app/controllers/monitor_controller.dart';",
        ),
      );
      expect(content, contains('MagicAction.flush()'));
    });

    test('scaffolds an action test mirroring a nested action path', () async {
      final cmd = MakeTestCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>[
          'Monitors/PauseMonitor',
          '--kind=action',
        ]),
      );

      expect(code, 0);
      final file = File(
        p.join(
          projectRoot.path,
          'test',
          'app',
          'actions',
          'monitors',
          'pause_monitor_test.dart',
        ),
      );
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(
        content,
        contains(
          "import 'package:fixture_app/app/actions/monitors/pause_monitor.dart';",
        ),
      );
      expect(content, contains('MagicAction.flush()'));
    });

    test('scaffolds a form test mirroring the FormObject path', () async {
      final cmd = MakeTestCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Monitor', '--kind=form']),
      );

      expect(code, 0);
      final file = File(
        p.join(
          projectRoot.path,
          'test',
          'app',
          'forms',
          'monitor_form_object_test.dart',
        ),
      );
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(
        content,
        contains(
          "import 'package:fixture_app/app/forms/monitor_form_object.dart';",
        ),
      );
      expect(content, contains('MagicAction.flush()'));
    });

    test('scaffolds a repository test mirroring the Repository path', () async {
      final cmd = MakeTestCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Monitor', '--kind=repository']),
      );

      expect(code, 0);
      final file = File(
        p.join(
          projectRoot.path,
          'test',
          'app',
          'repositories',
          'monitor_repository_test.dart',
        ),
      );
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(
        content,
        contains(
          "import 'package:fixture_app/app/repositories/monitor_repository.dart';",
        ),
      );
      expect(content, contains('resetForSession'));
    });

    test('scaffolds a request test mirroring the Request path', () async {
      final cmd = MakeTestCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['StoreMonitor', '--kind=request']),
      );

      expect(code, 0);
      final file = File(
        p.join(
          projectRoot.path,
          'test',
          'app',
          'validation',
          'requests',
          'store_monitor_request_test.dart',
        ),
      );
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(
        content,
        contains(
          "import 'package:fixture_app/app/validation/requests/store_monitor_request.dart';",
        ),
      );
      expect(content, contains('.rules()'));
    });

    test('scaffolds a view test mirroring the View path', () async {
      final cmd = MakeTestCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Login', '--kind=view']),
      );

      expect(code, 0);
      final file = File(
        p.join(
          projectRoot.path,
          'test',
          'resources',
          'views',
          'login_view_test.dart',
        ),
      );
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(
        content,
        contains(
          "import 'package:fixture_app/resources/views/login_view.dart';",
        ),
      );
      expect(content, contains('WindTheme('));
    });

    test('scaffolds a unit test under test/unit', () async {
      final cmd = MakeTestCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['StatusFormatter', '--kind=unit']),
      );

      expect(code, 0);
      final file = File(
        p.join(projectRoot.path, 'test', 'unit', 'status_formatter_test.dart'),
      );
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, contains('package:fixture_app/'));
      expect(content, contains('// TODO: implement test'));
    });

    test('returns 1 when the name argument is missing', () async {
      final cmd = MakeTestCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['--kind=action']),
      );
      expect(code, 1);
    });

    test('returns 1 and lists the kinds when --kind is unknown', () async {
      final cmd = MakeTestCommand(testRoot: projectRoot.path);
      final parser = ArgParser();
      cmd.configure(parser);
      final input = ArgvInput.parse(parser, <String>[
        'Monitor',
        '--kind=bogus',
      ]);
      final output = BufferedOutput();
      final code = await cmd.handle(ArtisanContext.bare(input, output));

      expect(code, 1);
      expect(output.content, contains('controller'));
      expect(output.content, contains('unit'));
    });

    test(
      'returns 1 naming the missing pubspec.yaml when the project has none',
      () async {
        final bareRoot = Directory.systemTemp.createTempSync('make_test_bare_');
        addTearDown(() => bareRoot.deleteSync(recursive: true));

        final cmd = MakeTestCommand(testRoot: bareRoot.path);
        final parser = ArgParser();
        cmd.configure(parser);
        final input = ArgvInput.parse(parser, <String>[
          'Monitor',
          '--kind=action',
        ]);
        final output = BufferedOutput();
        final code = await cmd.handle(ArtisanContext.bare(input, output));

        expect(code, 1);
        expect(output.content, contains('pubspec.yaml'));
      },
    );

    test(
      'returns 1 when the test file already exists without --force',
      () async {
        final cmd = MakeTestCommand(testRoot: projectRoot.path);
        await cmd.handle(
          buildCommandContext(cmd, <String>['Monitor', '--kind=action']),
        );

        final second = MakeTestCommand(testRoot: projectRoot.path);
        final code = await second.handle(
          buildCommandContext(second, <String>['Monitor', '--kind=action']),
        );
        expect(code, 1);
      },
    );
  });
}
