import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_artisan/artisan.dart';
import 'package:magic/src/cli/commands/make_enum_command.dart';
import 'package:path/path.dart' as p;

import '_harness.dart';

void main() {
  group('MakeEnumCommand metadata', () {
    final cmd = MakeEnumCommand();

    test('declares name make:enum', () {
      expect(cmd.name, 'make:enum');
    });

    test('declares CommandBoot.none', () {
      expect(cmd.boot, CommandBoot.none);
    });
  });

  group('MakeEnumCommand.handle()', () {
    late Directory projectRoot;

    setUp(() {
      projectRoot = Directory.systemTemp.createTempSync('make_enum_');
    });

    tearDown(() {
      if (projectRoot.existsSync()) projectRoot.deleteSync(recursive: true);
    });

    test('scaffolds the plain value/label enum by default', () async {
      final cmd = MakeEnumCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['MonitorType']),
      );

      expect(code, 0);
      final file = File(
        p.join(projectRoot.path, 'lib', 'app', 'enums', 'monitor_type.dart'),
      );
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, contains('enum MonitorType {'));
      expect(content, contains('static MonitorType? fromValue(String? value)'));
      expect(content, isNot(contains('fromWire')));
    });

    test('scaffolds a wire-backed enum with --wire', () async {
      final cmd = MakeEnumCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['IncidentSeverity', '--wire']),
      );

      expect(code, 0);
      final file = File(
        p.join(
          projectRoot.path,
          'lib',
          'app',
          'enums',
          'incident_severity.dart',
        ),
      );
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(
        content,
        contains('static IncidentSeverity fromWire(Object? value'),
      );
      expect(content, contains("trans('enums.incident_severity."));
      expect(content, contains("unknown('unknown')"));
      expect(content, contains('final String wire;'));
    });

    test(
      'derives the snake key MonitorRegion -> monitor_region for --wire',
      () async {
        final cmd = MakeEnumCommand(testRoot: projectRoot.path);
        final code = await cmd.handle(
          buildCommandContext(cmd, <String>['MonitorRegion', '--wire']),
        );

        expect(code, 0);
        final file = File(
          p.join(
            projectRoot.path,
            'lib',
            'app',
            'enums',
            'monitor_region.dart',
          ),
        );
        expect(
          file.readAsStringSync(),
          contains("trans('enums.monitor_region."),
        );
      },
    );
  });
}
