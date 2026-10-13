import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../facades/http.dart';
import '../../facades/log.dart';
import '../broadcast_connection_state.dart';
import '../broadcast_event.dart';
import '../contracts/broadcast_channel.dart';
import '../contracts/broadcast_driver.dart';
import '../contracts/broadcast_interceptor.dart';
import '../contracts/broadcast_presence_channel.dart';

/// Pusher close code classification for reconnection strategy.
///
/// The Pusher protocol groups the WebSocket close codes a server sends into
/// three ranges that dictate how the client reconnects. The close code
/// decides; a `pusher:error` frame on an open socket never does.
enum PusherErrorAction {
  /// 4000-4099: Do not reconnect, the error is permanent.
  fatal,

  /// 4200-4299: Reconnect immediately without backoff.
  reconnectImmediate,

  /// 4100-4199, any other code, or a close without a code: reconnect with
  /// exponential backoff.
  reconnectBackoff,
}

/// Thrown by the default auth call when the broadcasting auth endpoint
/// answers outside 2xx.
///
/// `Http.post` hands back a response for a 4xx or 5xx instead of throwing, so
/// without this a refused auth looked like a malformed answer and the status
/// was lost. [isRetryable] tells a transient failure (no response, a 5xx)
/// from a refusal (401, 403) that retrying cannot fix.
class BroadcastAuthException implements Exception {
  /// Creates a [BroadcastAuthException].
  ///
  /// [statusCode] is `0` when no response arrived at all.
  BroadcastAuthException({
    required this.channelName,
    required this.statusCode,
    this.message,
  });

  /// The fully-qualified channel the auth call was for.
  final String channelName;

  /// The HTTP status the endpoint answered with, `0` when none arrived.
  final int statusCode;

  /// The error message the response carried, if any.
  final String? message;

  /// Whether the driver retries the auth: on no response and on a 5xx.
  bool get isRetryable => statusCode == 0 || statusCode >= 500;

  @override
  String toString() =>
      'BroadcastAuthException: auth for $channelName failed with status '
      '$statusCode${message == null ? '' : ': $message'}';
}

