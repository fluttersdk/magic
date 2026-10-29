import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

class _RecordingProvider extends ServiceProvider {
  final String name;
  final List<String> log;

  _RecordingProvider(super.app, this.name, this.log);

  @override
  void register() => log.add('register:$name');

  @override
  Future<void> boot() async => log.add('boot:$name');
}

class _FirstNotifier extends ChangeNotifier {
  final List<String> log;

  _FirstNotifier(this.log);

  @override
  void dispose() {
    log.add('dispose:first');
    super.dispose();
  }
}

class _SecondNotifier extends ChangeNotifier {
  final List<String> log;

  _SecondNotifier(this.log);

  @override
  void dispose() {
    log.add('dispose:second');
    super.dispose();
  }
}

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  tearDown(() {
    Magic.flush();
    SessionScope.detach();
    MagicRouter.reset();
  });

  group('MagicTest.bootProviders()', () {
    test(
      'registers every provider before booting any, in list order',
      () async {
        final log = <String>[];

        await MagicTest.bootProviders([
          _RecordingProvider(Magic.app, 'a', log),
          _RecordingProvider(Magic.app, 'b', log),
        ]);

        expect(log, ['register:a', 'register:b', 'boot:a', 'boot:b']);
      },
    );

    test('leaves the application booted', () async {
      await MagicTest.bootProviders([_RecordingProvider(Magic.app, 'a', [])]);

      expect(Magic.app.isBooted, isTrue);
    });
  });

  group('MagicTest.disposeBooted()', () {
    test(
      'disposes controllers dependents first, then flushes the container',
      () {
        final log = <String>[];
        Magic.put<_FirstNotifier>(_FirstNotifier(log));
        Magic.put<_SecondNotifier>(_SecondNotifier(log));
        Magic.app.bind('bound', () => Object());

        MagicTest.disposeBooted();

        expect(log, ['dispose:second', 'dispose:first']);
        expect(Magic.controllers, isEmpty);
        expect(Magic.app.bound('bound'), isFalse);
      },
    );

    test('detaches SessionScope from auth state', () {
      Auth.fake();
      SessionScope.attach();
      expect(SessionScope.isAttached, isTrue);

      MagicTest.disposeBooted();

      expect(SessionScope.isAttached, isFalse);
    });

    test('resets the routes a boot registered', () {
      MagicRoute.page('/booted', () => const SizedBox());
      expect(MagicRouter.instance.routes, isNotEmpty);

      MagicTest.disposeBooted();

      expect(MagicRouter.instance.routes, isEmpty);
    });
  });
}
