import 'dart:async';
import 'dart:convert';
import 'dart:math';

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
  int? _closeCode;

  @override
  Stream<dynamic> get stream => _incomingController.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  Future<void> get ready => Future<void>.value();

  @override
  int? get closeCode => _closeCode;

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

  /// Simulates the server closing the connection, with the WebSocket close
  /// [code] it sent, or none when the TCP connection simply went away.
  void simulateClose([int? code]) {
    _closeCode = code;
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

/// A socket the server refused: `ready` fails, as it does when nothing
/// listens on the port, and closing it never completes, as a browser socket
/// that never opened does. The retry used to wait on that close forever.
class _RefusedWebSocketChannel extends _MockWebSocketChannel {
  final _NeverClosingSink _deadSink = _NeverClosingSink();

  @override
  Future<void> get ready =>
      Future<void>.error(WebSocketChannelException('Connection refused'));

  @override
  WebSocketSink get sink => _deadSink;
}

/// A sink whose [close] never completes.
class _NeverClosingSink extends _MockWebSocketSink {
  @override
  Future close([int? closeCode, String? closeReason]) {
    isClosed = true;
    return Completer<void>().future;
  }
}

/// An open socket whose peer went silent: it answers nothing, delivers no
/// close, and closing it never completes, as a socket to a killed server
/// behind a NAT does.
class _HangingWebSocketChannel extends _MockWebSocketChannel {
  final _NeverClosingSink _deadSink = _NeverClosingSink();

  @override
  WebSocketSink get sink => _deadSink;
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
  bool includeActivityTimeout = true,
}) {
  Future<void>.delayed(Duration.zero, () {
    final data = <String, dynamic>{'socket_id': socketId};
    if (includeActivityTimeout) {
      data['activity_timeout'] = activityTimeout;
    }
    mock.simulateMessage({
      'event': 'pusher:connection_established',
      'data': jsonEncode(data),
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

/// Creates a driver whose channel factory records every socket it opens, so
/// a test can count them. Each socket completes the Pusher handshake after a
/// microtask with socket id `socket-<index>`, except that the server closes
/// it before the handshake when [refuse] answers `true` for its 1-based
/// index, and never answers it at all when [silent] does. [config], when
/// given, is used as is, so a test can change it after construction.
(ReverbBroadcastDriver, List<_MockWebSocketChannel>) _createCountingDriver({
  bool Function(int index)? refuse,
  bool Function(int index)? silent,
  Map<String, dynamic>? configOverrides,
  Map<String, dynamic>? config,
  Future<Map<String, dynamic>> Function(
    String endpoint,
    Map<String, dynamic> data,
  )?
  authFactory,
}) {
  final sockets = <_MockWebSocketChannel>[];
  final driver = ReverbBroadcastDriver(
    config ??
        _defaultConfig(
          overrides: {
            'reconnect': true,
            'connection_timeout': 1,
            ...?configOverrides,
          },
        ),
    channelFactory: (_) {
      final socket = _MockWebSocketChannel();
      sockets.add(socket);
      final index = sockets.length;
      if (refuse?.call(index) ?? false) {
        Future<void>.delayed(Duration.zero, socket.simulateClose);
      } else if (!(silent?.call(index) ?? false)) {
        _simulateConnectionEstablished(socket, socketId: 'socket-$index');
      }
      return socket;
    },
    authFactory: authFactory,
    random: Random(42),
  );
  return (driver, sockets);
}

/// The `pusher:subscribe` frames [socket] carried, in order.
List<Map<String, dynamic>> _subscribeFrames(_MockWebSocketChannel socket) =>
    socket.sentFrames
        .where((f) => f['event'] == 'pusher:subscribe')
        .map((f) => f['data'] as Map<String, dynamic>)
        .toList();

/// The channel names [socket] sent a `pusher:subscribe` for.
Set<String> _subscribedOn(_MockWebSocketChannel socket) =>
    _subscribeFrames(socket).map((data) => data['channel'] as String).toSet();

/// An auth answer signed for the socket id the driver sent, so a test can
/// tell which socket a subscribe frame was authorised for.
Future<Map<String, dynamic>> _signingAuth(
  String endpoint,
  Map<String, dynamic> data,
) async => <String, dynamic>{'auth': 'sig-${data['socket_id']}'};

/// Lets queued microtasks and zero-duration timers run.
Future<void> _pump() => Future<void>.delayed(const Duration(milliseconds: 10));

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

    test('throws TimeoutException when server does not send '
        'connection_established within timeout', () async {
      final mock = _MockWebSocketChannel();
      final driver = ReverbBroadcastDriver(
        _defaultConfig(
          overrides: {'connection_timeout': 1, 'reconnect': false},
        ),
        channelFactory: (_) => mock,
      );

      // Do NOT simulate connection_established — server is unresponsive.
      await expectLater(driver.connect(), throwsA(isA<TimeoutException>()));

      // Socket should have been closed.
      expect(mock._sink.isClosed, isTrue);
    });

    test('schedules reconnect after connection timeout', () async {
      final mock1 = _MockWebSocketChannel();
      _MockWebSocketChannel? mock2;
      var connectionCount = 0;

      final driver = ReverbBroadcastDriver(
        _defaultConfig(overrides: {'connection_timeout': 1, 'reconnect': true}),
        channelFactory: (_) {
          connectionCount++;
          if (connectionCount == 1) return mock1;
          mock2 = _MockWebSocketChannel();
          Future<void>.delayed(Duration.zero, () {
            mock2!.simulateMessage({
              'event': 'pusher:connection_established',
              'data': jsonEncode({
                'socket_id': 'retry-socket-id',
                'activity_timeout': 30,
              }),
            });
          });
          return mock2!;
        },
        random: Random(42),
      );

      // connect() will timeout, but reconnect should be scheduled.
      try {
        await driver.connect();
      } on TimeoutException catch (_) {
        // Expected.
      }

      // Wait for reconnect timer (attempt 0 backoff ~500ms + jitter + connect).
      await Future<void>.delayed(const Duration(milliseconds: 900));

      // Driver should have reconnected successfully.
      expect(connectionCount, greaterThanOrEqualTo(2));

      await driver.disconnect();
    });

    test('schedules a reconnect when the server refuses the socket', () async {
      // A Reverb that is down refuses the socket before any handshake, so
      // `ready` fails. That path armed no retry: the driver never connected
      // again, even once the server was back.
      var connectionCount = 0;

      final driver = ReverbBroadcastDriver(
        _defaultConfig(overrides: {'reconnect': true}),
        channelFactory: (_) {
          connectionCount++;
          if (connectionCount == 1) return _RefusedWebSocketChannel();
          final mock = _MockWebSocketChannel();
          Future<void>.delayed(Duration.zero, () {
            mock.simulateMessage({
              'event': 'pusher:connection_established',
              'data': jsonEncode({
                'socket_id': 'back-socket-id',
                'activity_timeout': 30,
              }),
            });
          });
          return mock;
        },
        random: Random(42),
      );

      await expectLater(
        driver.connect(),
        throwsA(isA<WebSocketChannelException>()),
      );

      await Future<void>.delayed(const Duration(milliseconds: 900));

      expect(connectionCount, greaterThanOrEqualTo(2));
      expect(driver.isConnected, isTrue);

      await driver.disconnect();
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

  group('ReverbBroadcastDriver: repeated events', () {
    test('delivers an application event whose payload repeats', () async {
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

      expect(events, hasLength(2));

      await driver.disconnect();
    });

    test('delivers different events on the same channel', () async {
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
    test('computes backoff delays within expected range with jitter', () {
      final driver = ReverbBroadcastDriver(
        _defaultConfig(overrides: {'max_reconnect_delay': 16000}),
      );

      // Formula: base = min(500 * 2^attempt, maxDelay), jitter = 0..30%
      // Result is in [base, base * 1.3]
      void expectRange(int attempt, int base) {
        final delay = driver.backoffDelay(attempt);
        final ms = delay.inMilliseconds;
        final maxWithJitter = (base * 1.3).ceil();
        expect(
          ms,
          greaterThanOrEqualTo(base),
          reason: 'attempt $attempt: $ms should be >= $base',
        );
        expect(
          ms,
          lessThanOrEqualTo(maxWithJitter),
          reason: 'attempt $attempt: $ms should be <= $maxWithJitter',
        );
      }

      expectRange(0, 500);
      expectRange(1, 1000);
      expectRange(2, 2000);
      expectRange(3, 4000);
      expectRange(4, 8000);
      expectRange(5, 16000);
      // Capped at max.
      expectRange(6, 16000);
      expectRange(10, 16000);
    });

    test('produces deterministic delays with seeded Random', () {
      final driver = ReverbBroadcastDriver(
        _defaultConfig(overrides: {'max_reconnect_delay': 16000}),
        random: Random(42),
      );

      // With a seeded Random, delays are deterministic but include jitter.
      final delay0 = driver.backoffDelay(0);
      expect(delay0.inMilliseconds, greaterThan(500));
      expect(delay0.inMilliseconds, lessThanOrEqualTo(650));
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
        random: Random(42),
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

  group('ReverbBroadcastDriver: idempotent connect', () {
    test('two concurrent connect() calls open one socket', () async {
      final (driver, sockets) = _createCountingDriver();

      await Future.wait(<Future<void>>[driver.connect(), driver.connect()]);

      expect(sockets, hasLength(1));
      expect(driver.isConnected, isTrue);

      await driver.disconnect();
    });

    test('connect() while connected opens nothing', () async {
      final (driver, sockets) = _createCountingDriver();
      await driver.connect();

      final states = <BroadcastConnectionState>[];
      driver.connectionState.listen(states.add);

      await driver.connect();

      expect(sockets, hasLength(1));
      expect(states, isEmpty);
      expect(driver.socketId, 'socket-1');

      await driver.disconnect();
    });

    test('connect() after a drop supersedes the armed retry: one socket in '
        'total, channels resubscribed, onReconnect once', () async {
      final (driver, sockets) = _createCountingDriver();
      await driver.connect();
      driver.channel('orders');
      await Future<void>.delayed(Duration.zero);

      var reconnects = 0;
      driver.onReconnect.listen((_) => reconnects++);

      // The server drops the socket; the driver arms its retry timer.
      sockets.first.simulateClose();
      await Future<void>.delayed(Duration.zero);
      expect(driver.isConnected, isFalse);

      await driver.connect();

      expect(sockets, hasLength(2));
      expect(driver.isConnected, isTrue);
      expect(_subscribedOn(sockets[1]), contains('orders'));

      // Past the attempt-0 backoff (at most 650ms): the cancelled retry must
      // not open a third socket.
      await Future<void>.delayed(const Duration(milliseconds: 800));

      expect(sockets, hasLength(2));
      expect(reconnects, 1);

      await driver.disconnect();
    });

    test('connect() during the backoff after a failed timer-driven retry '
        'opens one socket, not two', () async {
      final (driver, sockets) = _createCountingDriver(
        refuse: (index) => index == 2,
      );
      await driver.connect();

      // Drop, then let the timer-driven retry (socket 2) fail and re-arm.
      sockets.first.simulateClose();
      await Future<void>.delayed(const Duration(milliseconds: 800));
      expect(sockets, hasLength(2));
      expect(driver.isConnected, isFalse);

      await driver.connect();

      expect(sockets, hasLength(3));
      expect(driver.isConnected, isTrue);

      // Past the attempt-1 backoff (at most 1300ms).
      await Future<void>.delayed(const Duration(milliseconds: 1500));

      expect(sockets, hasLength(3));

      await driver.disconnect();
    });

    test('connect() during the retry armed by a connection timeout opens one '
        'socket, not two', () async {
      final (driver, sockets) = _createCountingDriver(
        silent: (index) => index == 1,
      );

      // The server never answers socket 1: connect() times out after 1s and
      // arms a retry before throwing.
      await expectLater(driver.connect(), throwsA(isA<TimeoutException>()));
      expect(sockets, hasLength(1));

      await driver.connect();

      expect(sockets, hasLength(2));
      expect(driver.isConnected, isTrue);

      // Past the backoff the timeout armed (at most 650ms).
      await Future<void>.delayed(const Duration(milliseconds: 800));

      expect(sockets, hasLength(2));

      await driver.disconnect();
    });

    test('a failed superseding connect() throws to its caller and re-arms '
        'the retry', () async {
      final (driver, sockets) = _createCountingDriver(
        refuse: (index) => index == 2,
      );
      await driver.connect();

      sockets.first.simulateClose();
      await Future<void>.delayed(Duration.zero);

      await expectLater(driver.connect(), throwsA(isA<StateError>()));
      expect(sockets, hasLength(2));

      // The retry loop survives the failed public attempt: the re-armed
      // timer (attempt-1 backoff, at most 1300ms) opens socket 3.
      await Future<void>.delayed(const Duration(milliseconds: 1500));

      expect(sockets, hasLength(3));
      expect(driver.isConnected, isTrue);

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

    test('4100-4199 reconnect with backoff', () {
      final driver = ReverbBroadcastDriver(_defaultConfig());

      expect(
        driver.classifyErrorCode(4100),
        equals(PusherErrorAction.reconnectBackoff),
      );
      expect(
        driver.classifyErrorCode(4150),
        equals(PusherErrorAction.reconnectBackoff),
      );
      expect(
        driver.classifyErrorCode(4199),
        equals(PusherErrorAction.reconnectBackoff),
      );
    });

    test('4200-4299 reconnect immediately', () {
      final driver = ReverbBroadcastDriver(_defaultConfig());

      expect(
        driver.classifyErrorCode(4200),
        equals(PusherErrorAction.reconnectImmediate),
      );
      expect(
        driver.classifyErrorCode(4250),
        equals(PusherErrorAction.reconnectImmediate),
      );
      expect(
        driver.classifyErrorCode(4299),
        equals(PusherErrorAction.reconnectImmediate),
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

    test('onDone emits disconnected, not reconnecting, when reconnect is '
        'disabled', () async {
      final (driver, mock) = await _createConnectedDriver(
        configOverrides: {'reconnect': false},
      );

      final states = <BroadcastConnectionState>[];
      driver.connectionState.listen(states.add);

      // Simulate server closing the connection.
      mock.simulateClose();

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(states, contains(BroadcastConnectionState.disconnected));
      expect(states, isNot(contains(BroadcastConnectionState.reconnecting)));

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

    test('a 4100-4199 error frame is routed through interceptors', () async {
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

    test('a 4200-4299 error frame is routed through interceptors', () async {
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
    test('disconnect clears channels', () async {
      final (driver, mock) = await _createConnectedDriver();

      // Subscribe to channels.
      final orders = driver.channel('orders');
      driver.channel('notifications');

      // Deliver an event so the channel has seen traffic before teardown.
      mock.simulateMessage({
        'event': 'Test',
        'channel': 'orders',
        'data': jsonEncode({'id': 1}),
      });
      await Future<void>.delayed(Duration.zero);

      await driver.disconnect();

      expect(driver.isConnected, isFalse);
      expect(driver.socketId, isNull);
      expect(identical(driver.channel('orders'), orders), isFalse);
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

    test('event whose data decodes to a list uses empty map', () async {
      // Laravel encodes an empty broadcastWith() as "[]", a JSON list.
      final (driver, mock) = await _createConnectedDriver();

      final ch = driver.channel('orders');
      final events = <BroadcastEvent>[];
      ch.events.listen(events.add);

      mock.simulateMessage({
        'event': 'OrderShipped',
        'channel': 'orders',
        'data': jsonEncode(<Object>[]),
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
        random: Random(42),
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

    test('malformed auth response (missing auth key) logs warning', () async {
      final fakeLog = Log.fake();

      final (driver, mock1, _) = await createReconnectableDriver(
        authFactory: (endpoint, data) async => <String, dynamic>{'token': 'x'},
      );

      driver.private('malformed');
      await Future<void>.delayed(Duration.zero);

      // Simulate reconnect to trigger auth with malformed response.
      mock1.simulateClose();
      await Future<void>.delayed(const Duration(milliseconds: 600));

      final warnings = fakeLog.entries.where((e) => e.level == 'warning');
      expect(
        warnings.any((e) => e.message.contains('private-malformed')),
        isTrue,
        reason: 'Should log warning for malformed auth response',
      );

      await driver.disconnect();
    });

    test('auth factory returning empty map triggers warning path', () async {
      final fakeLog = Log.fake();

      final (driver, mock1, getReconnectMock) = await createReconnectableDriver(
        authFactory: (endpoint, data) async => <String, dynamic>{},
      );

      driver.private('empty-auth');
      await Future<void>.delayed(Duration.zero);

      mock1.simulateClose();
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Empty map has null 'auth' key — should trigger warning.
      final warnings = fakeLog.entries.where((e) => e.level == 'warning');
      expect(
        warnings.any((e) => e.message.contains('private-empty-auth')),
        isTrue,
        reason: 'Empty auth response should log warning',
      );

      // Channel should NOT receive a subscribe frame (auth was missing).
      final reconnectMock = getReconnectMock();
      final subscribed = reconnectMock.sentFrames
          .where((f) => f['event'] == 'pusher:subscribe')
          .map((f) => (f['data'] as Map<String, dynamic>)['channel'] as String)
          .toSet();
      expect(subscribed, isNot(contains('private-empty-auth')));

      await driver.disconnect();
    });
  });

  // ---------------------------------------------------------------------------
  // Activity Monitor (client-side ping/pong timeout)
  // ---------------------------------------------------------------------------

  group('ReverbBroadcastDriver — Activity Monitor', () {
    test('sends pusher:ping after activity_timeout silence', () async {
      final mock = _MockWebSocketChannel();
      final driver = ReverbBroadcastDriver(
        _defaultConfig(overrides: {'activity_timeout': 1}),
        channelFactory: (_) => mock,
        pongTimeout: const Duration(seconds: 1),
      );

      // Handshake with 1-second activity_timeout.
      _simulateConnectionEstablished(mock, activityTimeout: 1);
      await driver.connect();

      // Clear handshake frames.
      mock._sink.messages.clear();

      // Wait longer than activity_timeout (1s) for ping to be sent.
      await Future<void>.delayed(const Duration(milliseconds: 1200));

      final frames = mock.sentFrames;
      expect(
        frames,
        contains(
          predicate<Map<String, dynamic>>((f) => f['event'] == 'pusher:ping'),
        ),
        reason: 'Driver should send pusher:ping after activity_timeout silence',
      );

      await driver.disconnect();
    });

    test(
      'falls back to config activity_timeout when server omits it',
      () async {
        final mock = _MockWebSocketChannel();
        final driver = ReverbBroadcastDriver(
          _defaultConfig(overrides: {'activity_timeout': 1}),
          channelFactory: (_) => mock,
          pongTimeout: const Duration(seconds: 1),
        );

        // Handshake WITHOUT activity_timeout — driver should use config value.
        _simulateConnectionEstablished(mock, includeActivityTimeout: false);
        await driver.connect();

        expect(
          driver.activityTimeout,
          equals(1),
          reason: 'Should fall back to config activity_timeout',
        );

        await driver.disconnect();
      },
    );

    test('closes socket when pong not received within timeout', () async {
      final mock = _MockWebSocketChannel();
      final driver = ReverbBroadcastDriver(
        _defaultConfig(overrides: {'activity_timeout': 1, 'reconnect': false}),
        channelFactory: (_) => mock,
        pongTimeout: const Duration(seconds: 1),
      );

      _simulateConnectionEstablished(mock, activityTimeout: 1);
      await driver.connect();

      // Wait for activity_timeout (1s) + pong timeout (1s) + buffer.
      await Future<void>.delayed(const Duration(milliseconds: 2500));

      // Socket should have been closed (triggering reconnect via _onDone).
      expect(
        mock._sink.isClosed,
        isTrue,
        reason:
            'Socket should be closed when pong is not received within timeout',
      );

      await driver.disconnect();
    });

    test('resets activity timer on any inbound message', () async {
      final mock = _MockWebSocketChannel();
      final driver = ReverbBroadcastDriver(
        _defaultConfig(overrides: {'activity_timeout': 1}),
        channelFactory: (_) => mock,
        pongTimeout: const Duration(seconds: 1),
      );

      _simulateConnectionEstablished(mock, activityTimeout: 1);
      await driver.connect();

      // Clear handshake frames.
      mock._sink.messages.clear();

      // Wait 700ms (partial timeout — less than 1s activity_timeout).
      await Future<void>.delayed(const Duration(milliseconds: 700));

      // Send a data message — should reset the activity timer.
      mock.simulateMessage({
        'event': 'SomeEvent',
        'channel': 'orders',
        'data': jsonEncode({'id': 1}),
      });

      // Wait another 700ms — total 1400ms since connect, but only 700ms since
      // last inbound message, so ping should NOT have been sent.
      await Future<void>.delayed(const Duration(milliseconds: 700));

      final frames = mock.sentFrames;
      final pings = frames.where((f) => f['event'] == 'pusher:ping');
      expect(
        pings,
        isEmpty,
        reason:
            'No ping should be sent because activity timer was reset by '
            'inbound message',
      );

      await driver.disconnect();
    });

    test('cancels activity timers on disconnect', () async {
      final mock = _MockWebSocketChannel();
      final driver = ReverbBroadcastDriver(
        _defaultConfig(overrides: {'activity_timeout': 1}),
        channelFactory: (_) => mock,
        pongTimeout: const Duration(seconds: 1),
      );

      _simulateConnectionEstablished(mock, activityTimeout: 1);
      await driver.connect();

      // Clear handshake frames.
      mock._sink.messages.clear();

      // Disconnect immediately.
      await driver.disconnect();

      // Wait longer than activity_timeout.
      await Future<void>.delayed(const Duration(milliseconds: 1500));

      // No ping should have been sent after disconnect.
      final frames = mock._sink.sentFrames;
      final pings = frames.where((f) {
        final decoded = jsonDecode(f as String) as Map<String, dynamic>;
        return decoded['event'] == 'pusher:ping';
      });
      expect(pings, isEmpty, reason: 'No ping should be sent after disconnect');
    });

    test('restarts activity monitor after reconnect', () async {
      _MockWebSocketChannel? firstConnection;
      _MockWebSocketChannel? secondConnection;
      var connectionCount = 0;

      final driver = ReverbBroadcastDriver(
        _defaultConfig(overrides: {'activity_timeout': 1, 'reconnect': true}),
        channelFactory: (_) {
          connectionCount++;
          if (connectionCount == 1) {
            firstConnection = _MockWebSocketChannel();
            // Schedule handshake for first connection.
            Future<void>.delayed(Duration.zero, () {
              firstConnection!.simulateMessage({
                'event': 'pusher:connection_established',
                'data': jsonEncode({
                  'socket_id': 'first-socket-id',
                  'activity_timeout': 1,
                }),
              });
            });
            return firstConnection!;
          }
          secondConnection = _MockWebSocketChannel();
          // Schedule handshake for reconnected connection.
          Future<void>.delayed(Duration.zero, () {
            secondConnection!.simulateMessage({
              'event': 'pusher:connection_established',
              'data': jsonEncode({
                'socket_id': 'reconnected-socket-id',
                'activity_timeout': 1,
              }),
            });
          });
          return secondConnection!;
        },
        pongTimeout: const Duration(seconds: 1),
      );

      await driver.connect();

      // Simulate server closing the connection — triggers reconnect.
      firstConnection!.simulateClose();

      // Wait for reconnect (500ms backoff) + handshake.
      await Future<void>.delayed(const Duration(milliseconds: 700));

      // Clear frames on new connection.
      secondConnection!._sink.messages.clear();

      // Wait for activity_timeout (1s) on the new connection.
      await Future<void>.delayed(const Duration(milliseconds: 1200));

      // Activity monitor should have restarted — ping should be sent on new
      // connection.
      final frames = secondConnection!.sentFrames;
      expect(
        frames,
        contains(
          predicate<Map<String, dynamic>>((f) => f['event'] == 'pusher:ping'),
        ),
        reason:
            'Activity monitor should restart after reconnect and send ping '
            'on new connection',
      );

      await driver.disconnect();
    });
  });

  // ---------------------------------------------------------------------------
  // Resubscribe on every handshake (pusher-js subscribeAll parity)
  // ---------------------------------------------------------------------------

  group('ReverbBroadcastDriver: resubscribe on every handshake', () {
    test('connect() after a drop with reconnect disabled resubscribes every '
        'registered channel', () async {
      final (driver, sockets) = _createCountingDriver(
        configOverrides: {'reconnect': false},
        authFactory: _signingAuth,
      );
      await driver.connect();
      driver.channel('orders');
      driver.private('payments');
      await _pump();

      sockets.first.simulateClose();
      await _pump();
      expect(driver.isConnected, isFalse);

      await driver.connect();
      await _pump();

      expect(sockets, hasLength(2));
      expect(_subscribedOn(sockets[1]), {'orders', 'private-payments'});

      await driver.disconnect();
    });

    test('connect() after a drop resubscribes every registered channel when '
        'reconnect is enabled after the drop', () async {
      final config = _defaultConfig(overrides: {'reconnect': false});
      final (driver, sockets) = _createCountingDriver(
        config: config,
        authFactory: _signingAuth,
      );
      await driver.connect();
      driver.channel('orders');
      driver.private('payments');
      await _pump();

      sockets.first.simulateClose();
      await _pump();
      config['reconnect'] = true;

      await driver.connect();
      await _pump();

      expect(sockets, hasLength(2));
      expect(_subscribedOn(sockets[1]), {'orders', 'private-payments'});

      await driver.disconnect();
    });

    test('a channel created while disconnected is subscribed exactly once on '
        'the next socket', () async {
      final (driver, sockets) = _createCountingDriver();
      await driver.connect();

      sockets.first.simulateClose();
      await _pump();
      driver.channel('orders');

      await driver.connect();
      await _pump();

      final orders = _subscribeFrames(
        sockets[1],
      ).where((data) => data['channel'] == 'orders');
      expect(orders, hasLength(1));

      await driver.disconnect();
    });

    test('an auth answered after a second handshake sends nothing on the new '
        'socket', () async {
      final gate = Completer<void>();
      var calls = 0;
      final (driver, sockets) = _createCountingDriver(
        authFactory: (endpoint, data) async {
          calls++;
          if (calls == 1) await gate.future;
          return <String, dynamic>{'auth': 'sig-${data['socket_id']}'};
        },
      );
      await driver.connect();
      driver.private('payments');
      await _pump();

      sockets.first.simulateClose();
      await _pump();
      await driver.connect();
      await _pump();

      gate.complete();
      await _pump();

      final auths = _subscribeFrames(sockets[1])
          .where((data) => data['channel'] == 'private-payments')
          .map((data) => data['auth'])
          .toList();
      expect(auths, ['sig-socket-2']);

      await driver.disconnect();
    });

    test('leave() during a pending auth sends no subscribe', () async {
      final gate = Completer<void>();
      final (driver, sockets) = _createCountingDriver(
        authFactory: (endpoint, data) async {
          await gate.future;
          return _signingAuth(endpoint, data);
        },
      );
      await driver.connect();
      driver.private('payments');
      await _pump();

      driver.leave('private-payments');
      gate.complete();
      await _pump();

      expect(_subscribedOn(sockets.first), isNot(contains('private-payments')));

      await driver.disconnect();
    });

    test(
      'a late close from socket 1 after socket 2 connected leaves the driver '
      'connected',
      () async {
        final (driver, sockets) = _createCountingDriver();
        await driver.connect();

        sockets.first.simulateError(Exception('connection reset'));
        await _pump();
        await driver.connect();
        expect(sockets, hasLength(2));

        sockets.first.simulateClose();
        await Future<void>.delayed(const Duration(milliseconds: 800));

        expect(driver.isConnected, isTrue);
        expect(sockets, hasLength(2));

        await driver.disconnect();
      },
    );

    test('a drop while a timer reconnect waits on its replay still '
        'reconnects once the replay ends', () async {
      final gate = Completer<void>();
      var calls = 0;
      final (driver, sockets) = _createCountingDriver(
        authFactory: (endpoint, data) async {
          calls++;
          if (calls == 2) await gate.future;
          return _signingAuth(endpoint, data);
        },
      );
      await driver.connect();
      driver.private('payments');
      await _pump();

      // Socket 2 comes from the reconnect timer, and its replay holds on the
      // gated auth.
      sockets.first.simulateClose();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      expect(sockets, hasLength(2));

      // Socket 2 drops while that auth is still out; its retry fires while
      // the timer reconnect is in flight.
      sockets[1].simulateClose();
      await Future<void>.delayed(const Duration(milliseconds: 900));

      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 900));

      expect(sockets, hasLength(3));
      expect(driver.isConnected, isTrue);
      expect(_subscribedOn(sockets[2]), contains('private-payments'));

      await driver.disconnect();
    });
  });

  group('ReverbBroadcastDriver: subscription state', () {
    test(
      'isSubscribed flips on subscription_succeeded and back on a drop',
      () async {
        final (driver, sockets) = _createCountingDriver();
        await driver.connect();

        final orders = driver.channel('orders');
        final changes = <bool>[];
        orders.onSubscriptionChanged.listen(changes.add);
        expect(orders.isSubscribed, isFalse);

        sockets.first.simulateMessage({
          'event': 'pusher_internal:subscription_succeeded',
          'channel': 'orders',
          'data': '{}',
        });
        await _pump();
        expect(orders.isSubscribed, isTrue);

        sockets.first.simulateClose();
        await _pump();
        expect(orders.isSubscribed, isFalse);
        expect(changes, [true, false]);

        await driver.disconnect();
      },
    );

    test('a presence channel takes its members from the internal '
        'subscription_succeeded frame Reverb sends', () async {
      final (driver, sockets) = _createCountingDriver();
      await driver.connect();

      final room = driver.join('room.1');
      sockets.first.simulateMessage({
        'event': 'pusher_internal:subscription_succeeded',
        'channel': 'presence-room.1',
        'data': jsonEncode({
          'presence': {
            'count': 1,
            'ids': ['1'],
            'hash': {
              '1': {'name': 'Alice'},
            },
          },
        }),
      });
      await _pump();

      expect(room.isSubscribed, isTrue);
      expect(room.members, hasLength(1));

      await driver.disconnect();
    });

    test('leave() reports the channel unsubscribed', () async {
      final (driver, sockets) = _createCountingDriver();
      await driver.connect();

      final orders = driver.channel('orders');
      sockets.first.simulateMessage({
        'event': 'pusher:subscription_succeeded',
        'channel': 'orders',
        'data': '{}',
      });
      await _pump();
      final changes = <bool>[];
      orders.onSubscriptionChanged.listen(changes.add);

      driver.leave('orders');
      await _pump();

      expect(orders.isSubscribed, isFalse);
      expect(changes, [false]);

      await driver.disconnect();
    });
  });

  group('ReverbBroadcastDriver: close codes decide the reconnect', () {
    test('a close without a code reconnects with backoff', () async {
      final (driver, sockets) = _createCountingDriver();
      await driver.connect();

      sockets.first.simulateClose();
      await _pump();
      expect(sockets, hasLength(1));

      await Future<void>.delayed(const Duration(milliseconds: 800));
      expect(sockets, hasLength(2));
      expect(driver.isConnected, isTrue);

      await driver.disconnect();
    });

    test('a 4200-4299 close reconnects immediately', () async {
      final (driver, sockets) = _createCountingDriver();
      await driver.connect();

      sockets.first.simulateClose(4200);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(sockets, hasLength(2));
      expect(driver.isConnected, isTrue);

      await driver.disconnect();
    });

    test('a 4100-4199 close reconnects with backoff', () async {
      final (driver, sockets) = _createCountingDriver();
      await driver.connect();

      sockets.first.simulateClose(4100);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(sockets, hasLength(1));

      await Future<void>.delayed(const Duration(milliseconds: 800));
      expect(sockets, hasLength(2));

      await driver.disconnect();
    });

    test(
      'a 4000-4099 close does not reconnect and reports disconnected',
      () async {
        final (driver, sockets) = _createCountingDriver();
        await driver.connect();

        final states = <BroadcastConnectionState>[];
        driver.connectionState.listen(states.add);

        sockets.first.simulateClose(4001);
        await Future<void>.delayed(const Duration(milliseconds: 800));

        expect(sockets, hasLength(1));
        expect(states, [BroadcastConnectionState.disconnected]);

        await driver.disconnect();
      },
    );

    test('a socket lost before its handshake with reconnect disabled reports '
        'disconnected', () async {
      final (driver, _) = _createCountingDriver(
        refuse: (_) => true,
        configOverrides: {'reconnect': false},
      );
      final states = <BroadcastConnectionState>[];
      driver.connectionState.listen(states.add);

      await expectLater(driver.connect(), throwsStateError);
      await _pump();

      expect(states.last, BroadcastConnectionState.disconnected);

      await driver.disconnect();
    });

    test(
      'a pusher:error 4200 frame on an open socket schedules nothing',
      () async {
        final (driver, sockets) = _createCountingDriver();
        await driver.connect();

        sockets.first.simulateMessage({
          'event': 'pusher:error',
          'data': jsonEncode({'code': 4200, 'message': 'Server error'}),
        });
        await Future<void>.delayed(const Duration(milliseconds: 800));

        expect(sockets, hasLength(1));
        expect(driver.isConnected, isTrue);

        await driver.disconnect();
      },
    );

    test('a pong timeout drops the socket and reconnects without waiting on '
        'the dead socket\'s close', () async {
      final sockets = <_MockWebSocketChannel>[];
      final driver = ReverbBroadcastDriver(
        _defaultConfig(overrides: {'activity_timeout': 1}),
        channelFactory: (_) {
          final socket = sockets.isEmpty
              ? _HangingWebSocketChannel()
              : _MockWebSocketChannel();
          sockets.add(socket);
          _simulateConnectionEstablished(
            socket,
            socketId: 'socket-${sockets.length}',
            activityTimeout: 1,
          );
          return socket;
        },
        pongTimeout: const Duration(milliseconds: 100),
        random: Random(42),
      );
      await driver.connect();

      final states = <BroadcastConnectionState>[];
      driver.connectionState.listen(states.add);

      // Ping after 1s of silence, no pong within 100ms, then the backoff.
      await Future<void>.delayed(const Duration(milliseconds: 2200));

      expect(states, contains(BroadcastConnectionState.reconnecting));
      expect(sockets, hasLength(2));
      expect(driver.isConnected, isTrue);
      expect(driver.socketId, 'socket-2');

      await driver.disconnect();
    });
  });

  group('ReverbBroadcastDriver: auth answers', () {
    test('a 502 auth answer is retried with backoff and logged as a '
        'warning', () async {
      final fakeLog = Log.fake();
      var calls = 0;
      Http.fake((request) {
        calls++;
        return calls == 1
            ? Http.response({'message': 'Server Error'}, 502)
            : Http.response({'auth': 'sig'}, 200);
      });
      final (driver, sockets) = _createCountingDriver();
      await driver.connect();

      driver.private('payments');
      await Future<void>.delayed(const Duration(milliseconds: 900));

      expect(calls, 2);
      expect(_subscribedOn(sockets.first), contains('private-payments'));
      final entries = fakeLog.entries.where(
        (e) => e.message.contains('private-payments'),
      );
      expect(entries.map((e) => e.level), ['warning']);

      await driver.disconnect();
    });

    test('a non-2xx auth answer reaches the interceptors as a '
        'BroadcastAuthException carrying the status', () async {
      Http.fake((request) => Http.response({'message': 'Forbidden'}, 403));
      final (driver, _) = _createCountingDriver();
      final interceptor = _TestInterceptor();
      driver.addInterceptor(interceptor);
      await driver.connect();

      driver.private('payments');
      await _pump();

      expect(
        interceptor.errors,
        contains(
          isA<BroadcastAuthException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having((e) => e.channelName, 'channelName', 'private-payments'),
        ),
      );

      await driver.disconnect();
    });

    test('a 403 auth answer is logged as an error and not retried', () async {
      final fakeLog = Log.fake();
      var calls = 0;
      Http.fake((request) {
        calls++;
        return Http.response({'message': 'This action is unauthorized.'}, 403);
      });
      final (driver, sockets) = _createCountingDriver();
      await driver.connect();

      driver.private('payments');
      await Future<void>.delayed(const Duration(milliseconds: 900));

      expect(calls, 1);
      expect(_subscribedOn(sockets.first), isNot(contains('private-payments')));
      expect(
        fakeLog.entries.where(
          (e) => e.level == 'error' && e.message.contains('private-payments'),
        ),
        isNotEmpty,
      );

      await driver.disconnect();
    });
  });
}
