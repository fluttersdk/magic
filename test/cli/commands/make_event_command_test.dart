import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_artisan/artisan.dart';
import 'package:magic/src/cli/commands/make_event_command.dart';
import 'package:path/path.dart' as p;

import '_harness.dart';

void main() {
  group('MakeEventCommand metadata', () {
    final cmd = MakeEventCommand();

    test('declares name make:event', () {
      expect(cmd.name, 'make:event');
    });

    test('extends ArtisanGeneratorCommand', () {
      expect(cmd, isA<ArtisanGeneratorCommand>());
    });

    test('declares CommandBoot.none', () {
      expect(cmd.boot, CommandBoot.none);
    });
  });

  group('MakeEventCommand.handle()', () {
    late Directory projectRoot;

    setUp(() {
      projectRoot = Directory.systemTemp.createTempSync('make_event_');
    });

    tearDown(() {
      if (projectRoot.existsSync()) projectRoot.deleteSync(recursive: true);
    });

    test('scaffolds an event extending MagicEvent', () async {
      final cmd = MakeEventCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['UserLoggedIn']),
      );

      expect(code, 0);
      final file = File(
        p.join(projectRoot.path, 'lib', 'app', 'events', 'user_logged_in.dart'),
      );
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, contains('class UserLoggedIn extends MagicEvent'));
    });

    test('supports a nested name', () async {
      final cmd = MakeEventCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Auth/TokenRefreshed']),
      );

      expect(code, 0);
      final file = File(
        p.join(
          projectRoot.path,
          'lib',
          'app',
          'events',
          'auth',
          'token_refreshed.dart',
        ),
      );
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), contains('class TokenRefreshed'));
    });

    test('returns 1 when the name argument is missing', () async {
      final cmd = MakeEventCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(buildCommandContext(cmd, <String>[]));
      expect(code, 1);
    });

    test('returns 1 when the file already exists without --force', () async {
      final cmd = MakeEventCommand(testRoot: projectRoot.path);
      await cmd.handle(buildCommandContext(cmd, <String>['UserLoggedIn']));

      final second = MakeEventCommand(testRoot: projectRoot.path);
      final code = await second.handle(
        buildCommandContext(second, <String>['UserLoggedIn']),
      );
      expect(code, 1);
    });
  });
}
