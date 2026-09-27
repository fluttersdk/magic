import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/cli/commands/make_request_command.dart';
import 'package:path/path.dart' as p;

import '_harness.dart';

void main() {
  group('MakeRequestCommand metadata', () {
    final cmd = MakeRequestCommand();

    test('declares name make:request', () {
      expect(cmd.name, 'make:request');
    });

    test('extends ArtisanGeneratorCommand', () {
      expect(cmd, isA<ArtisanGeneratorCommand>());
    });

    test('declares CommandBoot.none', () {
      expect(cmd.boot, CommandBoot.none);
    });
  });

  group('MakeRequestCommand.handle()', () {
    late Directory projectRoot;

    setUp(() {
      projectRoot = Directory.systemTemp.createTempSync('make_request_');
      File(
        p.join(projectRoot.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: fixture_app\n');
    });

    tearDown(() {
      if (projectRoot.existsSync()) projectRoot.deleteSync(recursive: true);
    });

    test('scaffolds a FormRequest subclass with a const constructor', () async {
      final cmd = MakeRequestCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['StoreMonitor']),
      );

      expect(code, 0);
      final file = File(
        p.join(
          projectRoot.path,
          'lib',
          'app',
          'validation',
          'requests',
          'store_monitor_request.dart',
        ),
      );
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(
        content,
        contains('class StoreMonitorRequest extends FormRequest'),
      );
      expect(content, contains('const StoreMonitorRequest();'));
      expect(content, contains('Map<String, List<Rule>> rules()'));
    });

    test('does not double-suffix when Request is already present', () async {
      final cmd = MakeRequestCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['StoreMonitorRequest']),
      );

      expect(code, 0);
      final file = File(
        p.join(
          projectRoot.path,
          'lib',
          'app',
          'validation',
          'requests',
          'store_monitor_request.dart',
        ),
      );
      expect(file.existsSync(), isTrue);
      expect(
        file.readAsStringSync(),
        contains('class StoreMonitorRequest extends FormRequest'),
      );
    });

    test('returns 1 when the name argument is missing', () async {
      final cmd = MakeRequestCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(buildCommandContext(cmd, <String>[]));
      expect(code, 1);
    });

    test('--test chains make:test --kind=request', () async {
      final cmd = MakeRequestCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['StoreMonitor', '--test']),
      );

      expect(code, 0);
      final testFile = File(
        p.join(
          projectRoot.path,
          'test',
          'app',
          'validation',
          'requests',
          'store_monitor_request_test.dart',
        ),
      );
      expect(testFile.existsSync(), isTrue);
      expect(
        testFile.readAsStringSync(),
        contains(
          "import 'package:fixture_app/app/validation/requests/store_monitor_request.dart';",
        ),
      );
    });
  });
}
