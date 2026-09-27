import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_artisan/artisan.dart';
import 'package:magic/src/cli/commands/make_provider_command.dart';
import 'package:path/path.dart' as p;

import '_harness.dart';

void main() {
  group('MakeProviderCommand metadata', () {
    final cmd = MakeProviderCommand();

    test('declares name make:provider', () {
      expect(cmd.name, 'make:provider');
    });

    test('extends ArtisanGeneratorCommand', () {
      expect(cmd, isA<ArtisanGeneratorCommand>());
    });

    test('declares CommandBoot.none', () {
      expect(cmd.boot, CommandBoot.none);
    });
  });

  group('MakeProviderCommand.handle()', () {
    late Directory projectRoot;

    setUp(() {
      projectRoot = Directory.systemTemp.createTempSync('make_provider_');
    });

    tearDown(() {
      if (projectRoot.existsSync()) projectRoot.deleteSync(recursive: true);
    });

    test(
      'scaffolds a provider extending ServiceProvider with the auto-suffix',
      () async {
        final cmd = MakeProviderCommand(testRoot: projectRoot.path);
        final code = await cmd.handle(
          buildCommandContext(cmd, <String>['App']),
        );

        expect(code, 0);
        final file = File(
          p.join(
            projectRoot.path,
            'lib',
            'app',
            'providers',
            'app_service_provider.dart',
          ),
        );
        expect(file.existsSync(), isTrue);

        final content = file.readAsStringSync();
        expect(
          content,
          contains('class AppServiceProvider extends ServiceProvider'),
        );
        expect(content, contains('void register()'));
        expect(content, contains('Future<void> boot()'));
      },
    );

    test(
      'does not double-suffix when ServiceProvider is already present',
      () async {
        final cmd = MakeProviderCommand(testRoot: projectRoot.path);
        final code = await cmd.handle(
          buildCommandContext(cmd, <String>['AppServiceProvider']),
        );

        expect(code, 0);
        final file = File(
          p.join(
            projectRoot.path,
            'lib',
            'app',
            'providers',
            'app_service_provider.dart',
          ),
        );
        expect(file.existsSync(), isTrue);
        expect(
          file.readAsStringSync(),
          contains('class AppServiceProvider extends ServiceProvider'),
        );
      },
    );

    test('supports a nested name', () async {
      final cmd = MakeProviderCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(
        buildCommandContext(cmd, <String>['Billing/Stripe']),
      );

      expect(code, 0);
      final file = File(
        p.join(
          projectRoot.path,
          'lib',
          'app',
          'providers',
          'billing',
          'stripe_service_provider.dart',
        ),
      );
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), contains('class StripeServiceProvider'));
    });

    test('returns 1 when the name argument is missing', () async {
      final cmd = MakeProviderCommand(testRoot: projectRoot.path);
      final code = await cmd.handle(buildCommandContext(cmd, <String>[]));
      expect(code, 1);
    });

    test('returns 1 when the file already exists without --force', () async {
      final cmd = MakeProviderCommand(testRoot: projectRoot.path);
      await cmd.handle(buildCommandContext(cmd, <String>['App']));

      final second = MakeProviderCommand(testRoot: projectRoot.path);
      final code = await second.handle(
        buildCommandContext(second, <String>['App']),
      );
      expect(code, 1);
    });
  });
}
