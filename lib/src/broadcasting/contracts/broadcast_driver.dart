import '../broadcast_connection_state.dart';
import 'broadcast_channel.dart';
import 'broadcast_interceptor.dart';
import 'broadcast_presence_channel.dart';

/// The Broadcast Driver contract.
///
/// All transport implementations (Pusher, Ably, Soketi, etc.) must implement
/// this interface. The driver owns the underlying connection lifecycle and
/// vends typed channel objects to consumers.
///
/// ```dart
/// await Broadcast.driver().connect();
/// final channel = Broadcast.driver().channel('orders');
/// channel.listen('OrderShipped', (event) => print(event.data));
/// ```
abstract class BroadcastDriver {
  /// Establishes the connection to the broadcast server.
  ///
  /// Resolves once the connection is ready. Throws on unrecoverable failure.
  Future<void> connect();

  /// Closes the connection and releases all resources.
  ///
  /// After calling [disconnect] the driver should transition to
  /// [BroadcastConnectionState.disconnected].
  Future<void> disconnect();

  /// The socket identifier assigned by the server, or `null` when not connected.
  ///
  /// Required for server-side auth endpoints that validate channel subscriptions.
  String? get socketId;

  /// Whether the driver currently has an active connection.
  bool get isConnected;

  /// A broadcast stream of [BroadcastConnectionState] transitions.
  ///
  /// Emits the new state each time the connection lifecycle changes.
  Stream<BroadcastConnectionState> get connectionState;

  /// A stream that emits once each time the driver successfully reconnects.
  ///
  /// Useful for re-subscribing to channels after a connection drop.
  Stream<void> get onReconnect;

  /// Returns a public [BroadcastChannel] for [name].
  ///
  /// Subscribes to the channel on first call; subsequent calls for the same
  /// [name] should return the cached instance.
  BroadcastChannel channel(String name);

  /// Returns a private [BroadcastChannel] for [name].
  ///
  /// The driver will prefix the name (e.g. `'private-'`) as required by the
  /// server and perform the appropriate auth handshake.
  BroadcastChannel private(String name);

  /// Joins a presence channel for [name] and returns it.
  ///
  /// The driver will prefix the name (e.g. `'presence-'`) and perform the
  /// presence auth handshake to obtain membership data.
  BroadcastPresenceChannel join(String name);

  /// Unsubscribes from the channel identified by [name].
  ///
  /// Has no effect if the channel was not previously subscribed.
  void leave(String name);

  /// Registers an [interceptor] to be applied to all outbound and inbound
  /// messages processed by this driver.
  ///
  /// Interceptors are invoked in the order they are added.
  void addInterceptor(BroadcastInterceptor interceptor);
}
