import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Registers the minimal broadcasting config that resolves to NullBroadcastDriver.
void _setNullConfig() {
  Config.set('broadcasting.default', 'null');
  Config.set('broadcasting.connections', {
    'null': {'driver': 'null'},
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    BroadcastManager.resetDrivers();
    Magic.app.singleton('broadcasting', () => BroadcastManager());
    _setNullConfig();
  });

  group('Echo facade — channel methods', () {
    test('channel() returns a BroadcastChannel', () {
      final result = Echo.channel('orders');
      expect(result, isA<BroadcastChannel>());
    });

    test('private() returns a BroadcastChannel', () {
      final result = Echo.private('user.1');
      expect(result, isA<BroadcastChannel>());
    });

    test('join() returns a BroadcastPresenceChannel', () {
      final result = Echo.join('room.1');
      expect(result, isA<BroadcastPresenceChannel>());
    });
  });

  group('Echo facade — connection lifecycle', () {
    test('connect() completes without error', () async {
      await expectLater(Echo.connect(), completes);
    });

    test('disconnect() completes without error', () async {
      await expectLater(Echo.disconnect(), completes);
    });
  });

  group('Echo facade — driver accessors', () {
    test('connection getter returns a BroadcastDriver', () {
      expect(Echo.connection, isA<BroadcastDriver>());
    });

    test('socketId returns null for NullBroadcastDriver', () {
      expect(Echo.socketId, isNull);
    });

    test('connectionState returns a stream', () {
      expect(Echo.connectionState, isA<Stream>());
    });

    test('onReconnect returns a stream', () {
      expect(Echo.onReconnect, isA<Stream>());
    });
  });

  group('Echo facade — interceptors', () {
    test('addInterceptor() does not throw', () {
      final interceptor = _NoOpInterceptor();
      expect(() => Echo.addInterceptor(interceptor), returnsNormally);
    });
  });

  group('Echo facade — manager access', () {
    test('manager getter returns the BroadcastManager instance', () {
      expect(Echo.manager, isA<BroadcastManager>());
    });
  });

  group('Echo facade — fake/unfake', () {
    test('fake() replaces manager with FakeBroadcastManager', () {
      final fake = Echo.fake();
      expect(fake, isA<FakeBroadcastManager>());
      expect(Echo.manager, same(fake));
      Echo.unfake();
    });

    test('unfake() restores real manager resolution', () {
      Echo.fake();
      Echo.unfake();
      expect(Echo.manager, isA<BroadcastManager>());
    });
  });
}

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// No-op interceptor used to verify [Echo.addInterceptor] accepts an instance.
class _NoOpInterceptor extends BroadcastInterceptor {}
