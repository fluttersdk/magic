import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/cli/commands/make_view_command.dart';
import 'package:path/path.dart' as p;

import '_harness.dart';

void main() {
  group('MakeViewCommand metadata', () {
    final cmd = MakeViewCommand();

    test('declares name make:view', () {
      expect(cmd.name, 'make:view');
    });

    test('extends ArtisanGeneratorCommand', () {
      expect(cmd, isA<ArtisanGeneratorCommand>());
    });

    test('declares CommandBoot.none', () {
      expect(cmd.boot, CommandBoot.none);
    });
  });

  group('MakeViewCommand.handle()', () {
    late Directory projectRoot;

    setUp(() {
      projectRoot = Directory.systemTemp.createTempSync('make_view_');
      File(
        p.join(projectRoot.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: fixture_app\n');
    });

    tearDown(() {
      if (projectRoot.existsSync()) projectRoot.deleteSync(recursive: true);
    });

    String readFile(List<String> segments) =>
        File(p.joinAll([projectRoot.path, ...segments])).readAsStringSync();

    test('no flag keeps the stateless view', () async {
      final cmd = MakeViewCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Login']),
      );

      expect(code, 0);
      final content = readFile([
        'lib',
        'resources',
        'views',
        'login_view.dart',
      ]);
      expect(content, contains('class LoginView extends StatelessWidget'));
      expect(content, isNot(contains('MagicStatefulView')));
    });

    test('--controller emits a MagicStatefulView bound to it', () async {
      final cmd = MakeViewCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Monitor', '--controller=Monitor']),
      );

      expect(code, 0);
      final content = readFile([
        'lib',
        'resources',
        'views',
        'monitor_view.dart',
      ]);
      expect(
        content,
        contains(
          'class MonitorView extends MagicStatefulView<MonitorController>',
        ),
      );
      expect(
        content,
        contains(
          'class _MonitorViewState\n'
          '    extends MagicStatefulViewState<MonitorController, MonitorView> {',
        ),
      );
      expect(
        content,
        contains("import '../../app/controllers/monitor_controller.dart';"),
      );
      expect(content, contains('Magic.findOrPut(MonitorController.new);'));
    });

    test('--stateful derives the controller from the view name', () async {
      final cmd = MakeViewCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Login', '--stateful']),
      );

      expect(code, 0);
      final content = readFile([
        'lib',
        'resources',
        'views',
        'login_view.dart',
      ]);
      expect(
        content,
        contains('class LoginView extends MagicStatefulView<LoginController>'),
      );
      expect(
        content,
        contains("import '../../app/controllers/login_controller.dart';"),
      );
    });

    test(
      '--list adds RefetchesOnMount and delegates to controller.ensureFresh()',
      () async {
        final cmd = MakeViewCommand(testRoot: projectRoot.path);
        final code = await cmd.handle(
          buildCommandContext(cmd, <String>[
            'Monitor',
            '--controller=Monitor',
            '--list',
          ]),
        );

        expect(code, 0);
        final content = readFile([
          'lib',
          'resources',
          'views',
          'monitor_view.dart',
        ]);
        expect(
          content,
          contains('with RefetchesOnMount<MonitorController, MonitorView>'),
        );
        expect(
          content,
          contains('Future<void> refetch() => controller.ensureFresh();'),
        );
      },
    );

    test('--form adds a State-owned form field disposed in onClose', () async {
      final cmd = MakeViewCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>[
          'Monitor',
          '--controller=Monitor',
          '--form=MonitorFormObject',
        ]),
      );

      expect(code, 0);
      final content = readFile([
        'lib',
        'resources',
        'views',
        'monitor_view.dart',
      ]);
      expect(
        content,
        contains("import '../../app/forms/monitor_form_object.dart';"),
      );
      expect(content, contains('late final form = MonitorFormObject();'));
      expect(content, contains('void onClose() {\n    form.dispose();\n  }'));
    });

    test(
      'a nested view name computes the relative controller import from its depth',
      () async {
        final cmd = MakeViewCommand(testRoot: projectRoot.path);
        final code = await cmd.handle(
          buildCommandContext(cmd, <String>[
            'Monitors/MonitorsList',
            '--controller=Monitor',
          ]),
        );

        expect(code, 0);
        final content = readFile([
          'lib',
          'resources',
          'views',
          'monitors',
          'monitors_list_view.dart',
        ]);
        expect(
          content,
          contains(
            "import '../../../app/controllers/monitor_controller.dart';",
          ),
        );
      },
    );

    test('--test chains make:test --kind=view', () async {
      final cmd = MakeViewCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Monitor', '--test']),
      );

      expect(code, 0);
      expect(
        File(
          p.join(
            projectRoot.path,
            'test',
            'resources',
            'views',
            'monitor_view_test.dart',
          ),
        ).existsSync(),
        isTrue,
      );
    });

    test('returns 1 when the name argument is missing', () async {
      final cmd = MakeViewCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(buildCommandContext(cmd, <String>[]));
      expect(code, 1);
    });
  });
}
