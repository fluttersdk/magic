import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_artisan/artisan.dart';
import 'package:magic/src/cli/commands/make_resource_command.dart';
import 'package:magic/src/cli/magic_artisan_provider.dart';
import 'package:path/path.dart' as p;

import '_harness.dart';

/// Every file `make:resource Monitor` writes outside the views, relative to
/// the project root.
const List<String> _coreFiles = <String>[
  'lib/app/models/monitor.dart',
  'lib/database/factories/monitor_factory.dart',
  'lib/app/repositories/monitor_repository.dart',
  'lib/app/actions/monitors/create_monitor.dart',
  'lib/app/actions/monitors/update_monitor.dart',
  'lib/app/actions/monitors/delete_monitor.dart',
  'lib/app/validation/requests/store_monitor_request.dart',
  'lib/app/validation/requests/update_monitor_request.dart',
  'lib/app/forms/monitor_form_object.dart',
  'lib/app/controllers/monitor_controller.dart',
  'test/app/actions/monitors/create_monitor_test.dart',
  'test/app/actions/monitors/update_monitor_test.dart',
  'test/app/actions/monitors/delete_monitor_test.dart',
  'test/app/forms/monitor_form_object_test.dart',
  'test/app/controllers/monitor_controller_test.dart',
];

/// The two views `make:resource Monitor` writes unless `--no-views`.
const List<String> _viewFiles = <String>[
  'lib/resources/views/monitors/monitors_list_view.dart',
  'lib/resources/views/monitors/monitor_form_view.dart',
];

