import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_artisan/artisan.dart';
import 'package:magic/src/cli/commands/make_listener_command.dart';
import 'package:path/path.dart' as p;

import '_harness.dart';

void main() {
  group('MakeListenerCommand metadata', () {
    final cmd = MakeListenerCommand();

    test('declares name make:listener', () {
      expect(cmd.name, 'make:listener');
    });

    test('extends ArtisanGeneratorCommand', () {
      expect(cmd, isA<ArtisanGeneratorCommand>());
    });

    test('declares CommandBoot.none', () {
      expect(cmd.boot, CommandBoot.none);
    });
  });

  group('MakeListenerCommand.handle()', () {
    late Directory projectRoot;

    setUp(() {
      projectRoot = Directory.systemTemp.createTempSync('make_listener_');
    });

    tearDown(() {
      if (projectRoot.existsSync()) projectRoot.deleteSync(recursive: true);
    });

    test(
      'scaffolds a listener extending MagicListener<T> with --event',
      () async {
        final cmd = MakeListenerCommand(testRoot: projectRoot.path);
        final code = await cmd.handle(
          buildCommandContext(cmd, <String>[
            'AuthRestore',
            '--event=UserLoggedInEvent',
          ]),
        );

        expect(code, 0);
        final file = File(
          p.join(
            projectRoot.path,
            'lib',
            'app',
            'listeners',
            'auth_restore.dart',
          ),
        );
        expect(file.existsSync(), isTrue);

        final content = file.readAsStringSync();
        expect(
          content,
          contains(
            'class AuthRestore extends MagicListener<UserLoggedInEvent>',
          ),
        );
        expect(
          content,
          contains("import '../events/user_logged_in_event.dart';"),
        );
      },
    );

    test('defaults to MagicEvent when --event is omitted', () async {
      final cmd = MakeListenerCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['AuthRestore']),
      );

      expect(code, 0);
      final file = File(
        p.join(
          projectRoot.path,
          'lib',
          'app',
          'listeners',
          'auth_restore.dart',
        ),
      );
      final content = file.readAsStringSync();
      expect(
        content,
        contains('class AuthRestore extends MagicListener<MagicEvent>'),
      );
    });

    test('supports a nested name', () async {
      final cmd = MakeListenerCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Auth/RestoreSession']),
      );

      expect(code, 0);
      final file = File(
        p.join(
          projectRoot.path,
          'lib',
          'app',
          'listeners',
          'auth',
          'restore_session.dart',
        ),
      );
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), contains('class RestoreSession'));
    });

    test('returns 1 when the name argument is missing', () async {
      final cmd = MakeListenerCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(buildCommandContext(cmd, <String>[]));
      expect(code, 1);
    });

    test('returns 1 when the file already exists without --force', () async {
      final cmd = MakeListenerCommand(testRoot: projectRoot.path);
      await cmd.handle(buildCommandContext(cmd, <String>['AuthRestore']));

      final second = MakeListenerCommand(testRoot: projectRoot.path);
      final code = await second.handle(
        buildCommandContext(second, <String>['AuthRestore']),
      );
      expect(code, 1);
    });
  });
}
