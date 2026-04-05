import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../facades/http.dart';
import '../broadcast_connection_state.dart';
import '../broadcast_event.dart';
import '../contracts/broadcast_channel.dart';
import '../contracts/broadcast_driver.dart';
import '../contracts/broadcast_interceptor.dart';
import '../contracts/broadcast_presence_channel.dart';

/// Pusher error code classification for reconnection strategy.
///
/// Pusher protocol defines three error ranges that dictate how the client
/// should respond after receiving an error frame.
enum PusherErrorAction {
  /// 4000–4099: Do not reconnect — the error is permanent.
  fatal,

  /// 4100–4199: Reconnect immediately without backoff.
  reconnectImmediate,

  /// 4200–4299: Reconnect with exponential backoff.
  reconnectBackoff,
}

/// A [BroadcastDriver] that connects to Laravel Reverb (Pusher-compatible)
/// via a pure-Dart WebSocket client.
///
/// Handles the full Pusher protocol: connection handshake, application-level
/// ping/pong, channel subscriptions (public, private, presence), event
/// deduplication, interceptor chains, and automatic reconnection with
/// exponential backoff.
///
/// ## Usage
/// ```dart
/// final driver = ReverbBroadcastDriver({
///   'host': 'localhost',
///   'port': 8080,
///   'scheme': 'ws',
///   'app_key': 'my-app-key',
///   'auth_endpoint': '/broadcasting/auth',
/// });
/// await driver.connect();
/// driver.channel('orders').listen('OrderShipped', (event) {
///   print(event.data);
/// });
/// ```
class ReverbBroadcastDriver implements BroadcastDriver {
  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------

  /// Creates a [ReverbBroadcastDriver].
  ///
  /// [config] contains connection parameters read from
  /// `broadcasting.connections.reverb`. [channelFactory] overrides WebSocket
  /// creation for testing — defaults to [WebSocketChannel.connect].
  ReverbBroadcastDriver(
    this._config, {
    WebSocketChannel Function(Uri uri)? channelFactory,
  }) : _channelFactory = channelFactory ?? WebSocketChannel.connect;

  // ---------------------------------------------------------------------------
  // Dependencies
  // ---------------------------------------------------------------------------

  final Map<String, dynamic> _config;
  final WebSocketChannel Function(Uri uri) _channelFactory;

  // ---------------------------------------------------------------------------
  // Connection state
  // ---------------------------------------------------------------------------

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _streamSubscription;
  bool _isConnected = false;
  String? _socketId;

  /// The activity timeout in seconds reported by the server.
  ///
  /// Parsed from the `pusher:connection_established` frame. Used to determine
  /// how frequently the server expects keepalive traffic.
  int activityTimeout = 30;
  Completer<void>? _connectionCompleter;

  /// Broadcast controller that re-exposes the single-subscription
  /// [WebSocketChannel.stream] as a multi-subscriber stream for internal
  /// multi-channel routing.
  StreamController<dynamic>? _broadcastStreamController;

  final StreamController<BroadcastConnectionState> _connectionStateController =
      StreamController<BroadcastConnectionState>.broadcast();

  final StreamController<void> _onReconnectController =
      StreamController<void>.broadcast();

  // ---------------------------------------------------------------------------
  // Channel management
  // ---------------------------------------------------------------------------

  final Map<String, ReverbBroadcastChannel> _channels =
      <String, ReverbBroadcastChannel>{};

  // ---------------------------------------------------------------------------
  // Subscription queue — buffers subscribe calls during reconnection
  // ---------------------------------------------------------------------------

  final List<void Function()> _subscriptionQueue = <void Function()>[];

  // ---------------------------------------------------------------------------
  // Deduplication — ring buffer
  // ---------------------------------------------------------------------------

  final Queue<String> _dedupQueue = Queue<String>();
  final Set<String> _dedupSet = <String>{};

  // ---------------------------------------------------------------------------
  // Reconnection
  // ---------------------------------------------------------------------------

  Timer? _reconnectTimer;
  int _attempt = 0;

  // ---------------------------------------------------------------------------
  // Interceptors
  // ---------------------------------------------------------------------------

  final List<BroadcastInterceptor> _interceptors = <BroadcastInterceptor>[];

  // ---------------------------------------------------------------------------
  // BroadcastDriver — getters
  // ---------------------------------------------------------------------------

  @override
  String? get socketId => _socketId;

  @override
  bool get isConnected => _isConnected;

  @override
  Stream<BroadcastConnectionState> get connectionState =>
      _connectionStateController.stream;

  @override
  Stream<void> get onReconnect => _onReconnectController.stream;

