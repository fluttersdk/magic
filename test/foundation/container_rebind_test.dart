import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

class _Service {
  _Service(this.tag);
  final String tag;
}

/// Records what ran and when, so a boot that never happens is visible.
class _RecordingProvider extends ServiceProvider {
  _RecordingProvider(super.app, this.tag);

  final String tag;
  int registerCalls = 0;
  int bootCalls = 0;

  @override
  void register() {
    registerCalls++;
    app.singleton('recorded.$tag', () => _Service(tag));
  }

  @override
  Future<void> boot() async {
    bootCalls++;
  }
}

void main() {
  setUp(MagicApp.reset);

  group('rebinding a key drops the instance resolved from the old binding', () {
    test('a singleton rebound after resolution serves the new factory', () {
      // The override pattern this protects: a starter package binds a service
      // in its provider, the consuming app rebinds the same key to its own
      // implementation. If anything resolved the key in between, the container
      // kept answering with the first instance and the override silently did
      // nothing.
      final app = MagicApp.instance;
      app.singleton('svc', () => _Service('starter'));

      expect(app.make<_Service>('svc').tag, 'starter');

      app.singleton('svc', () => _Service('app'));

      expect(app.make<_Service>('svc').tag, 'app');
    });

    test(
      'rebinding to a non-shared factory also drops the cached instance',
      () {
        final app = MagicApp.instance;
        app.singleton('svc', () => _Service('shared'));
        app.make<_Service>('svc');

        var n = 0;
        app.bind('svc', () => _Service('fresh${n++}'));

        expect(app.make<_Service>('svc').tag, 'fresh0');
        expect(
          app.make<_Service>('svc').tag,
          'fresh1',
          reason: 'the rebound factory is not shared, so each call is new',
        );
      },
    );

    test('a singleton still returns one instance when it is not rebound', () {
      // The eviction must not defeat the point of a singleton.
      final app = MagicApp.instance;
      app.singleton('svc', () => _Service('once'));

      expect(
        identical(app.make<_Service>('svc'), app.make<_Service>('svc')),
        isTrue,
      );
    });

    test('setInstance still wins until the key is rebound', () {
      final app = MagicApp.instance;
      final fixed = _Service('fixed');
      app.singleton('svc', () => _Service('factory'));
      app.setInstance('svc', fixed);

      expect(identical(app.make<_Service>('svc'), fixed), isTrue);

      app.singleton('svc', () => _Service('rebound'));
      expect(app.make<_Service>('svc').tag, 'rebound');
    });
  });

  group('a provider registered after boot is booted', () {
    test('registering after boot() runs the provider boot too', () async {
      // `boot()` early-returns once the app is booted, so a provider added
      // later had its register() run and its boot() silently skipped: half an
      // initialisation, with no error to say so. Plugins that install
      // themselves lazily land in exactly this window.
      final app = MagicApp.instance;
      await app.boot();
      expect(app.isBooted, isTrue);

      final late = _RecordingProvider(app, 'late');
      app.register(late);

      // register() is synchronous but the boot it triggers is not.
      await Future<void>.delayed(Duration.zero);

      expect(late.registerCalls, 1);
      expect(late.bootCalls, 1, reason: 'a late provider still needs booting');
    });

    test('a provider registered before boot is booted exactly once', () async {
      final app = MagicApp.instance;
      final early = _RecordingProvider(app, 'early');
      app.register(early);

      expect(early.bootCalls, 0, reason: 'boot waits for the boot phase');

      await app.boot();
      expect(early.bootCalls, 1);

      await app.boot();
      expect(early.bootCalls, 1, reason: 'boot() is idempotent');
    });

    test(
      'registering the same instance twice registers and boots it once',
      () async {
        // Two registrations of one instance ran its boot twice, which for a
        // provider that starts polling or attaches a listener means two of them.
        final app = MagicApp.instance;
        final provider = _RecordingProvider(app, 'dup');

        app.register(provider);
        app.register(provider);
        await app.boot();

        expect(provider.registerCalls, 1);
        expect(provider.bootCalls, 1);
      },
    );

    test(
      'two instances of the same provider class both register and boot',
      () async {
        // The guard is identity, not class. A provider class parameterised per
        // plugin and registered once per plugin is a legitimate shape, and a
        // by-class guard would silently drop all but the first. Laravel guards
        // by class; this deliberately diverges.
        final app = MagicApp.instance;
        final a = _RecordingProvider(app, 'a');
        final b = _RecordingProvider(app, 'b');

        app.register(a);
        app.register(b);
        await app.boot();

        expect(a.bootCalls, 1);
        expect(b.bootCalls, 1);
        expect(app.bound('recorded.a'), isTrue);
        expect(app.bound('recorded.b'), isTrue);
      },
    );
  });
}