/// A [BroadcastDriver] that connects to Laravel Reverb (Pusher-compatible)
/// via a pure-Dart WebSocket client.
///
/// Handles the full Pusher protocol: connection handshake, application-level
/// ping/pong, channel subscriptions (public, private, presence), interceptor
/// chains, and automatic reconnection with exponential backoff. Every
/// handshake subscribes every registered channel with the new socket id, as
/// pusher-js does, so a channel survives any number of reconnects.
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
  /// creation for testing, defaulting to [WebSocketChannel.connect].
  /// [authFactory] overrides the HTTP auth call for testing; the default
  /// calls [Http.post] and throws a [BroadcastAuthException] on a non-2xx
  /// answer. An override that throws a retryable [BroadcastAuthException]
  /// is retried the same way.
  ReverbBroadcastDriver(
    this._config, {
    WebSocketChannel Function(Uri uri)? channelFactory,
    Future<Map<String, dynamic>> Function(
      String endpoint,
      Map<String, dynamic> data,
    )?
    authFactory,
    this.pongTimeout = _kPongTimeout,
    Random? random,
  }) : _channelFactory = channelFactory ?? WebSocketChannel.connect,
       _authFactory = authFactory ?? _defaultAuthFactory,
       _random = random ?? Random();

  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------

  static const Duration _kPongTimeout = Duration(seconds: 30);

  // ---------------------------------------------------------------------------
  // Dependencies
  // ---------------------------------------------------------------------------

  final Map<String, dynamic> _config;
  final WebSocketChannel Function(Uri uri) _channelFactory;
  final Future<Map<String, dynamic>> Function(
    String endpoint,
    Map<String, dynamic> data,
  )
  _authFactory;

  final Random _random;

  /// The duration to wait for a pong response after sending a ping.
  final Duration pongTimeout;

  /// Posts the auth request and returns the decoded body.
  ///
  /// @throws BroadcastAuthException when the endpoint answers outside 2xx,
  ///   or with status `0` when no response arrived.
  static Future<Map<String, dynamic>> _defaultAuthFactory(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final response = await Http.post(endpoint, data: data);
    if (!response.successful) {
      throw BroadcastAuthException(
        channelName: data['channel_name'] as String,
        statusCode: response.statusCode,
        message: response.message,
      );
    }

    final responseData = response.data;

    if (responseData is Map<String, dynamic>) {
      return responseData;
    }

    if (responseData is Map) {
      return Map<String, dynamic>.from(responseData);
    }

    return <String, dynamic>{};
  }

  // ---------------------------------------------------------------------------
  // Connection state
  // ---------------------------------------------------------------------------

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _streamSubscription;
  bool _isConnected = false;
  String? _socketId;

  /// The activity timeout in seconds.
  ///
  /// Parsed from the `pusher:connection_established` frame if provided by the
  /// server; otherwise falls back to the `activity_timeout` config key.
  late int activityTimeout = _config['activity_timeout'] as int? ?? 120;
  Completer<void>? _connectionCompleter;

  /// Broadcast controller that re-exposes the single-subscription
  /// [WebSocketChannel.stream] as a multi-subscriber stream for internal
  /// multi-channel routing.
  StreamController<dynamic>? _broadcastStreamController;

  final StreamController<BroadcastConnectionState> _connectionStateController =
      StreamController<BroadcastConnectionState>.broadcast();

  final StreamController<void> _onReconnectController =
      StreamController<void>.broadcast();

  /// Identifies the current socket. Bumped when a socket opens and when it
  /// is dropped, so anything started for one socket (an auth call, a stream
  /// callback, an auth retry) can tell it outlived that socket and stop.
  int _generation = 0;

  /// Whether a handshake completed since the last [disconnect], which makes
  /// the next handshake a reconnect.
  bool _connectedBefore = false;

  /// The resubscription the latest handshake started, awaited by
  /// [_reconnect] so a superseding [connect] resolves after it.
  Future<void>? _replay;

  // ---------------------------------------------------------------------------
  // Channel management
  // ---------------------------------------------------------------------------

  /// Every channel the app holds, the single source the handshake replays.
  final Map<String, ReverbBroadcastChannel> _channels =
      <String, ReverbBroadcastChannel>{};

  // ---------------------------------------------------------------------------
  // Reconnection
  // ---------------------------------------------------------------------------

  Timer? _reconnectTimer;
  int _attempt = 0;

  /// The socket-opening attempt currently in flight, or `null` when none is.
  ///
  /// Shared by the public [connect] and the reconnect timer, so any caller
  /// arriving while an attempt runs joins it instead of opening a second
  /// socket beside it.
  Future<void>? _inFlight;

  /// Bumped by [disconnect] so an attempt still suspended across an await
  /// can tell it was cancelled and stop before touching a socket.
  int _epoch = 0;

  // ---------------------------------------------------------------------------
  // Activity monitor
  // ---------------------------------------------------------------------------

  Timer? _activityTimer;
  Timer? _pongTimer;

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

  /// Emits after each reconnect handshake, once every registered channel has
  /// been sent its subscribe (private and presence channels after their first
  /// auth attempt). Never emits for the first connection after [disconnect].
  @override
  Stream<void> get onReconnect => _onReconnectController.stream;

  // ---------------------------------------------------------------------------
  // BroadcastDriver — connection lifecycle
  // ---------------------------------------------------------------------------

  /// Connects to the Reverb server. Idempotent: the driver never holds more
  /// than one socket, however many callers ask.
  ///
  /// Returns at once when already connected, and joins the attempt already
  /// in flight (a concurrent [connect] or a timer-driven retry) instead of
  /// starting another. The connection state stream alone cannot tell a
  /// caller whether a retry is pending (a failed timer retry re-arms without
  /// emitting anything), so the guard has to live here, where the retry
  /// state is.
  ///
  /// When a reconnect timer is armed, the call supersedes it: the timer is
  /// cancelled and the same reconnect work runs now, and the call resolves
  /// once every channel has been resubscribed. Superseding rather than
  /// joining is deliberate: joining would park the caller for the rest of
  /// the backoff (up to `max_reconnect_delay`), while an explicit connect
  /// asks for a connection now. A failed attempt arms one retry before it
  /// throws, so a superseding call never ends the reconnect loop it replaced.
  ///
  /// Every handshake, whichever path reached it, resubscribes every
  /// registered channel.
  ///
  /// @throws TimeoutException when the handshake does not arrive within
  ///   `connection_timeout` seconds; a retry is armed before the throw.
  /// @throws StateError when the server closes the socket before the
  ///   handshake.
  @override
  Future<void> connect() {
    if (_isConnected) return Future<void>.value();

    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final retryTimer = _reconnectTimer;
    if (retryTimer != null && retryTimer.isActive) {
      retryTimer.cancel();
      _reconnectTimer = null;
      return _singleFlight(_reconnect);
    }

    return _singleFlight(_openSocket);
  }

  /// Runs [attempt] as the one socket attempt in flight, published through
  /// [_inFlight] so every other [connect] and the reconnect timer join it.
  ///
  /// [_inFlight] is cleared before the returned future completes, so a
  /// caller reacting to the outcome with another [connect] starts a fresh
  /// attempt instead of joining the finished one.
  Future<void> _singleFlight(Future<void> Function() attempt) {
    final completer = Completer<void>();
    final flight = completer.future;
    _inFlight = flight;

    attempt().then(
      (_) {
        if (identical(_inFlight, flight)) _inFlight = null;
        completer.complete();
      },
      onError: (Object error, StackTrace stackTrace) {
        if (identical(_inFlight, flight)) _inFlight = null;
        completer.completeError(error, stackTrace);
      },
    );

    return flight;
  }

  /// Opens a fresh socket and waits for the Pusher handshake.
  ///
  /// The only place a socket is created. Both [connect] and the reconnect
  /// timer reach it through [_singleFlight], which is what bounds the driver
  /// to one socket. A previous socket was already released by [_dropSocket]
  /// when it was lost, so nothing here waits on an old socket's close. Every
  /// failure seen here or by the handshake arms exactly one retry. Returns
  /// without opening anything when [disconnect] runs while this is suspended.
  Future<void> _openSocket() async {
    final epoch = _epoch;
    _connectionStateController.add(BroadcastConnectionState.connecting);

    final host = _config['host'] as String;
    final port = _config['port'] as int;
    final scheme = _config['scheme'] as String;
    final appKey = _config['app_key'] as String;

    final uri = Uri.parse(
      '$scheme://$host:$port/app/$appKey'
      '?protocol=7&client=dart&version=1.0.0',
    );

    final channel = _channelFactory(uri);
    final generation = ++_generation;
    _channel = channel;
    try {
      await channel.ready;
    } catch (_) {
      // A refused socket (the server is down) fails here, before any
      // handshake, which is the one failure the timeout below never sees.
      // Without a retry the driver stayed disconnected for good, even once
      // the server was back. Arm one, as the timeout path does, unless a
      // disconnect() ended the loop while this was suspended.
      //
      // The dead socket is dropped here and its close is not awaited: a
      // browser socket that never opened never finishes closing, so the next
      // attempt waited on it forever and no retry ever opened a socket
      // (measured in a host app's web walk).
      if (identical(_channel, channel)) _channel = null;
      channel.sink.close().ignore();
      if (epoch == _epoch) _scheduleReconnect();
      rethrow;
    }
    // disconnect() already closed this socket; a later connect() may own
    // `_channel` by now, so leave every field alone.
    if (epoch != _epoch) return;

    final completer = _connectionCompleter = Completer<void>();

    // Wrap the single-subscription stream as a broadcast stream. The
    // callbacks check the generation: a socket that was already dropped
    // must not tear down, or reconnect over, the socket that replaced it.
    final controller = _broadcastStreamController =
        StreamController<dynamic>.broadcast();
    _streamSubscription = channel.stream.listen(
      controller.add,
      onDone: () {
        controller.close();
        if (generation == _generation) _onDone(channel.closeCode);
      },
      onError: (Object error) {
        controller.addError(error);
        if (generation == _generation) _onError(error);
      },
    );

    controller.stream.listen(
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

    final timeout = _config['connection_timeout'] as int? ?? 15;
    return completer.future.timeout(
      Duration(seconds: timeout),
      onTimeout: () {
        _connectionCompleter = null;
        _dropSocket();
        _scheduleReconnect();
        throw TimeoutException(
          'Connection establishment timed out after ${timeout}s',
        );
      },
    );
  }

  @override
  Future<void> disconnect() async {
    // Cancel any attempt still in flight: it sees the new epoch at its next
    // await and stops, and a connect() after this starts fresh instead of
    // joining it.
    _epoch++;
    _inFlight = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _attempt = 0;
    _connectedBefore = false;

    final completer = _connectionCompleter;
    _connectionCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();

    _dropSocket();

    // Dispose all channels.
    for (final channel in _channels.values) {
      channel.dispose();
    }
    _channels.clear();

    _connectionStateController.add(BroadcastConnectionState.disconnected);
  }

  // ---------------------------------------------------------------------------
  // BroadcastDriver — channel operations
  // ---------------------------------------------------------------------------

  @override
  BroadcastChannel channel(String name) {
    return _channels[name] ?? _register(ReverbBroadcastChannel(name));
  }

  @override
  BroadcastChannel private(String name) {
    final prefixed = name.startsWith('private-') ? name : 'private-$name';

    return _channels[prefixed] ?? _register(ReverbBroadcastChannel(prefixed));
  }

  @override
  BroadcastPresenceChannel join(String name) {
    final prefixed = name.startsWith('presence-') ? name : 'presence-$name';

    final existing = _channels[prefixed];
    if (existing != null) return existing as ReverbBroadcastPresenceChannel;

    return _register<ReverbBroadcastPresenceChannel>(
      ReverbBroadcastPresenceChannel(prefixed),
    );
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

  /// Records [channel] and subscribes it now when a socket is up.
  ///
  /// A channel registered while disconnected is only recorded: the next
  /// handshake's replay of [_channels] subscribes it, exactly once.
  T _register<T extends ReverbBroadcastChannel>(T channel) {
    _channels[channel.name] = channel;
    if (_isConnected) unawaited(_subscribe(channel));

    return channel;
  }

  // ---------------------------------------------------------------------------
  // Backoff delay — pure function, exposed for testing
  // ---------------------------------------------------------------------------

  /// Computes the reconnect delay for [attempt] using exponential backoff
  /// with random jitter.
  ///
  /// Formula: `min(500 * 2^attempt, maxReconnectDelay) * (1 + random(0..0.3))`
  /// milliseconds. The jitter (up to 30% of base delay) prevents thundering
  /// herd when many clients reconnect simultaneously after a server restart.
  /// Also paces the retries of a failed private or presence auth.
  Duration backoffDelay(int attempt) {
    final maxDelay = _config['max_reconnect_delay'] as int? ?? 30000;
    var base = 500;
    for (var i = 0; i < attempt && base < maxDelay; i++) {
      base = min(base * 2, maxDelay);
    }
    final jitter = (_random.nextDouble() * base * 0.3).toInt();
    return Duration(milliseconds: base + jitter);
  }

  /// Classifies a Pusher close [code] into a reconnection action, following
  /// the Pusher protocol (pusher-js `getCloseAction`).
  ///
  /// - 4000-4099: [PusherErrorAction.fatal], do not reconnect.
  /// - 4100-4199: [PusherErrorAction.reconnectBackoff], reconnect with backoff.
  /// - 4200-4299: [PusherErrorAction.reconnectImmediate], reconnect at once.
  /// - Other: defaults to [PusherErrorAction.reconnectBackoff].
  PusherErrorAction classifyErrorCode(int code) {
    if (code >= 4000 && code <= 4099) {
      return PusherErrorAction.fatal;
    }
    if (code >= 4200 && code <= 4299) {
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

    _resetActivityTimer();

    switch (event) {
      case 'pusher:connection_established':
        _handleConnectionEstablished(json);
      case 'pusher:ping':
        _sendPong();
      case 'pusher:subscription_succeeded' ||
          'pusher_internal:subscription_succeeded':
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
    // 1. Adopt the socket identity the server assigned.
    final data = jsonDecode(json['data'] as String) as Map<String, dynamic>;
    _socketId = data['socket_id'] as String;
    activityTimeout =
        data['activity_timeout'] as int? ??
        (_config['activity_timeout'] as int? ?? 120);
    _isConnected = true;
    _attempt = 0;

    _resetActivityTimer();

    _connectionStateController.add(BroadcastConnectionState.connected);

    // 2. Resubscribe every registered channel with the new socket id,
    // whichever path opened this socket. The server forgot every
    // subscription with the old socket, so a replay tied to one path only
    // left the others connected and deaf.
    final generation = _generation;
    final isReconnect = _connectedBefore;
    _connectedBefore = true;
    final replay = _replay = _resubscribeAll();

    final completer = _connectionCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();

    // 3. Announce a reconnect only once the replay ran, so a consumer that
    // refetches on it never races the subscriptions it depends on.
    if (!isReconnect) return;
    replay.then((_) {
      if (generation == _generation) _onReconnectController.add(null);
    });
  }

  void _handleSubscriptionSucceeded(Map<String, dynamic> json) {
    final channelName = json['channel'] as String?;
    if (channelName == null) return;

    final ch = _channels[channelName];
    if (ch == null) return;

    ch.setSubscribed(true);
    if (ch is! ReverbBroadcastPresenceChannel) return;

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

  /// Routes a `pusher:error` frame through the interceptors, and nothing
  /// more.
  ///
  /// The frame never schedules a reconnect: Reverb sends one (code 4200) for
  /// any exception it hits while handling a message, without closing the
  /// socket, so reconnecting on it tore down a healthy connection, and on an
  /// immediate code did so in a loop. When the server does mean to end the
  /// connection it closes the socket, and the close code decides in
  /// [_onDone].
  void _handlePusherError(Map<String, dynamic> json) {
    dynamic error = StateError('Pusher error: ${json['data']}');
    for (final interceptor in _interceptors) {
      error = interceptor.onError(error);
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
  // Subscription helpers
  // ---------------------------------------------------------------------------

  /// Subscribes every registered channel on the current socket and completes
  /// once each has been sent its subscribe, or its first auth attempt failed.
  ///
  /// The channel list is read before the first await, so a channel registered
  /// after this starts subscribes itself through [_register] and is never
  /// sent twice.
  Future<void> _resubscribeAll() async {
    await Future.wait<void>([
      for (final channel in _channels.values.toList()) _subscribe(channel),
    ]);
  }

  /// Sends the subscribe for [channel] on the current socket, authorising a
  /// private or presence channel first. Never throws: an auth failure is
  /// logged and routed through the interceptors.
  Future<void> _subscribe(ReverbBroadcastChannel channel) async {
    final name = channel.name;
    if (name.startsWith('private-') || name.startsWith('presence-')) {
      return _authenticateAndSubscribe(channel);
    }

    _send({
      'event': 'pusher:subscribe',
      'data': <String, dynamic>{'channel': name},
    });
  }

  /// Authorises [channel] for the current socket id via [_authFactory], then
  /// sends its `pusher:subscribe` with the signature.
  ///
  /// The answer is dropped when the socket changed or the channel was left
  /// while the call was out: the signature covers the old socket id (Reverb
  /// refuses it with 4009), and a left channel must not be re-joined. A
  /// retryable [BroadcastAuthException] (no response, a 5xx) is retried with
  /// [backoffDelay] for as long as the socket lasts; 401, 403 and any other
  /// failure are logged and left.
  Future<void> _authenticateAndSubscribe(
    ReverbBroadcastChannel channel, {
    int attempt = 0,
  }) async {
    final generation = _generation;
    final authEndpoint =
        _config['auth_endpoint'] as String? ?? '/broadcasting/auth';

    final Map<String, dynamic> authData;
    try {
      authData = await _authFactory(authEndpoint, <String, dynamic>{
        'socket_id': _socketId,
        'channel_name': channel.name,
      });
    } catch (error) {
      if (!_isCurrent(channel, generation)) return;

      Log.error('Broadcasting auth failed for channel: ${channel.name}', error);
      dynamic processed = error;
      for (final interceptor in _interceptors) {
        processed = interceptor.onError(processed);
      }

      if (error is BroadcastAuthException && error.isRetryable) {
        _retryAuth(channel, generation, attempt);
      }
      return;
    }

    if (!_isCurrent(channel, generation)) return;

    if (authData['auth'] == null) {
      Log.warning(
        'Broadcasting auth response malformed for channel: ${channel.name}',
      );
      return;
    }

    final subscribeData = <String, dynamic>{
      'channel': channel.name,
      'auth': authData['auth'],
    };

    // Presence channels include channel_data.
    if (authData.containsKey('channel_data')) {
      subscribeData['channel_data'] = authData['channel_data'];
    }

    _send({'event': 'pusher:subscribe', 'data': subscribeData});
  }

  /// Retries [channel]'s auth after the backoff for [attempt], unless the
  /// socket it was for is gone (the next handshake replays it) or the channel
  /// was left.
  void _retryAuth(ReverbBroadcastChannel channel, int generation, int attempt) {
    Timer(backoffDelay(attempt), () {
      if (!_isCurrent(channel, generation)) return;

      unawaited(_authenticateAndSubscribe(channel, attempt: attempt + 1));
    });
  }

  /// Whether work started for [channel] on socket [generation] still applies:
  /// the socket is the same one and the channel is still the one registered
  /// under its name.
  bool _isCurrent(ReverbBroadcastChannel channel, int generation) =>
      generation == _generation && identical(_channels[channel.name], channel);

  // ---------------------------------------------------------------------------
  // Reconnection
  // ---------------------------------------------------------------------------

  void _onDone(int? closeCode) {
    _handleDrop(
      closeCode: closeCode,
      handshakeError: StateError(
        'WebSocket closed before connection established',
      ),
    );
  }

  void _onError(Object error) {
    // Route through interceptor chain.
    dynamic processed = error;
    for (final interceptor in _interceptors) {
      processed = interceptor.onError(processed);
    }

    _handleDrop(handshakeError: error);
  }

  /// Handles the loss of the current socket, before or after its handshake.
  ///
  /// [closeCode] is the WebSocket close code the server sent, `null` when the
  /// connection went away without one (a Reverb restart sends no close
  /// frame), which reconnects with backoff as pusher-js does.
  /// [handshakeError] fails a [connect] still waiting on the handshake.
  void _handleDrop({int? closeCode, required Object handshakeError}) {
    // 1. Fail a pending handshake and retire the socket.
    final wasConnected = _isConnected;
    final completer = _connectionCompleter;
    _connectionCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(handshakeError);
    }
    _dropSocket();

    // 2. Let the close code decide whether and how soon to come back.
    final action = closeCode == null
        ? PusherErrorAction.reconnectBackoff
        : classifyErrorCode(closeCode);
    final willRetry =
        (_config['reconnect'] as bool? ?? true) &&
        action != PusherErrorAction.fatal;

    // 3. Report the drop as reconnecting only when a retry is really armed.
    if (wasConnected) {
      _connectionStateController.add(
        willRetry
            ? BroadcastConnectionState.reconnecting
            : BroadcastConnectionState.disconnected,
      );
    }
    if (willRetry) {
      _scheduleReconnect(
        immediate: action == PusherErrorAction.reconnectImmediate,
      );
    }
  }

  /// Arms the one retry for a failure. Callers arm once per failure, so the
  /// backoff attempt counts failures, not code paths.
  void _scheduleReconnect({bool immediate = false}) {
    final shouldReconnect = _config['reconnect'] as bool? ?? true;
    if (!shouldReconnect) return;

    _reconnectTimer?.cancel();

    final delay = immediate ? Duration.zero : backoffDelay(_attempt);
    _attempt++;

    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;

      // An attempt already in flight (a public connect()) owns the socket,
      // and arms its own retry if it fails; opening another beside it is
      // exactly what the single-flight forbids.
      if (_inFlight != null) return;

      // _reconnect already routed the failure through the interceptors and
      // logged it, and the failure armed the next retry; nobody awaits a
      // timer retry.
      _singleFlight(_reconnect).ignore();
    });
  }

  /// One reconnect: reopens the socket, then waits for the handshake's
  /// resubscription of every channel, which also emits [onReconnect].
  ///
  /// Run by the reconnect timer and by a [connect] that supersedes it, so a
  /// caller-driven reconnect behaves exactly like a timer-driven one. A
  /// failure is routed through the interceptors and logged before it is
  /// rethrown to whoever started the attempt; the failure itself already
  /// armed the next retry.
  Future<void> _reconnect() async {
    final epoch = _epoch;
    try {
      await _openSocket();
      if (epoch != _epoch) return;

      await _replay;
    } catch (error) {
      // Route through interceptor chain.
      dynamic processed = error;
      for (final interceptor in _interceptors) {
        processed = interceptor.onError(processed);
      }
      Log.error('Reconnect failed', error);
      rethrow;
    }
  }

  /// Retires the current socket at once, without waiting for its close.
  ///
  /// The generation moves on first, so the socket's own late close or error,
  /// an auth call still out for it, and an auth retry armed for it all find
  /// themselves stale. The close is not awaited: a socket to a dead peer, or
  /// a browser socket that never opened, may never finish closing.
  void _dropSocket() {
    _generation++;
    _cancelActivityTimers();

    _streamSubscription?.cancel();
    _streamSubscription = null;
    _broadcastStreamController?.close();
    _broadcastStreamController = null;

    _channel?.sink.close().ignore();
    _channel = null;

    _isConnected = false;
    _socketId = null;
    _replay = null;

    for (final channel in _channels.values) {
      channel.setSubscribed(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Activity monitor helpers
  // ---------------------------------------------------------------------------

  void _resetActivityTimer() {
    _activityTimer?.cancel();
    _pongTimer?.cancel();
    _pongTimer = null;
    _activityTimer = Timer(Duration(seconds: activityTimeout), () {
      _send({'event': 'pusher:ping', 'data': <String, dynamic>{}});
      // A dead peer delivers no close either, so closing the sink alone left
      // the driver "connected" with no retry. Drop it as a code-less close.
      _pongTimer = Timer(pongTimeout, () {
        _handleDrop(handshakeError: StateError('Pong not received'));
      });
    });
  }

  void _cancelActivityTimers() {
    _activityTimer?.cancel();
    _activityTimer = null;
    _pongTimer?.cancel();
    _pongTimer = null;
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

  final StreamController<bool> _subscriptionController =
      StreamController<bool>.broadcast();

  final Map<String, StreamSubscription<BroadcastEvent>> _listeners =
      <String, StreamSubscription<BroadcastEvent>>{};

  bool _isSubscribed = false;

  @override
  Stream<BroadcastEvent> get events => _controller.stream;

  @override
  bool get isSubscribed => _isSubscribed;

  @override
  Stream<bool> get onSubscriptionChanged => _subscriptionController.stream;

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

  /// Records whether the server has confirmed this channel (internal, called
  /// by driver), emitting on [onSubscriptionChanged] only on a change.
  void setSubscribed(bool subscribed) {
    if (_isSubscribed == subscribed) return;

    _isSubscribed = subscribed;
    if (!_subscriptionController.isClosed) {
      _subscriptionController.add(subscribed);
    }
  }

  /// Disposes this channel, cancelling all listeners and closing the stream.
  ///
  /// Reports the channel unsubscribed first, so a listener on
  /// [onSubscriptionChanged] learns of a leave.
  void dispose() {
    setSubscribed(false);
    for (final sub in _listeners.values) {
      sub.cancel();
    }
    _listeners.clear();
    _controller.close();
    _subscriptionController.close();
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
