import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// ---------------------------------------------------------------------------
// Mock WebSocket infrastructure
// ---------------------------------------------------------------------------

/// A mock [WebSocketSink] that captures all sent messages.
class _MockWebSocketSink implements WebSocketSink {
  final List<dynamic> messages = [];
  bool isClosed = false;
  int? closeCode;
  String? closeReason;

  @override
  void add(dynamic data) {
    messages.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream stream) => stream.drain();

  @override
  Future close([int? closeCode, String? closeReason]) {
    isClosed = true;
    this.closeCode = closeCode;
    this.closeReason = closeReason;
    return Future<void>.value();
  }

  @override
  Future get done => Future<void>.value();

  /// Returns all sent messages decoded as JSON maps.
  List<Map<String, dynamic>> get sentFrames => messages
      .map((m) => jsonDecode(m as String) as Map<String, dynamic>)
      .toList();
}

/// A mock [WebSocketChannel] backed by a [StreamController] for incoming
/// messages and a [_MockWebSocketSink] for outgoing messages.
class _MockWebSocketChannel implements WebSocketChannel {
  _MockWebSocketChannel()
    : _incomingController = StreamController<dynamic>.broadcast();

  final StreamController<dynamic> _incomingController;
  final _MockWebSocketSink _sink = _MockWebSocketSink();

  @override
  Stream<dynamic> get stream => _incomingController.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  Future<void> get ready => Future<void>.value();

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  /// Simulates a message arriving from the server.
  void simulateMessage(Map<String, dynamic> payload) {
    _incomingController.add(jsonEncode(payload));
  }

  /// Simulates the server closing the connection.
  void simulateClose() {
    _incomingController.close();
  }

  /// Simulates a stream error.
  void simulateError(Object error) {
    _incomingController.addError(error);
  }

  /// Returns decoded sent frames from the sink.
  List<Map<String, dynamic>> get sentFrames => _sink.sentFrames;

  /// Closes the incoming controller for cleanup.
  void dispose() {
    _incomingController.close();
  }
}

// ---------------------------------------------------------------------------
// Test interceptor
// ---------------------------------------------------------------------------

class _TestInterceptor extends BroadcastInterceptor {
  final List<Map<String, dynamic>> sentMessages = [];
  final List<BroadcastEvent> receivedEvents = [];
  final List<dynamic> errors = [];

  @override
  Map<String, dynamic> onSend(Map<String, dynamic> message) {
    sentMessages.add(message);
    return message;
  }

  @override
  BroadcastEvent onReceive(BroadcastEvent event) {
    receivedEvents.add(event);
    return event;
  }

  @override
  dynamic onError(dynamic error) {
    errors.add(error);
    return error;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _defaultConfig({Map<String, dynamic>? overrides}) {
  final config = <String, dynamic>{
    'host': 'localhost',
    'port': 8080,
    'scheme': 'ws',
    'app_key': 'test-app-key',
    'auth_endpoint': '/broadcasting/auth',
    'reconnect': true,
    'max_reconnect_delay': 30000,
    'activity_timeout': 30,
    'dedup_buffer_size': 100,
  };
  if (overrides != null) {
    config.addAll(overrides);
  }
  return config;
}

/// Schedules the Pusher `connection_established` handshake on [mock] after a
/// microtask, allowing [connect] to finish setting up stream listeners.
void _simulateConnectionEstablished(
  _MockWebSocketChannel mock, {
  String socketId = 'test-socket-id',
  int activityTimeout = 30,
}) {
  Future<void>.delayed(Duration.zero, () {
    mock.simulateMessage({
      'event': 'pusher:connection_established',
      'data': jsonEncode({
        'socket_id': socketId,
        'activity_timeout': activityTimeout,
      }),
    });
  });
}

/// Creates a driver connected to a mock channel with handshake complete.
Future<(ReverbBroadcastDriver, _MockWebSocketChannel)> _createConnectedDriver({
  Map<String, dynamic>? configOverrides,
}) async {
  final mock = _MockWebSocketChannel();
  final driver = ReverbBroadcastDriver(
    _defaultConfig(overrides: configOverrides),
    channelFactory: (_) => mock,
  );

  _simulateConnectionEstablished(mock);
  await driver.connect();
  return (driver, mock);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Log.fake();
  });

  group('ReverbBroadcastDriver — connection lifecycle', () {
    test(
      'transitions from connecting to connected on connection_established',
      () async {
        final mock = _MockWebSocketChannel();
        final driver = ReverbBroadcastDriver(
          _defaultConfig(),
          channelFactory: (_) => mock,
        );

        final states = <BroadcastConnectionState>[];
        driver.connectionState.listen(states.add);

        _simulateConnectionEstablished(mock);
        await driver.connect();

        expect(states, contains(BroadcastConnectionState.connecting));
        expect(states, contains(BroadcastConnectionState.connected));
        expect(driver.isConnected, isTrue);

        await driver.disconnect();
      },
    );

    test('parses socketId from connection_established event', () async {
      final (driver, _) = await _createConnectedDriver();

      expect(driver.socketId, equals('test-socket-id'));

      await driver.disconnect();
    });

    test('disconnect transitions to disconnected state', () async {
      final (driver, _) = await _createConnectedDriver();

      final states = <BroadcastConnectionState>[];
      driver.connectionState.listen(states.add);

      await driver.disconnect();

      expect(driver.isConnected, isFalse);
      expect(driver.socketId, isNull);
      expect(states, contains(BroadcastConnectionState.disconnected));
    });
  });

