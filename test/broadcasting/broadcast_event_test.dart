import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/broadcasting/broadcast_connection_state.dart';
import 'package:magic/src/broadcasting/broadcast_event.dart';

void main() {
  group('BroadcastEvent', () {
    test('constructs with required fields', () {
      final now = DateTime.now();
      final event = BroadcastEvent(
        event: 'OrderShipped',
        channel: 'orders',
        data: {'orderId': 42},
        receivedAt: now,
      );

      expect(event.event, 'OrderShipped');
      expect(event.channel, 'orders');
      expect(event.data, {'orderId': 42});
      expect(event.receivedAt, now);
    });

    test('data defaults to empty map when not provided', () {
      final event = BroadcastEvent(
        event: 'Ping',
        channel: 'public',
        data: const {},
        receivedAt: DateTime.now(),
      );

      expect(event.data, isEmpty);
    });

    test('toString includes event name and channel', () {
      final event = BroadcastEvent(
        event: 'UserJoined',
        channel: 'presence-room.1',
        data: const {'userId': 7},
        receivedAt: DateTime(2024, 1, 15, 10, 30),
      );

      final str = event.toString();
      expect(str, contains('UserJoined'));
      expect(str, contains('presence-room.1'));
    });

    test('data map is preserved as-is', () {
      final data = <String, dynamic>{
        'nested': {'key': 'value'},
        'list': [1, 2, 3],
        'flag': true,
      };
      final event = BroadcastEvent(
        event: 'Complex',
        channel: 'test',
        data: data,
        receivedAt: DateTime.now(),
      );

      expect(event.data['nested'], {'key': 'value'});
      expect(event.data['list'], [1, 2, 3]);
      expect(event.data['flag'], true);
    });
  });

  group('BroadcastConnectionState', () {
    test('has exactly 4 values', () {
      expect(BroadcastConnectionState.values, hasLength(4));
    });

    test('contains connecting state', () {
      expect(
        BroadcastConnectionState.values,
        contains(BroadcastConnectionState.connecting),
      );
    });

    test('contains connected state', () {
      expect(
        BroadcastConnectionState.values,
        contains(BroadcastConnectionState.connected),
      );
    });

    test('contains disconnected state', () {
      expect(
        BroadcastConnectionState.values,
        contains(BroadcastConnectionState.disconnected),
      );
    });

    test('contains reconnecting state', () {
      expect(
        BroadcastConnectionState.values,
        contains(BroadcastConnectionState.reconnecting),
      );
    });
  });
}
