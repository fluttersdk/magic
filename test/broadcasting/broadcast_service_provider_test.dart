import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    BroadcastManager.resetDrivers();
  });

  group('BroadcastServiceProvider — registration', () {
    test('extends ServiceProvider', () {
      final provider = BroadcastServiceProvider(MagicApp.instance);

      expect(provider, isA<ServiceProvider>());
    });

    test(
      'register() binds BroadcastManager singleton under "broadcasting"',
      () {
        final app = MagicApp.instance;
        final provider = BroadcastServiceProvider(app);

        provider.register();

        expect(
          app.make<BroadcastManager>('broadcasting'),
          isA<BroadcastManager>(),
        );
      },
    );

    test(
      'register() binds a true singleton — same instance on repeated resolution',
      () {
        final app = MagicApp.instance;
        final provider = BroadcastServiceProvider(app);

        provider.register();

        final first = app.make<BroadcastManager>('broadcasting');
        final second = app.make<BroadcastManager>('broadcasting');

        expect(identical(first, second), isTrue);
      },
    );
  });

  group('BroadcastServiceProvider — boot with null driver', () {
    test('boot() completes without error when default is "null"', () async {
      Config.set('broadcasting.default', 'null');
      Config.set('broadcasting.connections', {
        'null': <String, dynamic>{'driver': 'null'},
      });

      final app = MagicApp.instance;
      final provider = BroadcastServiceProvider(app);

      provider.register();

      await expectLater(provider.boot(), completes);
    });

    test('boot() skips connect() when default is "null"', () async {
      var connectCalled = false;

      BroadcastManager.extend('null', (Map<String, dynamic> config) {
        return _SpyNullDriver(onConnect: () => connectCalled = true);
      });

      Config.set('broadcasting.default', 'null');
      Config.set('broadcasting.connections', {
        'null': <String, dynamic>{'driver': 'null'},
      });

      final app = MagicApp.instance;
      final provider = BroadcastServiceProvider(app);

      provider.register();
      await provider.boot();

      expect(connectCalled, isFalse);
    });
  });
}

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// Spy driver that records whether [connect] was invoked.
class _SpyNullDriver implements BroadcastDriver {
  final void Function() onConnect;

  _SpyNullDriver({required this.onConnect});

  @override
  Future<void> connect() async => onConnect();

  @override
  Future<void> disconnect() async {}

  @override
  String? get socketId => null;

  @override
  bool get isConnected => false;

  @override
  Stream<BroadcastConnectionState> get connectionState => const Stream.empty();

  @override
  Stream<void> get onReconnect => const Stream.empty();

  @override
  BroadcastChannel channel(String name) => throw UnimplementedError();

  @override
  BroadcastChannel private(String name) => throw UnimplementedError();

  @override
  BroadcastPresenceChannel join(String name) => throw UnimplementedError();

  @override
  void leave(String name) {}

  @override
  void addInterceptor(BroadcastInterceptor interceptor) {}
}