  // ---------------------------------------------------------------------------
  // BroadcastDriver — connection lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> connect() async {
    _connectionStateController.add(BroadcastConnectionState.connecting);

    final host = _config['host'] as String;
    final port = _config['port'] as int;
    final scheme = _config['scheme'] as String;
    final appKey = _config['app_key'] as String;

    final uri = Uri.parse(
      '$scheme://$host:$port/app/$appKey'
      '?protocol=7&client=dart&version=1.0.0',
    );

    _channel = _channelFactory(uri);
    await _channel!.ready;

    _connectionCompleter = Completer<void>();

    // Wrap the single-subscription stream as a broadcast stream.
    _broadcastStreamController = StreamController<dynamic>.broadcast();
    _streamSubscription = _channel!.stream.listen(
      _broadcastStreamController!.add,
      onDone: () {
        _broadcastStreamController?.close();
        _onDone();
      },
      onError: (Object error) {
        _broadcastStreamController?.addError(error);
        _onError(error);
      },
    );

    _broadcastStreamController!.stream.listen(
      (raw) {
        try {
          _onMessage(raw);
        } on StateError catch (error) {
          // Protocol violation (e.g. missing 'event' key). Route through
          // interceptor error chain rather than crashing the subscription.
          dynamic processed = error;
          for (final interceptor in _interceptors) {
            processed = interceptor.onError(processed);
          }
        }
      },
      onError: (Object error) {
        // Route stream-level errors through interceptors.
        dynamic processed = error;
        for (final interceptor in _interceptors) {
          processed = interceptor.onError(processed);
        }
      },
    );

