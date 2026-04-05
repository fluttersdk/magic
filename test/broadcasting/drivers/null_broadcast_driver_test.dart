import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  group('NullBroadcastDriver', () {
    late NullBroadcastDriver driver;

    setUp(() {
      driver = NullBroadcastDriver();
    });

    test('connect() completes without error', () async {
      await expectLater(driver.connect(), completes);
    });

    test('disconnect() completes without error', () async {
      await expectLater(driver.disconnect(), completes);
    });

    test('isConnected is false', () {
      expect(driver.isConnected, isFalse);
    });

    test('socketId is null', () {
      expect(driver.socketId, isNull);
    });

    test('connectionState emits no events', () async {
      final events = await driver.connectionState.toList();
      expect(events, isEmpty);
    });

    test('onReconnect emits no events', () async {
      final events = await driver.onReconnect.toList();
      expect(events, isEmpty);
    });

    test('channel() returns a BroadcastChannel with correct name', () {
      final ch = driver.channel('orders');
      expect(ch, isA<BroadcastChannel>());
      expect(ch.name, equals('orders'));
    });

    test('private() returns a BroadcastChannel with correct name', () {
      final ch = driver.private('inbox');
      expect(ch, isA<BroadcastChannel>());
      expect(ch.name, equals('inbox'));
    });

    test(
      'join() returns a BroadcastPresenceChannel with correct name and empty members',
      () {
        final ch = driver.join('room.1');
        expect(ch, isA<BroadcastPresenceChannel>());
        expect(ch.name, equals('room.1'));
        expect(ch.members, isEmpty);
      },
    );

    test('leave() does not throw', () {
      expect(() => driver.leave('orders'), returnsNormally);
    });

    test('addInterceptor() does not throw', () {
      final interceptor = _NoOpInterceptor();
      expect(() => driver.addInterceptor(interceptor), returnsNormally);
    });
  });

  group('_NullBroadcastChannel (via channel())', () {
    late NullBroadcastDriver driver;

    setUp(() {
      driver = NullBroadcastDriver();
    });

    test('events stream emits no events', () async {
      final ch = driver.channel('test');
      final events = await ch.events.toList();
      expect(events, isEmpty);
    });

    test('listen() returns this for fluent chaining', () {
      final ch = driver.channel('test');
      final result = ch.listen('SomeEvent', (_) {});
      expect(result, same(ch));
    });

    test('stopListening() does not throw', () {
      final ch = driver.channel('test');
      expect(() => ch.stopListening('SomeEvent'), returnsNormally);
    });
  });

  group('_NullBroadcastPresenceChannel (via join())', () {
    late NullBroadcastDriver driver;

    setUp(() {
      driver = NullBroadcastDriver();
    });

    test('onJoin emits no events', () async {
      final ch = driver.join('room.1');
      final events = await ch.onJoin.toList();
      expect(events, isEmpty);
    });

    test('onLeave emits no events', () async {
      final ch = driver.join('room.1');
      final events = await ch.onLeave.toList();
      expect(events, isEmpty);
    });
  });
}

class _NoOpInterceptor extends BroadcastInterceptor {}
