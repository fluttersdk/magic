import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/cli/commands/make_action_command.dart';
import 'package:path/path.dart' as p;

/// A bare [ArtisanContext] driving the command with [args].
ArtisanContext _ctx(MakeActionCommand cmd, List<String> args) {
  final parser = ArgParser();
  cmd.configure(parser);
  final input = ArgvInput.parse(parser, args);
  return ArtisanContext.bare(input, BufferedOutput());
}

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
      final code = await cmd.handle(_ctx(cmd, <String>['PauseMonitor']));

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
        _ctx(cmd, <String>['Monitors/PauseMonitor']),
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
      final code = await cmd.handle(_ctx(cmd, <String>[]));
      expect(code, 1);
    });

    test('returns 1 when the file already exists without --force', () async {
      final cmd = MakeActionCommand(testRoot: projectRoot.path);
      await cmd.handle(_ctx(cmd, <String>['PauseMonitor']));

      final second = MakeActionCommand(testRoot: projectRoot.path);
      final code = await second.handle(_ctx(second, <String>['PauseMonitor']));
      expect(code, 1);
    });
  });
}