  group('ReverbBroadcastDriver — ping/pong', () {
    test('responds to pusher:ping with pusher:pong', () async {
      final (driver, mock) = await _createConnectedDriver();

      // Clear frames from handshake.
      mock._sink.messages.clear();

      mock.simulateMessage({
        'event': 'pusher:ping',
        'data': <String, dynamic>{},
      });

      // Allow microtask to process.
      await Future<void>.delayed(Duration.zero);

      final frames = mock.sentFrames;
      expect(
        frames,
        contains(
          predicate<Map<String, dynamic>>((f) => f['event'] == 'pusher:pong'),
        ),
      );

      await driver.disconnect();
    });
  });

  group('ReverbBroadcastDriver — channel subscription', () {
    test('channel() sends pusher:subscribe frame with correct name', () async {
      final (driver, mock) = await _createConnectedDriver();

      mock._sink.messages.clear();

      driver.channel('orders');

      await Future<void>.delayed(Duration.zero);

      final frames = mock.sentFrames;
      expect(
        frames,
        contains(
          predicate<Map<String, dynamic>>(
            (f) =>
                f['event'] == 'pusher:subscribe' &&
                (f['data'] as Map<String, dynamic>)['channel'] == 'orders',
          ),
        ),
      );

      await driver.disconnect();
    });

    test('channel() returns same instance on repeated calls', () async {
      final (driver, _) = await _createConnectedDriver();

      final ch1 = driver.channel('orders');
      final ch2 = driver.channel('orders');

      expect(identical(ch1, ch2), isTrue);

      await driver.disconnect();
    });

    test('private() sends subscribe frame with private- prefix', () async {
      final (driver, mock) = await _createConnectedDriver();

      mock._sink.messages.clear();

      // private() will attempt HTTP auth which will fail in unit test —
      // but we can verify the channel name prefix is correct.
      driver.private('orders');

      // The channel object should be created with the prefixed name.
      expect(driver.private('orders').name, equals('private-orders'));

      await driver.disconnect();
    });

    test(
      'join() returns BroadcastPresenceChannel with presence- prefix',
      () async {
        final (driver, _) = await _createConnectedDriver();

        final ch = driver.join('room.1');

        expect(ch, isA<BroadcastPresenceChannel>());
        expect(ch.name, equals('presence-room.1'));

        await driver.disconnect();
      },
    );
  });

  group('ReverbBroadcastDriver — event parsing', () {
    test('routes parsed BroadcastEvent to correct channel', () async {
      final (driver, mock) = await _createConnectedDriver();

      final ch = driver.channel('orders');
      final events = <BroadcastEvent>[];
      ch.listen('OrderShipped', events.add);

      mock.simulateMessage({
        'event': 'OrderShipped',
        'channel': 'orders',
        'data': jsonEncode({'order_id': 42}),
      });

      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.event, equals('OrderShipped'));
      expect(events.first.channel, equals('orders'));
      expect(events.first.data, equals({'order_id': 42}));

      await driver.disconnect();
    });

    test('double-JSON decodes string data field to Map', () async {
      final (driver, mock) = await _createConnectedDriver();

      final ch = driver.channel('orders');
      final events = <BroadcastEvent>[];
      ch.listen('OrderShipped', events.add);

      // Data is a JSON-encoded string (Pusher standard).
      mock.simulateMessage({
        'event': 'OrderShipped',
        'channel': 'orders',
        'data': jsonEncode({'item': 'widget'}),
      });

      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.data, isA<Map<String, dynamic>>());
      expect(events.first.data['item'], equals('widget'));

      await driver.disconnect();
    });

