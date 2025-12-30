import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

/// A simple test service for testing container bindings.
class TestService {
  final String name;
  TestService([this.name = 'default']);
}

/// A test service provider.
class TestServiceProvider extends ServiceProvider {
  bool registerCalled = false;
  bool bootCalled = false;

  TestServiceProvider(super.app);

  @override
  void register() {
    registerCalled = true;
    app.singleton('test.service', () => TestService('from-provider'));
  }

  @override
  Future<void> boot() async {
    bootCalled = true;
  }
}

void main() {
  // Reset the container before each test
  setUp(() {
    MagicApp.reset();
  });

  group('MagicApp Container', () {
    test('bind() registers a factory that creates new instances each call', () {
      final app = MagicApp.instance;

      int callCount = 0;
      app.bind('counter', () {
        callCount++;
        return TestService('instance-$callCount');
      });

      final first = app.make<TestService>('counter');
      final second = app.make<TestService>('counter');

      expect(first.name, 'instance-1');
      expect(second.name, 'instance-2');
      expect(callCount, 2);
      expect(identical(first, second), isFalse);
    });

    test('singleton() registers a factory that returns the same instance', () {
      final app = MagicApp.instance;

      int callCount = 0;
      app.singleton('single', () {
        callCount++;
        return TestService('singleton');
      });

      final first = app.make<TestService>('single');
      final second = app.make<TestService>('single');

      expect(first.name, 'singleton');
      expect(callCount, 1); // Factory called only once
      expect(identical(first, second), isTrue);
    });

    test('make() resolves registered bindings', () {
      final app = MagicApp.instance;
      app.bind('service', () => TestService('resolved'));

      final service = app.make<TestService>('service');

      expect(service, isA<TestService>());
      expect(service.name, 'resolved');
    });

    test('make() throws Exception for unregistered keys', () {
      final app = MagicApp.instance;

      expect(
        () => app.make<TestService>('unknown'),
        throwsA(isA<Exception>()),
      );
    });

    test('bound() checks if a service is registered', () {
      final app = MagicApp.instance;

      expect(app.bound('service'), isFalse);

      app.bind('service', () => TestService());

      expect(app.bound('service'), isTrue);
    });

    test('setInstance() stores an existing instance directly', () {
      final app = MagicApp.instance;
      final existing = TestService('existing');

      app.setInstance('existing', existing);

      final resolved = app.make<TestService>('existing');
      expect(identical(resolved, existing), isTrue);
    });

    test('flush() clears all bindings and instances', () {
      final app = MagicApp.instance;
      app.singleton('service', () => TestService('singleton'));
      app.make<TestService>('service'); // Resolve to cache it

      app.flush();

      expect(app.bound('service'), isFalse);
    });
  });

  group('ServiceProvider', () {
    test('register() adds providers and calls their register() method', () {
      final app = MagicApp.instance;
      final provider = TestServiceProvider(app);

      expect(provider.registerCalled, isFalse);

      app.register(provider);

      expect(provider.registerCalled, isTrue);
      expect(app.bound('test.service'), isTrue);
    });

    test('boot() calls boot() on all registered providers', () async {
      final app = MagicApp.instance;
      final provider1 = TestServiceProvider(app);
      final provider2 = TestServiceProvider(app);

      app.register(provider1);
      app.register(provider2);

      expect(provider1.bootCalled, isFalse);
      expect(provider2.bootCalled, isFalse);
      expect(app.isBooted, isFalse);

      await app.boot();

      expect(provider1.bootCalled, isTrue);
      expect(provider2.bootCalled, isTrue);
      expect(app.isBooted, isTrue);
    });

    test('boot() is idempotent - only boots once', () async {
      final app = MagicApp.instance;
      int bootCount = 0;

      final provider = _CountingProvider(app, onBoot: () => bootCount++);
      app.register(provider);

      await app.boot();
      await app.boot();
      await app.boot();

      expect(bootCount, 1);
    });
  });

  group('Magic Facade', () {
    test('Magic.bind() proxies to container correctly', () {
      Magic.bind('facade.service', () => TestService('via-facade'));

      final service = Magic.make<TestService>('facade.service');

      expect(service.name, 'via-facade');
    });

    test('Magic.singleton() creates shared bindings', () {
      Magic.singleton('facade.singleton', () => TestService('shared'));

      final first = Magic.make<TestService>('facade.singleton');
      final second = Magic.make<TestService>('facade.singleton');

      expect(identical(first, second), isTrue);
    });

    test('Magic.app returns the application instance', () {
      expect(Magic.app, isA<MagicApp>());
      expect(identical(Magic.app, MagicApp.instance), isTrue);
    });

    test('Magic.register() registers service providers', () {
      final provider = TestServiceProvider(Magic.app);

      Magic.register(provider);

      expect(provider.registerCalled, isTrue);
      expect(Magic.bound('test.service'), isTrue);
    });

    test('Magic.boot() boots all providers', () async {
      final provider = TestServiceProvider(Magic.app);
      Magic.register(provider);

      Magic.boot();

      expect(provider.bootCalled, isTrue);
    });

    test('Magic.flush() resets the container', () {
      Magic.singleton('temp', () => TestService('temporary'));
      Magic.make<TestService>('temp');

      Magic.flush();

      expect(Magic.bound('temp'), isFalse);
    });
  });
}

/// Helper provider for counting boot calls.
class _CountingProvider extends ServiceProvider {
  final void Function() onBoot;

  _CountingProvider(super.app, {required this.onBoot});

  @override
  void register() {}

  @override
  Future<void> boot() async => onBoot();
}
