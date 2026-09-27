import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_artisan/artisan.dart';
import 'package:magic/src/cli/commands/make_policy_command.dart';
import 'package:path/path.dart' as p;

import '_harness.dart';

void main() {
  group('MakePolicyCommand metadata', () {
    final cmd = MakePolicyCommand();

    test('declares name make:policy', () {
      expect(cmd.name, 'make:policy');
    });

    test('extends ArtisanGeneratorCommand', () {
      expect(cmd, isA<ArtisanGeneratorCommand>());
    });

    test('declares CommandBoot.none', () {
      expect(cmd.boot, CommandBoot.none);
    });
  });

  group('MakePolicyCommand.handle()', () {
    late Directory projectRoot;

    setUp(() {
      projectRoot = Directory.systemTemp.createTempSync('make_policy_');
    });

    tearDown(() {
      if (projectRoot.existsSync()) projectRoot.deleteSync(recursive: true);
    });

    test('scaffolds a policy extending Policy with --model', () async {
      final cmd = MakePolicyCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Monitor', '--model=Monitor']),
      );

      expect(code, 0);
      final file = File(
        p.join(
          projectRoot.path,
          'lib',
          'app',
          'policies',
          'monitor_policy.dart',
        ),
      );
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, contains('class MonitorPolicy extends Policy'));
      expect(content, contains("Gate.define('view-monitor', _view)"));
    });

    test('supports a nested name', () async {
      final cmd = MakePolicyCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Admin/Dashboard']),
      );

      expect(code, 0);
      final file = File(
        p.join(
          projectRoot.path,
          'lib',
          'app',
          'policies',
          'admin',
          'dashboard_policy.dart',
        ),
      );
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), contains('class DashboardPolicy'));
    });

    test('returns 1 when the name argument is missing', () async {
      final cmd = MakePolicyCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(buildCommandContext(cmd, <String>[]));
      expect(code, 1);
    });

    test('returns 1 when the file already exists without --force', () async {
      final cmd = MakePolicyCommand(testRoot: projectRoot.path);
      await cmd.handle(buildCommandContext(cmd, <String>['Monitor']));

      final second = MakePolicyCommand(testRoot: projectRoot.path);
      final code = await second.handle(
        buildCommandContext(second, <String>['Monitor']),
      );
      expect(code, 1);
    });
  });
}