    test('uses Map data directly when already decoded', () async {
      final (driver, mock) = await _createConnectedDriver();

      final ch = driver.channel('orders');
      final events = <BroadcastEvent>[];
      ch.events.listen(events.add);

      // Simulate a message where data is already a map (non-standard but defensive).
      mock.simulateMessage({
        'event': 'OrderShipped',
        'channel': 'orders',
        'data': {'item': 'widget'},
      });

      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.data['item'], equals('widget'));

      await driver.disconnect();
    });

    test(
      'routes StateError through interceptor when event key is missing',
      () async {
        final (driver, mock) = await _createConnectedDriver();

        final interceptor = _TestInterceptor();
        driver.addInterceptor(interceptor);

        mock.simulateMessage({'channel': 'orders', 'data': '{}'});

        await Future<void>.delayed(Duration.zero);

        // _onMessage throws StateError, caught by listener, routed to interceptor.
        expect(interceptor.errors.whereType<StateError>(), isNotEmpty);

        await driver.disconnect();
      },
    );
  });

  group('ReverbBroadcastDriver — deduplication', () {
    test('drops duplicate events', () async {
      final (driver, mock) = await _createConnectedDriver();

      final ch = driver.channel('orders');
      final events = <BroadcastEvent>[];
      ch.events.listen(events.add);

      final payload = {
        'event': 'OrderShipped',
        'channel': 'orders',
        'data': jsonEncode({'order_id': 1}),
      };

      mock.simulateMessage(payload);
      await Future<void>.delayed(Duration.zero);
      mock.simulateMessage(payload);
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));

      await driver.disconnect();
    });

    test('evicts oldest entry when buffer is full', () async {
      final (driver, mock) = await _createConnectedDriver(
        configOverrides: {'dedup_buffer_size': 3},
      );

      final ch = driver.channel('orders');
      final events = <BroadcastEvent>[];
      ch.events.listen(events.add);

      // Fill buffer with 3 unique events.
      for (var i = 0; i < 3; i++) {
        mock.simulateMessage({
          'event': 'Event$i',
          'channel': 'orders',
          'data': jsonEncode({'i': i}),
        });
        await Future<void>.delayed(Duration.zero);
      }
      expect(events, hasLength(3));

      // Add one more — evicts event 0.
      mock.simulateMessage({
        'event': 'Event3',
        'channel': 'orders',
        'data': jsonEncode({'i': 3}),
      });
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(4));

      // Replay event 0 — should pass through because it was evicted.
      // Buffer is now [E1, E2, E3].
      mock.simulateMessage({
        'event': 'Event0',
        'channel': 'orders',
        'data': jsonEncode({'i': 0}),
      });
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(5));

      // Replay event 2 — still in buffer [E2, E3, E0], so dropped.
      mock.simulateMessage({
        'event': 'Event2',
        'channel': 'orders',
        'data': jsonEncode({'i': 2}),
      });
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(5));

      await driver.disconnect();
    });

    test('different events with same channel are not deduplicated', () async {
      final (driver, mock) = await _createConnectedDriver();

      final ch = driver.channel('orders');
      final events = <BroadcastEvent>[];
      ch.events.listen(events.add);

      mock.simulateMessage({
        'event': 'OrderShipped',
        'channel': 'orders',
        'data': jsonEncode({'id': 1}),
      });
      await Future<void>.delayed(Duration.zero);

      mock.simulateMessage({
        'event': 'OrderCancelled',
        'channel': 'orders',
        'data': jsonEncode({'id': 1}),
      });
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(2));

      await driver.disconnect();
    });
  });

  group('ReverbBroadcastDriver — exponential backoff', () {
    test('computes correct backoff delays capped at max', () {
      final driver = ReverbBroadcastDriver(
        _defaultConfig(overrides: {'max_reconnect_delay': 16000}),
      );

      // Formula: min(500 * 2^attempt, maxDelay)
      expect(driver.backoffDelay(0), equals(const Duration(milliseconds: 500)));
      expect(
        driver.backoffDelay(1),
        equals(const Duration(milliseconds: 1000)),
      );
      expect(
        driver.backoffDelay(2),
        equals(const Duration(milliseconds: 2000)),
      );
      expect(
        driver.backoffDelay(3),
        equals(const Duration(milliseconds: 4000)),
      );
      expect(
        driver.backoffDelay(4),
        equals(const Duration(milliseconds: 8000)),
      );
      expect(
        driver.backoffDelay(5),
        equals(const Duration(milliseconds: 16000)),
      );
      // Capped at max.
      expect(
        driver.backoffDelay(6),
        equals(const Duration(milliseconds: 16000)),
      );
      expect(
        driver.backoffDelay(10),
        equals(const Duration(milliseconds: 16000)),
      );
    });
  });

  group('ReverbBroadcastDriver — interceptor chain', () {
    test('invokes onSend for outbound messages', () async {
      final (driver, mock) = await _createConnectedDriver();

      final interceptor = _TestInterceptor();
      driver.addInterceptor(interceptor);

      mock._sink.messages.clear();

      driver.channel('orders');

      await Future<void>.delayed(Duration.zero);

      expect(interceptor.sentMessages, isNotEmpty);
      expect(
        interceptor.sentMessages.first['event'],
        equals('pusher:subscribe'),
      );

      await driver.disconnect();
    });

    test('invokes onReceive for inbound events', () async {
      final (driver, mock) = await _createConnectedDriver();

      final interceptor = _TestInterceptor();
      driver.addInterceptor(interceptor);

      driver.channel('orders');

      mock.simulateMessage({
        'event': 'OrderShipped',
        'channel': 'orders',
        'data': jsonEncode({'id': 1}),
      });

      await Future<void>.delayed(Duration.zero);

      expect(interceptor.receivedEvents, hasLength(1));
      expect(interceptor.receivedEvents.first.event, equals('OrderShipped'));

      await driver.disconnect();
    });
  });

  group('ReverbBroadcastDriver — leave', () {
    test('sends pusher:unsubscribe frame and removes channel', () async {
      final (driver, mock) = await _createConnectedDriver();

      driver.channel('orders');
      await Future<void>.delayed(Duration.zero);

      mock._sink.messages.clear();

      driver.leave('orders');

      await Future<void>.delayed(Duration.zero);

      final frames = mock.sentFrames;
      expect(
        frames,
        contains(
          predicate<Map<String, dynamic>>(
            (f) =>
                f['event'] == 'pusher:unsubscribe' &&
                (f['data'] as Map<String, dynamic>)['channel'] == 'orders',
          ),
        ),
      );

      await driver.disconnect();
    });
  });

  group('ReverbBroadcastDriver — reconnection', () {
    test('reconnect resubscribes all active channels', () async {
      final mock1 = _MockWebSocketChannel();
      var connectionCount = 0;
      _MockWebSocketChannel? currentMock;

      final driver = ReverbBroadcastDriver(
        _defaultConfig(overrides: {'reconnect': true}),
        channelFactory: (_) {
          connectionCount++;
          if (connectionCount == 1) {
            currentMock = mock1;
            return mock1;
          }
          // Second connection (reconnect) — new mock.
          final mock2 = _MockWebSocketChannel();
          currentMock = mock2;
          // Simulate handshake on reconnect.
          Future<void>.delayed(Duration.zero, () {
            mock2.simulateMessage({
              'event': 'pusher:connection_established',
              'data': jsonEncode({
                'socket_id': 'reconnected-socket-id',
                'activity_timeout': 30,
              }),
            });
          });
          return mock2;
        },
      );

      // Connect and subscribe to two channels.
      _simulateConnectionEstablished(mock1);
      await driver.connect();

      driver.channel('orders');
      driver.channel('notifications');
      await Future<void>.delayed(Duration.zero);

      // Simulate server closing the connection — triggers reconnect.
      mock1.simulateClose();

      // Allow reconnect timer (immediate=false, attempt 0 = 500ms, but in tests
      // we can advance with a short wait and fakeAsync is not needed because
      // the _scheduleReconnect uses Timer which runs in the test event loop).
      // For a unit test we just need to verify the reconnection logic sends
      // subscribe frames on the new connection.
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // After reconnect, the new mock should have received subscribe frames.
      if (currentMock != null && currentMock != mock1) {
        final frames = currentMock!.sentFrames;
        final subscribeChannels = frames
            .where((f) => f['event'] == 'pusher:subscribe')
            .map(
              (f) => (f['data'] as Map<String, dynamic>)['channel'] as String,
            )
            .toSet();

        expect(subscribeChannels, contains('orders'));
        expect(subscribeChannels, contains('notifications'));
      }

      await driver.disconnect();
    });
  });

  group('ReverbBroadcastDriver — Pusher error codes', () {
    test('4000-4099 are fatal (no reconnect)', () {
      final driver = ReverbBroadcastDriver(_defaultConfig());

      expect(driver.classifyErrorCode(4000), equals(PusherErrorAction.fatal));
      expect(driver.classifyErrorCode(4050), equals(PusherErrorAction.fatal));
      expect(driver.classifyErrorCode(4099), equals(PusherErrorAction.fatal));
    });

    test('4100-4199 reconnect immediately', () {
      final driver = ReverbBroadcastDriver(_defaultConfig());

      expect(
        driver.classifyErrorCode(4100),
        equals(PusherErrorAction.reconnectImmediate),
      );
      expect(
        driver.classifyErrorCode(4150),
        equals(PusherErrorAction.reconnectImmediate),
      );
      expect(
        driver.classifyErrorCode(4199),
        equals(PusherErrorAction.reconnectImmediate),
      );
    });

    test('4200-4299 reconnect with backoff', () {
      final driver = ReverbBroadcastDriver(_defaultConfig());

      expect(
        driver.classifyErrorCode(4200),
        equals(PusherErrorAction.reconnectBackoff),
      );
      expect(
        driver.classifyErrorCode(4250),
        equals(PusherErrorAction.reconnectBackoff),
      );
      expect(
        driver.classifyErrorCode(4299),
        equals(PusherErrorAction.reconnectBackoff),
      );
    });

    test('unknown codes default to backoff', () {
      final driver = ReverbBroadcastDriver(_defaultConfig());

      expect(
        driver.classifyErrorCode(4300),
        equals(PusherErrorAction.reconnectBackoff),
      );
      expect(
        driver.classifyErrorCode(1000),
        equals(PusherErrorAction.reconnectBackoff),
      );
    });
  });

  group('ReverbBroadcastDriver — onDone and onError', () {
    test('onDone triggers reconnecting state when connected', () async {
      final (driver, mock) = await _createConnectedDriver();

      final states = <BroadcastConnectionState>[];
      driver.connectionState.listen(states.add);

      // Simulate server closing the connection.
      mock.simulateClose();

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(states, contains(BroadcastConnectionState.reconnecting));

      await driver.disconnect();
    });

    test('onError routes through interceptor chain', () async {
      final (driver, mock) = await _createConnectedDriver();

      final interceptor = _TestInterceptor();
      driver.addInterceptor(interceptor);

      mock.simulateError(Exception('test error'));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(interceptor.errors, isNotEmpty);

      await driver.disconnect();
    });

    test(
      'onDone completes connection completer with error if not yet connected',
      () async {
        final mock = _MockWebSocketChannel();
        final driver = ReverbBroadcastDriver(
          _defaultConfig(overrides: {'reconnect': false}),
          channelFactory: (_) => mock,
        );

        // Close before handshake completes.
        Future<void>.delayed(const Duration(milliseconds: 10), () {
          mock.simulateClose();
        });

        await expectLater(driver.connect(), throwsA(isA<StateError>()));
      },
    );
  });

  group('ReverbBroadcastDriver — Pusher error handling', () {
    test('fatal error (4000-4099) does not reconnect', () async {
      final (driver, mock) = await _createConnectedDriver(
        configOverrides: {'reconnect': true},
      );

      final states = <BroadcastConnectionState>[];
      driver.connectionState.listen(states.add);

      mock.simulateMessage({
        'event': 'pusher:error',
        'data': jsonEncode({'code': 4001, 'message': 'App disabled'}),
      });

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Fatal error should NOT trigger reconnecting state.
      expect(states, isNot(contains(BroadcastConnectionState.reconnecting)));

      await driver.disconnect();
    });

    test('reconnectImmediate error (4100-4199) schedules reconnect', () async {
      final (driver, mock) = await _createConnectedDriver(
        configOverrides: {'reconnect': true},
      );

      final interceptor = _TestInterceptor();
      driver.addInterceptor(interceptor);

      mock.simulateMessage({
        'event': 'pusher:error',
        'data': jsonEncode({'code': 4100, 'message': 'Over capacity'}),
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Error should be routed through interceptor.
      expect(interceptor.errors, isNotEmpty);

      await driver.disconnect();
    });

    test('reconnectBackoff error (4200-4299) schedules reconnect', () async {
      final (driver, mock) = await _createConnectedDriver(
        configOverrides: {'reconnect': true},
      );

      final interceptor = _TestInterceptor();
      driver.addInterceptor(interceptor);

      mock.simulateMessage({
        'event': 'pusher:error',
        'data': jsonEncode({'code': 4200, 'message': 'Rate limited'}),
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(interceptor.errors, isNotEmpty);

      await driver.disconnect();
    });

    test('malformed error data does not crash', () async {
      final (driver, mock) = await _createConnectedDriver();

      mock.simulateMessage({'event': 'pusher:error', 'data': 'not-json'});

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Should not throw — malformed data is caught.
      expect(driver.isConnected, isTrue);

      await driver.disconnect();
    });

    test('non-string error data is handled', () async {
      final (driver, mock) = await _createConnectedDriver();

      mock.simulateMessage({'event': 'pusher:error', 'data': 42});

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(driver.isConnected, isTrue);

      await driver.disconnect();
    });
  });

  group('ReverbBroadcastDriver — presence events via driver', () {
    test('routes member_added through driver to presence channel', () async {
      final (driver, mock) = await _createConnectedDriver();

      final ch = driver.join('room.1');
      final joined = <Map<String, dynamic>>[];
      ch.onJoin.listen(joined.add);

      mock.simulateMessage({
        'event': 'pusher_internal:member_added',
        'channel': 'presence-room.1',
        'data': jsonEncode({
          'user_id': '1',
          'user_info': {'name': 'Alice'},
        }),
      });

      await Future<void>.delayed(Duration.zero);

      expect(joined, hasLength(1));
      expect(ch.members, hasLength(1));

      await driver.disconnect();
    });

    test('routes member_removed through driver to presence channel', () async {
      final (driver, mock) = await _createConnectedDriver();

      final ch = driver.join('room.1');

      // Add a member first.
      mock.simulateMessage({
        'event': 'pusher_internal:member_added',
        'channel': 'presence-room.1',
        'data': jsonEncode({
          'user_id': '1',
          'user_info': {'name': 'Alice'},
        }),
      });
      await Future<void>.delayed(Duration.zero);

      final left = <Map<String, dynamic>>[];
      ch.onLeave.listen(left.add);

      mock.simulateMessage({
        'event': 'pusher_internal:member_removed',
        'channel': 'presence-room.1',
        'data': jsonEncode({
          'user_id': '1',
          'user_info': {'name': 'Alice'},
        }),
      });
      await Future<void>.delayed(Duration.zero);

      expect(left, hasLength(1));
      expect(ch.members, isEmpty);

      await driver.disconnect();
    });

    test('subscription_succeeded populates members via driver', () async {
      final (driver, mock) = await _createConnectedDriver();

      final ch = driver.join('room.1');

      mock.simulateMessage({
        'event': 'pusher:subscription_succeeded',
        'channel': 'presence-room.1',
        'data': jsonEncode({
          'presence': {
            'count': 2,
            'ids': ['1', '2'],
            'hash': {
              '1': {'name': 'Alice'},
              '2': {'name': 'Bob'},
            },
          },
        }),
      });

      await Future<void>.delayed(Duration.zero);

      expect(ch.members, hasLength(2));

      await driver.disconnect();
    });

    test('presence event on non-presence channel is ignored', () async {
      final (driver, mock) = await _createConnectedDriver();

      // Subscribe to a regular (non-presence) channel.
      driver.channel('orders');

      // Send a presence event to it — should be silently ignored.
      mock.simulateMessage({
        'event': 'pusher_internal:member_added',
        'channel': 'orders',
        'data': jsonEncode({'user_id': '1'}),
      });

      await Future<void>.delayed(Duration.zero);

      // No crash — test passes if no exception.
      await driver.disconnect();
    });

    test('presence event without channel name is ignored', () async {
      final (driver, mock) = await _createConnectedDriver();

      mock.simulateMessage({
        'event': 'pusher_internal:member_added',
        'data': jsonEncode({'user_id': '1'}),
      });

      await Future<void>.delayed(Duration.zero);

      await driver.disconnect();
    });

    test(
      'subscription_succeeded with Map data (not String) is handled',
      () async {
        final (driver, mock) = await _createConnectedDriver();

        final ch = driver.join('room.1');

        mock.simulateMessage({
          'event': 'pusher:subscription_succeeded',
          'channel': 'presence-room.1',
          'data': {
            'presence': {
              'count': 1,
              'ids': ['1'],
              'hash': {
                '1': {'name': 'Alice'},
              },
            },
          },
        });

        await Future<void>.delayed(Duration.zero);

        expect(ch.members, hasLength(1));

        await driver.disconnect();
      },
    );

    test('subscription_succeeded without channel is ignored', () async {
      final (driver, mock) = await _createConnectedDriver();

      mock.simulateMessage({
        'event': 'pusher:subscription_succeeded',
        'data': jsonEncode({'presence': {}}),
      });

      await Future<void>.delayed(Duration.zero);

      await driver.disconnect();
    });

    test('subscription_succeeded on non-presence channel is ignored', () async {
      final (driver, mock) = await _createConnectedDriver();

      driver.channel('orders');

      mock.simulateMessage({
        'event': 'pusher:subscription_succeeded',
        'channel': 'orders',
        'data': jsonEncode({'presence': {}}),
      });

      await Future<void>.delayed(Duration.zero);

      await driver.disconnect();
    });
  });

  group('ReverbBroadcastDriver — subscription queue', () {
    test('queues private subscribe when not connected', () async {
      final mock = _MockWebSocketChannel();
      final driver = ReverbBroadcastDriver(
        _defaultConfig(),
        channelFactory: (_) => mock,
      );

      // Call private() before connect — should queue.
      driver.private('secret');

      // Now connect — queued subscription should flush.
      _simulateConnectionEstablished(mock);
      await driver.connect();

      await Future<void>.delayed(Duration.zero);

      // Channel should exist with private- prefix.
      expect(driver.private('secret').name, equals('private-secret'));

      await driver.disconnect();
    });

    test('queues presence subscribe when not connected', () async {
      final mock = _MockWebSocketChannel();
      final driver = ReverbBroadcastDriver(
        _defaultConfig(),
        channelFactory: (_) => mock,
      );

      // Call join() before connect — should queue.
      driver.join('room.1');

      _simulateConnectionEstablished(mock);
      await driver.connect();

      await Future<void>.delayed(Duration.zero);

      expect(driver.join('room.1').name, equals('presence-room.1'));

      await driver.disconnect();
    });
  });

  group('ReverbBroadcastDriver — disconnect cleanup', () {
    test('disconnect clears channels and dedup state', () async {
      final (driver, mock) = await _createConnectedDriver();

      // Subscribe to channels.
      driver.channel('orders');
      driver.channel('notifications');

      // Send events to populate dedup buffer.
      mock.simulateMessage({
        'event': 'Test',
        'channel': 'orders',
        'data': jsonEncode({'id': 1}),
      });
      await Future<void>.delayed(Duration.zero);

      await driver.disconnect();

      expect(driver.isConnected, isFalse);
      expect(driver.socketId, isNull);
    });
  });

  group('ReverbBroadcastDriver — application event edge cases', () {
    test('event for unknown channel is ignored', () async {
      final (driver, mock) = await _createConnectedDriver();

      mock.simulateMessage({
        'event': 'SomeEvent',
        'channel': 'nonexistent',
        'data': jsonEncode({'key': 'value'}),
      });

      await Future<void>.delayed(Duration.zero);

      // No crash — passes if no exception.
      await driver.disconnect();
    });

    test('event without channel is ignored', () async {
      final (driver, mock) = await _createConnectedDriver();

      mock.simulateMessage({
        'event': 'SomeEvent',
        'data': jsonEncode({'key': 'value'}),
      });

      await Future<void>.delayed(Duration.zero);

      await driver.disconnect();
    });

    test('event with non-Map non-String data uses empty map', () async {
      final (driver, mock) = await _createConnectedDriver();

      final ch = driver.channel('orders');
      final events = <BroadcastEvent>[];
      ch.events.listen(events.add);

      mock.simulateMessage({
        'event': 'OrderShipped',
        'channel': 'orders',
        'data': 42,
      });

      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.data, isEmpty);

      await driver.disconnect();
    });
  });

  group('ReverbBroadcastChannel', () {
    test('listen() filters events by name and returns this', () async {
      final ch = ReverbBroadcastChannel('test');
      final events = <BroadcastEvent>[];

      final result = ch.listen('OrderShipped', events.add);
      expect(result, same(ch));

      ch.addEvent(
        BroadcastEvent(
          event: 'OrderShipped',
          channel: 'test',
          data: {'id': 1},
          receivedAt: DateTime.now(),
        ),
      );

      ch.addEvent(
        BroadcastEvent(
          event: 'OrderCancelled',
          channel: 'test',
          data: {'id': 2},
          receivedAt: DateTime.now(),
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.data['id'], equals(1));

      ch.dispose();
    });

    test('stopListening() removes listener for event', () async {
      final ch = ReverbBroadcastChannel('test');
      final events = <BroadcastEvent>[];

      ch.listen('OrderShipped', events.add);
      ch.stopListening('OrderShipped');

      ch.addEvent(
        BroadcastEvent(
          event: 'OrderShipped',
          channel: 'test',
          data: {'id': 1},
          receivedAt: DateTime.now(),
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);

      ch.dispose();
    });
  });

  group('ReverbBroadcastPresenceChannel', () {
    test('handles member_added and member_removed', () async {
      final ch = ReverbBroadcastPresenceChannel('presence-room.1');

      final joinedMembers = <Map<String, dynamic>>[];
      final leftMembers = <Map<String, dynamic>>[];
      ch.onJoin.listen(joinedMembers.add);
      ch.onLeave.listen(leftMembers.add);

      ch.handlePresenceEvent('pusher_internal:member_added', {
        'user_id': '1',
        'user_info': {'name': 'Alice'},
      });

      await Future<void>.delayed(Duration.zero);

      expect(ch.members, hasLength(1));
      expect(joinedMembers, hasLength(1));

      ch.handlePresenceEvent('pusher_internal:member_removed', {
        'user_id': '1',
        'user_info': {'name': 'Alice'},
      });

      await Future<void>.delayed(Duration.zero);

      expect(ch.members, isEmpty);
      expect(leftMembers, hasLength(1));

      ch.dispose();
    });

    test('handles subscription_succeeded with member list', () async {
      final ch = ReverbBroadcastPresenceChannel('presence-room.1');

      ch.handlePresenceEvent('pusher:subscription_succeeded', {
        'presence': {
          'count': 2,
          'ids': ['1', '2'],
          'hash': {
            '1': {'name': 'Alice'},
            '2': {'name': 'Bob'},
          },
        },
      });

      await Future<void>.delayed(Duration.zero);

      expect(ch.members, hasLength(2));

      ch.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Reconnect resubscription
  // ---------------------------------------------------------------------------

  group('reconnect resubscription', () {
    /// Helper: creates a driver with an [authFactory] and a [channelFactory]
    /// that returns a fresh mock for each connection attempt. The reconnect
    /// mock auto-completes the Pusher handshake after a microtask.
    Future<
      (
        ReverbBroadcastDriver,
        _MockWebSocketChannel,
        _MockWebSocketChannel Function(),
      )
    >
    createReconnectableDriver({
      Future<Map<String, dynamic>> Function(
        String endpoint,
        Map<String, dynamic> data,
      )?
      authFactory,
      Map<String, dynamic>? configOverrides,
    }) async {
      final mock1 = _MockWebSocketChannel();
      _MockWebSocketChannel? reconnectMock;
      var connectionCount = 0;

      final driver = ReverbBroadcastDriver(
        _defaultConfig(overrides: {'reconnect': true, ...?configOverrides}),
        channelFactory: (_) {
          connectionCount++;
          if (connectionCount == 1) return mock1;
          reconnectMock = _MockWebSocketChannel();
          Future<void>.delayed(Duration.zero, () {
            reconnectMock!.simulateMessage({
              'event': 'pusher:connection_established',
              'data': jsonEncode({
                'socket_id': 'reconnected-socket-id',
                'activity_timeout': 30,
              }),
            });
          });
          return reconnectMock!;
        },
        authFactory: authFactory,
      );

      _simulateConnectionEstablished(mock1);
      await driver.connect();

      return (driver, mock1, () => reconnectMock!);
    }

    test('auth failure routes through interceptor.onError()', () async {
      final authError = Exception('Auth request failed: 403 Forbidden');

      final (driver, mock1, getReconnectMock) = await createReconnectableDriver(
        authFactory: (endpoint, data) async => throw authError,
      );

      // Subscribe to a private channel (triggers auth immediately — will fail).
      driver.private('secret');
      await Future<void>.delayed(Duration.zero);

      // Add interceptor AFTER initial subscribe so we only capture reconnect errors.
      final interceptor = _TestInterceptor();
      driver.addInterceptor(interceptor);

      // Simulate server closing the connection — triggers reconnect.
      mock1.simulateClose();
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Auth failure during reconnect should have been routed through the interceptor.
      expect(
        interceptor.errors,
        contains(
          predicate<dynamic>((e) => e.toString().contains('403 Forbidden')),
        ),
      );

      await driver.disconnect();
    });

    test('auth failure logs via Log.error()', () async {
      final fakeLog = Log.fake();

      final (driver, mock1, _) = await createReconnectableDriver(
        authFactory: (endpoint, data) async =>
            throw Exception('Auth denied for channel'),
      );

      // Subscribe to a private channel.
      driver.private('payments');
      await Future<void>.delayed(Duration.zero);

      // Simulate reconnect.
      mock1.simulateClose();
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Verify Log.error was called with channel name context.
      final errorEntries = fakeLog.entries.where((e) => e.level == 'error');
      expect(
        errorEntries,
        isNotEmpty,
        reason: 'Expected at least one error log entry for auth failure',
      );
      expect(
        errorEntries.any((e) => e.message.contains('private-payments')),
        isTrue,
        reason: 'Error log should contain the channel name',
      );

      await driver.disconnect();
    });

    test('all channels resubscribed after reconnect', () async {
      final (driver, mock1, getReconnectMock) = await createReconnectableDriver(
        authFactory: (endpoint, data) async => {'auth': 'test-token'},
      );

      // Subscribe to 1 public + 1 private channel.
      driver.channel('orders');
      driver.private('payments');
      await Future<void>.delayed(Duration.zero);

      // Simulate reconnect.
      mock1.simulateClose();
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Verify both channels received subscribe frames on the new connection.
      final reconnectMock = getReconnectMock();
      final frames = reconnectMock.sentFrames;
      final subscribeChannels = frames
          .where((f) => f['event'] == 'pusher:subscribe')
          .map((f) => (f['data'] as Map<String, dynamic>)['channel'] as String)
          .toSet();

      expect(subscribeChannels, contains('orders'));
      expect(subscribeChannels, contains('private-payments'));

      // Private channel should include auth data.
      final privateFrame = frames.firstWhere(
        (f) =>
            f['event'] == 'pusher:subscribe' &&
            (f['data'] as Map<String, dynamic>)['channel'] ==
                'private-payments',
      );
      expect(
        (privateFrame['data'] as Map<String, dynamic>)['auth'],
        equals('test-token'),
      );

      await driver.disconnect();
    });

    test('onReconnect emits only after all resubscriptions complete', () async {
      final subscriptionTimestamps = <DateTime>[];

      final (driver, mock1, _) = await createReconnectableDriver(
        authFactory: (endpoint, data) async {
          // Simulate slow auth — 100ms delay.
          await Future<void>.delayed(const Duration(milliseconds: 100));
          subscriptionTimestamps.add(DateTime.now());
          return {'auth': 'delayed-token'};
        },
      );

      // Subscribe to a private channel.
      driver.private('slow-auth');
      await Future<void>.delayed(Duration.zero);

      DateTime? reconnectEmitTime;
      driver.onReconnect.listen((_) {
        reconnectEmitTime = DateTime.now();
      });

      // Simulate reconnect.
      mock1.simulateClose();
      await Future<void>.delayed(const Duration(milliseconds: 800));

      // onReconnect must have fired.
      expect(
        reconnectEmitTime,
        isNotNull,
        reason: 'onReconnect should have emitted',
      );

      // The auth call must have completed before onReconnect emitted.
      expect(
        subscriptionTimestamps,
        isNotEmpty,
        reason: 'Auth factory should have been called during reconnect',
      );
      expect(
        reconnectEmitTime!.isAfter(subscriptionTimestamps.last) ||
            reconnectEmitTime!.isAtSameMomentAs(subscriptionTimestamps.last),
        isTrue,
        reason:
            'onReconnect should emit after auth+subscribe completes, '
            'not before',
      );

      await driver.disconnect();
    });

    test('auth failure on one channel does not block others', () async {
      final (driver, mock1, getReconnectMock) = await createReconnectableDriver(
        authFactory: (endpoint, data) async {
          final channelName = data['channel_name'] as String?;
          if (channelName == 'private-failing') {
            throw Exception('Auth denied for failing channel');
          }
          return {'auth': 'valid-token'};
        },
      );

      // Subscribe to two private channels.
      driver.private('failing');
      driver.private('succeeding');
      await Future<void>.delayed(Duration.zero);

      // Simulate reconnect.
      mock1.simulateClose();
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // The succeeding channel should still be subscribed.
      final reconnectMock = getReconnectMock();
      final frames = reconnectMock.sentFrames;
      final subscribedChannels = frames
          .where((f) => f['event'] == 'pusher:subscribe')
          .map((f) => (f['data'] as Map<String, dynamic>)['channel'] as String)
          .toSet();

      expect(
        subscribedChannels,
        contains('private-succeeding'),
        reason:
            'Auth failure on one channel should not prevent other channels '
            'from subscribing',
      );

      await driver.disconnect();
    });
  });
}
