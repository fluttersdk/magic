import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

// ---------------------------------------------------------------------------
// Test stub interceptor
// ---------------------------------------------------------------------------

class _TestInterceptor extends BroadcastInterceptor {}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    BroadcastManager.resetDrivers();
  });

  tearDown(() {
    Echo.unfake();
  });

  // ---------------------------------------------------------------------------
  // 1. Basic operations
  // ---------------------------------------------------------------------------

  group('basic operations', () {
    test('driver is disconnected by default', () {
      final fake = FakeBroadcastManager();
      expect(fake.driver.isConnected, isFalse);
    });

    test('connect() sets isConnected to true', () async {
      final fake = FakeBroadcastManager();
      await fake.connection().connect();
      expect(fake.driver.isConnected, isTrue);
    });

    test('disconnect() sets isConnected to false', () async {
      final fake = FakeBroadcastManager();
      await fake.connection().connect();
      await fake.connection().disconnect();
      expect(fake.driver.isConnected, isFalse);
    });

    test('channel() returns a BroadcastChannel with correct name', () {
      final fake = FakeBroadcastManager();
      final ch = fake.connection().channel('orders');
      expect(ch.name, equals('orders'));
    });

    test('private() returns a channel with private- prefix recorded', () {
      final fake = FakeBroadcastManager();
      fake.connection().private('user.1');
      expect(fake.driver.subscribedChannels, contains('private-user.1'));
    });

    test(
      'join() returns a presence channel with presence- prefix recorded',
      () {
        final fake = FakeBroadcastManager();
        fake.connection().join('room.1');
        expect(fake.driver.subscribedChannels, contains('presence-room.1'));
      },
    );

    test('leave() removes channel from subscribed list', () {
      final fake = FakeBroadcastManager();
      fake.connection().channel('orders');
      fake.connection().leave('orders');
      expect(fake.driver.subscribedChannels, isNot(contains('orders')));
    });

    test('socketId returns fake-socket-id when connected', () async {
      final fake = FakeBroadcastManager();
      await fake.connection().connect();
      expect(fake.driver.socketId, equals('fake-socket-id'));
    });

    test('socketId returns null when disconnected', () {
      final fake = FakeBroadcastManager();
      expect(fake.driver.socketId, isNull);
    });

    test('connectionState returns empty stream', () {
      final fake = FakeBroadcastManager();
      expect(fake.driver.connectionState, isA<Stream>());
    });

    test('onReconnect returns empty stream', () {
      final fake = FakeBroadcastManager();
      expect(fake.driver.onReconnect, isA<Stream>());
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Assertion helpers — assertConnected
  // ---------------------------------------------------------------------------

  group('assertConnected', () {
    test('passes when connected', () async {
      final fake = FakeBroadcastManager();
      await fake.connection().connect();
      expect(() => fake.assertConnected(), returnsNormally);
    });

    test('throws AssertionError when not connected', () {
      final fake = FakeBroadcastManager();
      expect(() => fake.assertConnected(), throwsA(isA<AssertionError>()));
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Assertion helpers — assertDisconnected
  // ---------------------------------------------------------------------------

  group('assertDisconnected', () {
    test('passes when not connected', () {
      final fake = FakeBroadcastManager();
      expect(() => fake.assertDisconnected(), returnsNormally);
    });

    test('throws AssertionError when connected', () async {
      final fake = FakeBroadcastManager();
      await fake.connection().connect();
      expect(() => fake.assertDisconnected(), throwsA(isA<AssertionError>()));
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Assertion helpers — assertSubscribed
  // ---------------------------------------------------------------------------

  group('assertSubscribed', () {
    test('passes when channel is in subscribed list', () {
      final fake = FakeBroadcastManager();
      fake.connection().channel('orders');
      expect(() => fake.assertSubscribed('orders'), returnsNormally);
    });

    test('throws AssertionError when channel is not in subscribed list', () {
      final fake = FakeBroadcastManager();
      expect(
        () => fake.assertSubscribed('orders'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('passes for private- prefixed channel', () {
      final fake = FakeBroadcastManager();
      fake.connection().private('user.1');
      expect(() => fake.assertSubscribed('private-user.1'), returnsNormally);
    });

    test('passes for presence- prefixed channel', () {
      final fake = FakeBroadcastManager();
      fake.connection().join('room.1');
      expect(() => fake.assertSubscribed('presence-room.1'), returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Assertion helpers — assertNotSubscribed
  // ---------------------------------------------------------------------------

  group('assertNotSubscribed', () {
    test('passes when channel is not in subscribed list', () {
      final fake = FakeBroadcastManager();
      expect(() => fake.assertNotSubscribed('orders'), returnsNormally);
    });

    test('throws AssertionError when channel IS in subscribed list', () {
      final fake = FakeBroadcastManager();
      fake.connection().channel('orders');
      expect(
        () => fake.assertNotSubscribed('orders'),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Interceptor tracking
  // ---------------------------------------------------------------------------

  group('interceptor tracking', () {
    test('addInterceptor records the interceptor', () {
      final fake = FakeBroadcastManager();
      final interceptor = _TestInterceptor();
      fake.connection().addInterceptor(interceptor);
      expect(fake.driver.addedInterceptors, contains(interceptor));
    });

    test('assertInterceptorAdded passes after adding interceptor', () {
      final fake = FakeBroadcastManager();
      fake.connection().addInterceptor(_TestInterceptor());
      expect(() => fake.assertInterceptorAdded(), returnsNormally);
    });

    test('assertInterceptorAdded throws when no interceptors added', () {
      final fake = FakeBroadcastManager();
      expect(
        () => fake.assertInterceptorAdded(),
        throwsA(isA<AssertionError>()),
      );
    });

    test('multiple interceptors can be added', () {
      final fake = FakeBroadcastManager();
      fake.connection().addInterceptor(_TestInterceptor());
      fake.connection().addInterceptor(_TestInterceptor());
      expect(fake.driver.addedInterceptors, hasLength(2));
    });
  });

  // ---------------------------------------------------------------------------
  // 7. Recording — driver tracks subscriptions
  // ---------------------------------------------------------------------------

  group('recording', () {
    test('channel() records channel name', () {
      final fake = FakeBroadcastManager();
      fake.connection().channel('notifications');
      expect(fake.driver.subscribedChannels, contains('notifications'));
    });

    test('multiple channel() calls accumulate', () {
      final fake = FakeBroadcastManager();
      fake.connection().channel('orders');
      fake.connection().channel('notifications');
      expect(
        fake.driver.subscribedChannels,
        containsAll(['orders', 'notifications']),
      );
    });

    test('leave() removes only the matching channel', () {
      final fake = FakeBroadcastManager();
      fake.connection().channel('orders');
      fake.connection().channel('notifications');
      fake.connection().leave('orders');
      expect(fake.driver.subscribedChannels, isNot(contains('orders')));
      expect(fake.driver.subscribedChannels, contains('notifications'));
    });
  });

  // ---------------------------------------------------------------------------
  // 8. reset()
  // ---------------------------------------------------------------------------

  group('reset()', () {
    test('clears subscribed channels', () {
      final fake = FakeBroadcastManager();
      fake.connection().channel('orders');
      fake.reset();
      expect(fake.driver.subscribedChannels, isEmpty);
    });

    test('clears connected state', () async {
      final fake = FakeBroadcastManager();
      await fake.connection().connect();
      fake.reset();
      expect(fake.driver.isConnected, isFalse);
    });

    test('clears added interceptors', () {
      final fake = FakeBroadcastManager();
      fake.connection().addInterceptor(_TestInterceptor());
      fake.reset();
      expect(fake.driver.addedInterceptors, isEmpty);
    });

    test('after reset assertNothingSubscribed passes', () {
      final fake = FakeBroadcastManager();
      fake.connection().channel('orders');
      fake.reset();
      expect(() => fake.assertNotSubscribed('orders'), returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  // 9. Facade integration — Echo.fake()
  // ---------------------------------------------------------------------------

  group('Echo.fake()', () {
    test('returns a FakeBroadcastManager instance', () {
      final fake = Echo.fake();
      expect(fake, isA<FakeBroadcastManager>());
    });

    test('Echo.channel() routes through the fake', () {
      final fake = Echo.fake();
      Config.set('broadcasting.default', 'null');

      Echo.channel('orders');

      expect(fake.driver.subscribedChannels, contains('orders'));
    });

    test('Echo.private() routes through the fake', () {
      final fake = Echo.fake();
      Config.set('broadcasting.default', 'null');

      Echo.private('user.1');

      fake.assertSubscribed('private-user.1');
    });

    test('Echo.join() routes through the fake', () {
      final fake = Echo.fake();
      Config.set('broadcasting.default', 'null');

      Echo.join('room.1');

      fake.assertSubscribed('presence-room.1');
    });

    test('Echo.connect() routes through the fake', () async {
      final fake = Echo.fake();
      Config.set('broadcasting.default', 'null');

      await Echo.connect();

      fake.assertConnected();
    });

    test('Echo.disconnect() routes through the fake', () async {
      final fake = Echo.fake();
      Config.set('broadcasting.default', 'null');

      await Echo.connect();
      await Echo.disconnect();

      fake.assertDisconnected();
    });
  });

  // ---------------------------------------------------------------------------
  // 10. Echo.unfake()
  // ---------------------------------------------------------------------------

  group('Echo.unfake()', () {
    test('can be called without throwing', () {
      Echo.fake();
      expect(() => Echo.unfake(), returnsNormally);
    });

    test('can be called when not faked without throwing', () {
      expect(() => Echo.unfake(), returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  // 11. Presence channel
  // ---------------------------------------------------------------------------

  group('presence channel', () {
    test('join() returns an object with empty members list', () {
      final fake = FakeBroadcastManager();
      final presence = fake.connection().join('room.1');
      expect(presence.members, isEmpty);
    });

    test('join() onJoin stream is empty', () {
      final fake = FakeBroadcastManager();
      final presence = fake.connection().join('room.1');
      expect(presence.onJoin, isA<Stream>());
    });

    test('join() onLeave stream is empty', () {
      final fake = FakeBroadcastManager();
      final presence = fake.connection().join('room.1');
      expect(presence.onLeave, isA<Stream>());
    });
  });
}