    return _connectionCompleter!.future;
  }

  @override
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _attempt = 0;

    _subscriptionQueue.clear();

    _streamSubscription?.cancel();
    _streamSubscription = null;

    _broadcastStreamController?.close();
    _broadcastStreamController = null;

    _channel?.sink.close();
    _channel = null;

    _isConnected = false;
    _socketId = null;

    // Dispose all channels.
    for (final channel in _channels.values) {
      channel.dispose();
    }
    _channels.clear();

    _dedupQueue.clear();
    _dedupSet.clear();

    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.complete();
    }
    _connectionCompleter = null;

    _connectionStateController.add(BroadcastConnectionState.disconnected);
  }

  // ---------------------------------------------------------------------------
  // BroadcastDriver — channel operations
  // ---------------------------------------------------------------------------

  @override
  BroadcastChannel channel(String name) {
    if (_channels.containsKey(name)) {
      return _channels[name]!;
    }

    final ch = ReverbBroadcastChannel(name);
    _channels[name] = ch;
    _subscribePublic(name);
    return ch;
  }

  @override
  BroadcastChannel private(String name) {
    final prefixed = name.startsWith('private-') ? name : 'private-$name';

    if (_channels.containsKey(prefixed)) {
      return _channels[prefixed]!;
    }

    final ch = ReverbBroadcastChannel(prefixed);
    _channels[prefixed] = ch;
    _subscribePrivate(prefixed);
    return ch;
  }

  @override
  BroadcastPresenceChannel join(String name) {
    final prefixed = name.startsWith('presence-') ? name : 'presence-$name';

    if (_channels.containsKey(prefixed)) {
      return _channels[prefixed]! as ReverbBroadcastPresenceChannel;
    }

    final ch = ReverbBroadcastPresenceChannel(prefixed);
    _channels[prefixed] = ch;
    _subscribePresence(prefixed);
    return ch;
  }

  @override
  void leave(String name) {
    final ch = _channels.remove(name);
    if (ch == null) return;

    _send({
      'event': 'pusher:unsubscribe',
      'data': <String, dynamic>{'channel': name},
    });

    ch.dispose();
  }

  @override
  void addInterceptor(BroadcastInterceptor interceptor) {
    _interceptors.add(interceptor);
  }

  // ---------------------------------------------------------------------------
  // Backoff delay — pure function, exposed for testing
  // ---------------------------------------------------------------------------

  /// Computes the reconnect delay for [attempt] using exponential backoff.
  ///
  /// Formula: `min(500 * 2^attempt, maxReconnectDelay)` milliseconds.
  Duration backoffDelay(int attempt) {
    final maxDelay = _config['max_reconnect_delay'] as int? ?? 30000;
    final ms = min(500 * pow(2, attempt).toInt(), maxDelay);
    return Duration(milliseconds: ms);
  }

  /// Classifies a Pusher error [code] into a reconnection action.
  ///
  /// - 4000–4099: [PusherErrorAction.fatal] — do not reconnect.
  /// - 4100–4199: [PusherErrorAction.reconnectImmediate] — reconnect without delay.
  /// - 4200–4299: [PusherErrorAction.reconnectBackoff] — reconnect with backoff.
  /// - Other: defaults to [PusherErrorAction.reconnectBackoff].
  PusherErrorAction classifyErrorCode(int code) {
    if (code >= 4000 && code <= 4099) {
      return PusherErrorAction.fatal;
    }
    if (code >= 4100 && code <= 4199) {
      return PusherErrorAction.reconnectImmediate;
    }
    return PusherErrorAction.reconnectBackoff;
  }

  // ---------------------------------------------------------------------------
  // Pusher protocol handling (private)
  // ---------------------------------------------------------------------------

  void _onMessage(dynamic raw) {
    final json = jsonDecode(raw as String) as Map<String, dynamic>;
    final event = json['event'] as String?;

    if (event == null) {
      throw StateError(
        'Received WebSocket frame without required "event" key: $json',
      );
    }

    switch (event) {
      case 'pusher:connection_established':
        _handleConnectionEstablished(json);
      case 'pusher:ping':
        _sendPong();
      case 'pusher:subscription_succeeded':
        _handleSubscriptionSucceeded(json);
      case 'pusher:error':
        _handlePusherError(json);
      case 'pusher_internal:member_added':
        _handlePresenceEvent(json);
      case 'pusher_internal:member_removed':
        _handlePresenceEvent(json);
      default:
        _handleApplicationEvent(json);
    }
  }

  void _handleConnectionEstablished(Map<String, dynamic> json) {
    final data = jsonDecode(json['data'] as String) as Map<String, dynamic>;
    _socketId = data['socket_id'] as String;
    activityTimeout = data['activity_timeout'] as int? ?? 30;
    _isConnected = true;
    _attempt = 0;

    _connectionStateController.add(BroadcastConnectionState.connected);

    // Flush subscription queue.
    if (_subscriptionQueue.isNotEmpty) {
      for (final action in _subscriptionQueue) {
        action();
      }
      _subscriptionQueue.clear();
    }

    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.complete();
    }
  }

  void _handleSubscriptionSucceeded(Map<String, dynamic> json) {
    final channelName = json['channel'] as String?;
    if (channelName == null) return;

    final ch = _channels[channelName];
    if (ch is ReverbBroadcastPresenceChannel) {
      final rawData = json['data'];
      final Map<String, dynamic> data;
      if (rawData is String) {
        data = jsonDecode(rawData) as Map<String, dynamic>;
      } else if (rawData is Map<String, dynamic>) {
        data = rawData;
      } else {
        return;
      }
      ch.handlePresenceEvent('pusher:subscription_succeeded', data);
    }
  }

  void _handlePusherError(Map<String, dynamic> json) {
    final rawData = json['data'];

    // Route through interceptor chain.
    dynamic error = StateError('Pusher error: $rawData');
    for (final interceptor in _interceptors) {
      error = interceptor.onError(error);
    }

    if (rawData is String) {
      try {
        final data = jsonDecode(rawData) as Map<String, dynamic>;
        final code = data['code'] as int?;
        if (code != null) {
          final action = classifyErrorCode(code);
          switch (action) {
            case PusherErrorAction.fatal:
              // Do not reconnect.
              return;
            case PusherErrorAction.reconnectImmediate:
              _scheduleReconnect(immediate: true);
            case PusherErrorAction.reconnectBackoff:
              _scheduleReconnect();
          }
        }
      } catch (_) {
        // Malformed data.
      }
    }
  }

  void _handlePresenceEvent(Map<String, dynamic> json) {
    final channelName = json['channel'] as String?;
    if (channelName == null) return;

    final ch = _channels[channelName];
    if (ch is! ReverbBroadcastPresenceChannel) return;

    final event = json['event'] as String;
    final rawData = json['data'];
    final Map<String, dynamic> data;
    if (rawData is String) {
      data = jsonDecode(rawData) as Map<String, dynamic>;
    } else if (rawData is Map<String, dynamic>) {
      data = rawData;
    } else {
      return;
    }

    ch.handlePresenceEvent(event, data);
  }

  void _handleApplicationEvent(Map<String, dynamic> json) {
    final channelName = json['channel'] as String?;
    if (channelName == null) return;

    final ch = _channels[channelName];
    if (ch == null) return;

    final eventName = json['event'] as String;
    final rawData = json['data'];

    // Deduplication.
    final rawDataString = rawData is String ? rawData : jsonEncode(rawData);
    final dedupKey = '$channelName:$eventName:$rawDataString';
    final maxDedupSize = _config['dedup_buffer_size'] as int? ?? 100;

    if (_dedupSet.contains(dedupKey)) return;
    _addToDedupBuffer(dedupKey, maxDedupSize);

    // Double-JSON decode: if data is a String, decode it. If already a Map,
    // use directly.
    final Map<String, dynamic> data;
    if (rawData is String) {
      data = jsonDecode(rawData) as Map<String, dynamic>;
    } else if (rawData is Map<String, dynamic>) {
      data = rawData;
    } else {
      data = <String, dynamic>{};
    }

    var event = BroadcastEvent(
      event: eventName,
      channel: channelName,
      data: data,
      receivedAt: DateTime.now(),
    );

    // Interceptor chain — onReceive.
    for (final interceptor in _interceptors) {
      event = interceptor.onReceive(event);
    }

    ch.addEvent(event);
  }

  // ---------------------------------------------------------------------------
  // Deduplication ring buffer
  // ---------------------------------------------------------------------------

  void _addToDedupBuffer(String key, int maxSize) {
    _dedupQueue.add(key);
    _dedupSet.add(key);

    if (_dedupQueue.length > maxSize) {
      final evicted = _dedupQueue.removeFirst();
      _dedupSet.remove(evicted);
    }
  }

  // ---------------------------------------------------------------------------
  // Subscription helpers
  // ---------------------------------------------------------------------------

  void _subscribePublic(String name) {
    if (!_isConnected) {
      _subscriptionQueue.add(() => _subscribePublic(name));
      return;
    }

    _send({
      'event': 'pusher:subscribe',
      'data': <String, dynamic>{'channel': name},
    });
  }

  void _subscribePrivate(String name) {
    if (!_isConnected) {
      _subscriptionQueue.add(() => _subscribePrivate(name));
      return;
    }

    _authenticateAndSubscribe(name);
  }

  void _subscribePresence(String name) {
    if (!_isConnected) {
      _subscriptionQueue.add(() => _subscribePresence(name));
      return;
    }

    _authenticateAndSubscribe(name);
  }

  /// Authenticates a private or presence channel via HTTP POST and then sends
  /// the `pusher:subscribe` frame with the auth token.
  Future<void> _authenticateAndSubscribe(String channelName) async {
    if (_socketId == null) return;

    try {
      final authEndpoint =
          _config['auth_endpoint'] as String? ?? '/broadcasting/auth';

      final response = await Http.post(
        authEndpoint,
        data: <String, dynamic>{
          'socket_id': _socketId,
          'channel_name': channelName,
        },
      );

      final authData = response.data;
      if (authData is! Map<String, dynamic> || authData['auth'] == null) return;

      final subscribeData = <String, dynamic>{
        'channel': channelName,
        'auth': authData['auth'],
      };

      // Presence channels include channel_data.
      if (authData.containsKey('channel_data')) {
        subscribeData['channel_data'] = authData['channel_data'];
      }

      _send({'event': 'pusher:subscribe', 'data': subscribeData});
    } catch (_) {
      // Auth failure — channel will not be subscribed.
    }
  }

  // ---------------------------------------------------------------------------
  // Reconnection
  // ---------------------------------------------------------------------------

  void _onDone() {
    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.completeError(
        StateError('WebSocket closed before connection established'),
      );
      _connectionCompleter = null;
    }

    if (!_isConnected) return;
    _isConnected = false;
    _socketId = null;
    _connectionStateController.add(BroadcastConnectionState.reconnecting);
    _scheduleReconnect();
  }

  void _onError(Object error) {
    // Route through interceptor chain.
    dynamic processed = error;
    for (final interceptor in _interceptors) {
      processed = interceptor.onError(processed);
    }

    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.completeError(error);
      _connectionCompleter = null;
    }

    if (!_isConnected) return;
    _isConnected = false;
    _socketId = null;
    _connectionStateController.add(BroadcastConnectionState.reconnecting);
    _scheduleReconnect();
  }

  void _scheduleReconnect({bool immediate = false}) {
    final shouldReconnect = _config['reconnect'] as bool? ?? true;
    if (!shouldReconnect) return;

    _reconnectTimer?.cancel();

    final delay = immediate ? Duration.zero : backoffDelay(_attempt);
    _attempt++;

    _reconnectTimer = Timer(delay, () async {
      try {
        _streamSubscription?.cancel();
        _streamSubscription = null;
        _broadcastStreamController?.close();
        _broadcastStreamController = null;
        try {
          await _channel?.sink.close();
        } catch (_) {}
        _channel = null;
        _isConnected = false;

        await connect();

        // Resubscribe all channels.
        for (final entry in _channels.entries) {
          final name = entry.key;
          if (name.startsWith('presence-') || name.startsWith('private-')) {
            _authenticateAndSubscribe(name);
          } else {
            _send({
              'event': 'pusher:subscribe',
              'data': <String, dynamic>{'channel': name},
            });
          }
        }

        _onReconnectController.add(null);
      } catch (_) {
        _scheduleReconnect();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Wire protocol helpers
  // ---------------------------------------------------------------------------

  void _sendPong() {
    _send({'event': 'pusher:pong', 'data': <String, dynamic>{}});
  }

  void _send(Map<String, dynamic> payload) {
    // Interceptor chain — onSend.
    var message = payload;
    for (final interceptor in _interceptors) {
      message = interceptor.onSend(message);
    }

    final encoded = jsonEncode(message);
    _channel?.sink.add(encoded);
  }
}

// ---------------------------------------------------------------------------
// ReverbBroadcastChannel
// ---------------------------------------------------------------------------

/// A [BroadcastChannel] implementation backed by a [StreamController] that
/// receives events routed by the [ReverbBroadcastDriver].
class ReverbBroadcastChannel implements BroadcastChannel {
  /// Creates a [ReverbBroadcastChannel] for [name].
  ReverbBroadcastChannel(this.name);

  @override
  final String name;

  final StreamController<BroadcastEvent> _controller =
      StreamController<BroadcastEvent>.broadcast();

  final Map<String, StreamSubscription<BroadcastEvent>> _listeners =
      <String, StreamSubscription<BroadcastEvent>>{};

  @override
  Stream<BroadcastEvent> get events => _controller.stream;

  @override
  BroadcastChannel listen(
    String event,
    void Function(BroadcastEvent) callback,
  ) {
    // Cancel any existing listener for this event name.
    _listeners[event]?.cancel();

    _listeners[event] = _controller.stream
        .where((e) => e.event == event)
        .listen(callback);

    return this;
  }

  @override
  void stopListening(String event) {
    _listeners[event]?.cancel();
    _listeners.remove(event);
  }

  /// Adds an [event] to this channel's stream (internal, called by driver).
  void addEvent(BroadcastEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  /// Disposes this channel, cancelling all listeners and closing the stream.
  void dispose() {
    for (final sub in _listeners.values) {
      sub.cancel();
    }
    _listeners.clear();
    _controller.close();
  }
}

// ---------------------------------------------------------------------------
// ReverbBroadcastPresenceChannel
// ---------------------------------------------------------------------------

/// A presence-aware [BroadcastChannel] that tracks connected members and
/// emits join/leave events.
class ReverbBroadcastPresenceChannel extends ReverbBroadcastChannel
    implements BroadcastPresenceChannel {
  /// Creates a [ReverbBroadcastPresenceChannel] for [name].
  ReverbBroadcastPresenceChannel(super.name);

  final List<Map<String, dynamic>> _members = <Map<String, dynamic>>[];

  final StreamController<Map<String, dynamic>> _onJoinController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _onLeaveController =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  List<Map<String, dynamic>> get members =>
      List<Map<String, dynamic>>.unmodifiable(_members);

  @override
  Stream<Map<String, dynamic>> get onJoin => _onJoinController.stream;

  @override
  Stream<Map<String, dynamic>> get onLeave => _onLeaveController.stream;

  /// Handles a Pusher internal presence event.
  ///
  /// Supports `pusher_internal:member_added`, `pusher_internal:member_removed`,
  /// and `pusher:subscription_succeeded`.
  void handlePresenceEvent(String event, Map<String, dynamic> data) {
    switch (event) {
      case 'pusher_internal:member_added':
        _members.add(data);
        _onJoinController.add(data);
      case 'pusher_internal:member_removed':
        _members.removeWhere((m) => m['user_id'] == data['user_id']);
        _onLeaveController.add(data);
      case 'pusher:subscription_succeeded':
        _parseInitialMembers(data);
    }
  }

  void _parseInitialMembers(Map<String, dynamic> data) {
    final presence = data['presence'] as Map<String, dynamic>?;
    if (presence == null) return;

    final hash = presence['hash'] as Map<String, dynamic>? ?? {};
    _members.clear();
    for (final entry in hash.entries) {
      _members.add(<String, dynamic>{
        'user_id': entry.key,
        'user_info': entry.value,
      });
    }
  }

  @override
  void dispose() {
    _onJoinController.close();
    _onLeaveController.close();
    super.dispose();
  }
}