void main() {
  group('MakeResourceCommand metadata', () {
    final cmd = MakeResourceCommand();

    test('declares name make:resource', () {
      expect(cmd.name, 'make:resource');
    });

    test('declares CommandBoot.none', () {
      expect(cmd.boot, CommandBoot.none);
    });

    test('is registered by MagicArtisanProvider', () {
      final names = MagicArtisanProvider().commands().map((c) => c.name);
      expect(names, contains('make:resource'));
    });
  });

  group('MakeResourceCommand.handle()', () {
    late Directory projectRoot;

    File file(String relative) => File(p.join(projectRoot.path, relative));

    Future<(int, String)> run(List<String> args) async {
      final cmd = MakeResourceCommand(testRoot: projectRoot.path);
      final ctx = buildCommandContext(cmd, args);
      final code = await cmd.handle(ctx);
      return (code, (ctx.output as BufferedOutput).content);
    }

    setUp(() {
      projectRoot = Directory.systemTemp.createTempSync('make_resource_');
      file('pubspec.yaml').writeAsStringSync('name: app\n');
    });

    tearDown(() {
      if (projectRoot.existsSync()) projectRoot.deleteSync(recursive: true);
    });

    test('writes every file of the vertical at its path', () async {
      final (code, _) = await run(<String>['Monitor']);

      expect(code, 0);
      for (final relative in <String>[..._coreFiles, ..._viewFiles]) {
        expect(file(relative).existsSync(), isTrue, reason: relative);
      }

      expect(
        file('lib/app/actions/monitors/create_monitor.dart').readAsStringSync(),
        contains('class CreateMonitor'),
      );
      expect(
        file('lib/app/forms/monitor_form_object.dart').readAsStringSync(),
        contains('StoreMonitorRequest'),
      );
      expect(
        file('lib/app/controllers/monitor_controller.dart').readAsStringSync(),
        allOf(contains('RunsActions'), contains('MonitorRepository')),
      );
      expect(
        file(_viewFiles.first).readAsStringSync(),
        contains('RefetchesOnMount<MonitorController, MonitorsListView>'),
      );
      expect(
        file(_viewFiles.last).readAsStringSync(),
        contains('late final form = MonitorFormObject();'),
      );
    });

    test('prints the route lines and never touches a routes file', () async {
      final (code, output) = await run(<String>['Monitor']);

      expect(code, 0);
      expect(
        output,
        contains(
          "MagicRoute.page('/monitors', () => const MonitorsListView())"
          ".name('monitors.index');",
        ),
      );
      expect(
        output,
        contains(
          "MagicRoute.page('/monitors/create', () => const MonitorFormView())"
          ".name('monitors.create').stacked();",
        ),
      );
      expect(
        Directory(p.join(projectRoot.path, 'lib', 'routes')).existsSync(),
        isFalse,
      );
    });

    test('--no-views omits the views and the route lines', () async {
      final (code, output) = await run(<String>['Monitor', '--no-views']);

      expect(code, 0);
      for (final relative in _coreFiles) {
        expect(file(relative).existsSync(), isTrue, reason: relative);
      }
      for (final relative in _viewFiles) {
        expect(file(relative).existsSync(), isFalse, reason: relative);
      }
      expect(output, isNot(contains('MagicRoute.page')));
    });

    test('--no-model omits the model and its factory', () async {
      final (code, _) = await run(<String>['Monitor', '--no-model']);

      expect(code, 0);
      expect(file('lib/app/models/monitor.dart').existsSync(), isFalse);
      expect(
        file('lib/database/factories/monitor_factory.dart').existsSync(),
        isFalse,
      );
      expect(
        file('lib/app/repositories/monitor_repository.dart').existsSync(),
        isTrue,
      );
    });

    test('skips an existing model with a note and writes the rest', () async {
      const existing = '// hand-written model\n';
      file('lib/app/models/monitor.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync(existing);

      final (code, output) = await run(<String>['Monitor']);

      expect(code, 0);
      expect(file('lib/app/models/monitor.dart').readAsStringSync(), existing);
      expect(output, contains('Skipped'));
      expect(output, contains(p.join('lib', 'app', 'models', 'monitor.dart')));
      for (final relative in _coreFiles.skip(1)) {
        expect(file(relative).existsSync(), isTrue, reason: relative);
      }
    });

    test('a second run without --force exits 1 and changes no file', () async {
      final (first, _) = await run(<String>['Monitor']);
      expect(first, 0);

      // Backdate every written file so any rewrite shows up as a new mtime.
      final backdated = DateTime(2000);
      final written = <String>[..._coreFiles, ..._viewFiles];
      for (final relative in written) {
        file(relative).setLastModifiedSync(backdated);
      }

      final (second, output) = await run(<String>['Monitor']);

      expect(second, 1);
      expect(
        output,
        contains(
          p.join('lib', 'app', 'repositories', 'monitor_repository.dart'),
        ),
      );
      for (final relative in written) {
        expect(file(relative).lastModifiedSync(), backdated, reason: relative);
      }
    });

    test('a clash on one file writes nothing at all', () async {
      file('lib/app/forms/monitor_form_object.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('// existing form\n');

      final (code, output) = await run(<String>['Monitor']);

      expect(code, 1);
      expect(
        output,
        contains(p.join('lib', 'app', 'forms', 'monitor_form_object.dart')),
      );
      expect(file('lib/app/models/monitor.dart').existsSync(), isFalse);
      expect(
        file('lib/app/repositories/monitor_repository.dart').existsSync(),
        isFalse,
      );
    });

    test('--force overwrites the clashes, tests included', () async {
      await run(<String>['Monitor']);
      file(
        'test/app/forms/monitor_form_object_test.dart',
      ).writeAsStringSync('// stale\n');

      final (code, _) = await run(<String>['Monitor', '--force']);

      expect(code, 0);
      expect(
        file('test/app/forms/monitor_form_object_test.dart').readAsStringSync(),
        contains('MonitorFormObject'),
      );
    });

    test('leaves an unrelated file byte-identical', () async {
      final unrelated = file('lib/app/services/billing.dart')
        ..createSync(recursive: true)
        ..writeAsBytesSync(<int>[0, 1, 2, 255, 10]);

      final (code, _) = await run(<String>['Monitor']);

      expect(code, 0);
      expect(unrelated.readAsBytesSync(), <int>[0, 1, 2, 255, 10]);
    });

    test('exits 1 without a name', () async {
      final (code, output) = await run(<String>[]);

      expect(code, 1);
      expect(output, contains('Not enough arguments'));
    });
  });
}
