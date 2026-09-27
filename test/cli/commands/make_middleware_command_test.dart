import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_artisan/artisan.dart';
import 'package:magic/src/cli/commands/make_middleware_command.dart';
import 'package:path/path.dart' as p;

import '_harness.dart';

void main() {
  group('MakeMiddlewareCommand metadata', () {
    final cmd = MakeMiddlewareCommand();

    test('declares name make:middleware', () {
      expect(cmd.name, 'make:middleware');
    });

    test('extends ArtisanGeneratorCommand', () {
      expect(cmd, isA<ArtisanGeneratorCommand>());
    });

    test('declares CommandBoot.none', () {
      expect(cmd.boot, CommandBoot.none);
    });
  });

  group('MakeMiddlewareCommand.handle()', () {
    late Directory projectRoot;

    setUp(() {
      projectRoot = Directory.systemTemp.createTempSync('make_middleware_');
    });

    tearDown(() {
      if (projectRoot.existsSync()) projectRoot.deleteSync(recursive: true);
    });

    test(
      'scaffolds a middleware extending MagicMiddleware with handle(next)',
      () async {
        final cmd = MakeMiddlewareCommand(testRoot: projectRoot.path);
        final code = await cmd.handle(
          buildCommandContext(cmd, <String>['EnsureAuthenticated']),
        );

        expect(code, 0);
        final file = File(
          p.join(
            projectRoot.path,
            'lib',
            'app',
            'middleware',
            'ensure_authenticated.dart',
          ),
        );
        expect(file.existsSync(), isTrue);

        final content = file.readAsStringSync();
        expect(
          content,
          contains('class EnsureAuthenticated extends MagicMiddleware'),
        );
        expect(content, contains('Future<void> handle(void Function() next)'));
      },
    );

    test('supports a nested name', () async {
      final cmd = MakeMiddlewareCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Admin/RoleCheck']),
      );

      expect(code, 0);
      final file = File(
        p.join(
          projectRoot.path,
          'lib',
          'app',
          'middleware',
          'admin',
          'role_check.dart',
        ),
      );
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), contains('class RoleCheck'));
    });

    test('returns 1 when the name argument is missing', () async {
      final cmd = MakeMiddlewareCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(buildCommandContext(cmd, <String>[]));
      expect(code, 1);
    });

    test('returns 1 when the file already exists without --force', () async {
      final cmd = MakeMiddlewareCommand(testRoot: projectRoot.path);
      await cmd.handle(
        buildCommandContext(cmd, <String>['EnsureAuthenticated']),
      );

      final second = MakeMiddlewareCommand(testRoot: projectRoot.path);
      final code = await second.handle(
        buildCommandContext(second, <String>['EnsureAuthenticated']),
      );
      expect(code, 1);
    });
  });
}
