import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/cli/commands/make_form_command.dart';
import 'package:path/path.dart' as p;

/// A bare [ArtisanContext] driving the command with [args].
ArtisanContext _ctx(MakeFormCommand cmd, List<String> args) {
  final parser = ArgParser();
  cmd.configure(parser);
  final input = ArgvInput.parse(parser, args);
  return ArtisanContext.bare(input, BufferedOutput());
}

void main() {
  group('MakeFormCommand metadata', () {
    final cmd = MakeFormCommand();

    test('declares name make:form', () {
      expect(cmd.name, 'make:form');
    });

    test('extends ArtisanGeneratorCommand', () {
      expect(cmd, isA<ArtisanGeneratorCommand>());
    });

    test('declares CommandBoot.none', () {
      expect(cmd.boot, CommandBoot.none);
    });
  });

  group('MakeFormCommand.handle()', () {
    late Directory projectRoot;

    setUp(() {
      projectRoot = Directory.systemTemp.createTempSync('make_form_');
    });

    tearDown(() {
      if (projectRoot.existsSync()) projectRoot.deleteSync(recursive: true);
    });

    test('scaffolds a form object with the FormObject suffix', () async {
      final cmd = MakeFormCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(_ctx(cmd, <String>['Monitor']));

      expect(code, 0);
      final file = File(
        p.join(
          projectRoot.path,
          'lib',
          'app',
          'forms',
          'monitor_form_object.dart',
        ),
      );
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(
        content,
        contains('class MonitorFormObject extends MagicFormObject'),
      );
      expect(content, contains('Map<String, dynamic> get initial'));
      expect(content, contains('FormRequest get request'));
      expect(
        content,
        contains('Future<bool> persist(Map<String, dynamic> validated)'),
      );
    });

    test('does not double-suffix when FormObject is already present', () async {
      final cmd = MakeFormCommand(testRoot: projectRoot.path);
      await cmd.handle(_ctx(cmd, <String>['MonitorFormObject']));

      final file = File(
        p.join(
          projectRoot.path,
          'lib',
          'app',
          'forms',
          'monitor_form_object.dart',
        ),
      );
      expect(file.existsSync(), isTrue);
    });

    test('--request wires a real import and request expression', () async {
      final cmd = MakeFormCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        _ctx(cmd, <String>['Monitor', '--request=StoreMonitorRequest']),
      );

      expect(code, 0);
      final content = File(
        p.join(
          projectRoot.path,
          'lib',
          'app',
          'forms',
          'monitor_form_object.dart',
        ),
      ).readAsStringSync();
      expect(
        content,
        contains("import '../validation/requests/store_monitor_request.dart';"),
      );
      expect(
        content,
        contains('FormRequest get request => StoreMonitorRequest();'),
      );
      expect(
        content,
        isNot(contains('Import your form request and override request')),
      );
    });

    test(
      'without --request leaves a TODO import and an UnimplementedError',
      () async {
        final cmd = MakeFormCommand(testRoot: projectRoot.path);
        await cmd.handle(_ctx(cmd, <String>['Monitor']));

        final content = File(
          p.join(
            projectRoot.path,
            'lib',
            'app',
            'forms',
            'monitor_form_object.dart',
          ),
        ).readAsStringSync();
        expect(content, contains('// TODO: Import your form request'));
        expect(content, contains('UnimplementedError'));
      },
    );

    test('returns 1 when the name argument is missing', () async {
      final cmd = MakeFormCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(_ctx(cmd, <String>[]));
      expect(code, 1);
    });
  });
}
