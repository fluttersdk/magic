import '../broadcasting/broadcast_connection_state.dart';
import '../broadcasting/broadcast_event.dart';
import '../broadcasting/broadcast_manager.dart';
import '../broadcasting/contracts/broadcast_channel.dart';
import '../broadcasting/contracts/broadcast_driver.dart';
import '../broadcasting/contracts/broadcast_interceptor.dart';
import '../broadcasting/contracts/broadcast_presence_channel.dart';
import '../foundation/magic.dart';
import '../testing/fake_broadcast_manager.dart';

/// The Echo Facade.
///
/// Provides static access to the broadcasting system, proxying all calls to
/// the bound [BroadcastManager]. Modeled after the Laravel Echo API.
///
/// ```dart
/// // Subscribe to a public channel
/// Echo.channel('orders').listen('OrderShipped', (event) {
///   print('Order shipped: ${event.data}');
/// });
///
/// // Subscribe to a private channel
/// Echo.private('user.1').listen('ProfileUpdated', (event) {
///   print('Profile updated: ${event.data}');
/// });
///
/// // Join a presence channel
/// final presence = Echo.join('room.1');
/// presence.onJoin.listen((member) => print('${member['name']} joined'));
/// ```
class Echo {
  Echo._();

  static BroadcastManager get _manager =>
      Magic.make<BroadcastManager>('broadcasting');

  // ---------------------------------------------------------------------------
  // Channel subscriptions
  // ---------------------------------------------------------------------------

  /// Returns a public [BroadcastChannel] for [name].
  ///
  /// Subscribes to the channel on the underlying driver. Subsequent calls for
  /// the same [name] return the cached instance from the driver.
  ///
  /// ```dart
  /// Echo.channel('orders').listen('OrderShipped', (e) => print(e.data));
  /// ```
  static BroadcastChannel channel(String name) =>
      _manager.connection().channel(name);

  /// Returns a private [BroadcastChannel] for [name].
  ///
  /// The driver handles the `private-` prefix and auth handshake as required
  /// by the server configuration.
  ///
  /// ```dart
  /// Echo.private('user.1').listen('ProfileUpdated', (e) => print(e.data));
  /// ```
  static BroadcastChannel private(String name) =>
      _manager.connection().private(name);

  /// Joins a presence channel for [name] and returns it.
  ///
  /// The driver handles the `presence-` prefix, auth handshake, and member
  /// list tracking.
  ///
  /// ```dart
  /// final ch = Echo.join('room.1');
  /// ch.onJoin.listen((m) => print('${m['name']} joined'));
  /// ```
  static BroadcastPresenceChannel join(String name) =>
      _manager.connection().join(name);

  /// Listens for [event] on [channelName], invoking [callback] on each receipt.
  ///
  /// Convenience shorthand for `Echo.channel(name).listen(event, callback)`.
  /// Returns the underlying [BroadcastChannel] for fluent chaining.
  ///
  /// ```dart
  /// Echo.listen('orders', 'OrderShipped', (e) => print(e.data));
  /// ```
  static BroadcastChannel listen(
    String channelName,
    String event,
    void Function(BroadcastEvent) callback,
  ) => _manager.connection().channel(channelName).listen(event, callback);

  /// Unsubscribes from the channel identified by [name].
  ///
  /// Has no effect if the channel was not previously subscribed.
  ///
  /// ```dart
  /// Echo.leave('orders');
  /// ```
  static void leave(String name) => _manager.connection().leave(name);

  // ---------------------------------------------------------------------------
  // Connection lifecycle
  // ---------------------------------------------------------------------------

  /// Establishes the connection to the broadcast server.
  ///
  /// Resolves once the connection is ready. Throws on unrecoverable failure.
  ///
  /// ```dart
  /// await Echo.connect();
  /// ```
  static Future<void> connect() => _manager.connection().connect();

  /// Closes the connection and releases all resources.
  ///
  /// ```dart
  /// await Echo.disconnect();
  /// ```
  static Future<void> disconnect() => _manager.connection().disconnect();

  // ---------------------------------------------------------------------------
  // Driver / connection accessors
  // ---------------------------------------------------------------------------

  /// Returns the default [BroadcastDriver] resolved by the manager.
  ///
  /// Use this when you need direct access to driver-level capabilities not
  /// exposed by the facade.
  static BroadcastDriver get connection => _manager.connection();

  /// The socket identifier assigned by the server, or `null` when not connected.
  ///
  /// Required for server-side auth endpoints that validate channel subscriptions.
  static String? get socketId => _manager.connection().socketId;

  /// A broadcast stream of [BroadcastConnectionState] transitions.
  ///
  /// Emits the new state each time the connection lifecycle changes.
  static Stream<BroadcastConnectionState> get connectionState =>
      _manager.connection().connectionState;

  /// A stream that emits once each time the driver successfully reconnects.
  ///
  /// Useful for re-subscribing to channels after a connection drop.
  static Stream<void> get onReconnect => _manager.connection().onReconnect;

  // ---------------------------------------------------------------------------
  // Interceptors
  // ---------------------------------------------------------------------------

  /// Registers an [interceptor] to be applied to all messages on the connection.
  ///
  /// Interceptors are invoked in the order they are added.
  ///
  /// ```dart
  /// Echo.addInterceptor(LoggingBroadcastInterceptor());
  /// ```
  static void addInterceptor(BroadcastInterceptor interceptor) =>
      _manager.connection().addInterceptor(interceptor);

  // ---------------------------------------------------------------------------
  // Manager access
  // ---------------------------------------------------------------------------

  /// Returns the underlying [BroadcastManager].
  ///
  /// Use for advanced configuration such as registering custom drivers via
  /// [BroadcastManager.extend].
  static BroadcastManager get manager => _manager;

  // ---------------------------------------------------------------------------
  // Testing
  // ---------------------------------------------------------------------------

  /// Replace the bound [BroadcastManager] with a [FakeBroadcastManager] for testing.
  ///
  /// Returns the [FakeBroadcastManager] so callers can make assertions.
  ///
  /// ```dart
  /// final fake = Echo.fake();
  ///
  /// Echo.channel('orders');
  ///
  /// fake.assertSubscribed('orders');
  /// ```
  static FakeBroadcastManager fake() {
    final manager = FakeBroadcastManager();
    Magic.app.setInstance('broadcasting', manager);
    return manager;
  }

  /// Restore the real [BroadcastManager] binding, removing the fake.
  ///
  /// ```dart
  /// Echo.unfake();
  /// ```
  static void unfake() => Magic.app.removeInstance('broadcasting');
}
