import '../broadcast_connection_state.dart';
import '../broadcast_event.dart';
import '../contracts/broadcast_channel.dart';
import '../contracts/broadcast_driver.dart';
import '../contracts/broadcast_interceptor.dart';
import '../contracts/broadcast_presence_channel.dart';

/// A no-op [BroadcastDriver] for local development and testing environments
/// where no WebSocket server is available.
///
/// All connection methods resolve immediately without side-effects. Channel
/// methods return silent [_NullBroadcastChannel] instances whose event streams
/// never emit. This allows application code that depends on broadcasting to
/// compile and run without a real server.
///
/// ```dart
/// Magic.init(
///   providers: [BroadcastServiceProvider()],
///   config: {'broadcast': {'default': 'null'}},
/// );
/// ```
class NullBroadcastDriver implements BroadcastDriver {
  @override
  /// Resolves immediately — no connection is established.
  Future<void> connect() => Future<void>.value();

  @override
  /// Resolves immediately — nothing to close.
  Future<void> disconnect() => Future<void>.value();

  @override
  /// Always `null` — no server assigns a socket identifier to a null driver.
  String? get socketId => null;

  @override
  /// Always `false` — the null driver never establishes a real connection.
  bool get isConnected => false;

  @override
  /// Never emits — the null driver has no connection lifecycle transitions.
  Stream<BroadcastConnectionState> get connectionState =>
      const Stream<BroadcastConnectionState>.empty();

  @override
  /// Never emits — the null driver never reconnects.
  Stream<void> get onReconnect => const Stream<void>.empty();

  @override
  /// Returns a [_NullBroadcastChannel] for [name].
  ///
  /// The returned channel accepts listener registrations but never delivers
  /// events.
  BroadcastChannel channel(String name) => _NullBroadcastChannel(name);

  @override
  /// Returns a [_NullBroadcastChannel] for [name].
  ///
  /// Behaves identically to [channel] — no auth handshake is performed.
  BroadcastChannel private(String name) => _NullBroadcastChannel(name);

  @override
  /// Returns a [_NullBroadcastPresenceChannel] for [name] with no members.
  ///
  /// No presence auth handshake is performed.
  BroadcastPresenceChannel join(String name) =>
      _NullBroadcastPresenceChannel(name);

  @override
  /// No-op — the null driver holds no subscriptions to unsubscribe from.
  void leave(String name) {}

  @override
  /// No-op — the null driver processes no messages for interceptors to act on.
  void addInterceptor(BroadcastInterceptor interceptor) {}
}

/// A no-op [BroadcastChannel] whose event streams never emit.
///
/// Listener registrations are accepted without error but never invoked.
/// The [events] stream is a permanent empty broadcast stream — no
/// [StreamController] is allocated, so there is no resource to leak.
class _NullBroadcastChannel implements BroadcastChannel {
  /// Creates a [_NullBroadcastChannel] with the given [name].
  const _NullBroadcastChannel(this.name);

  @override
  final String name;

  @override
  /// A stream that never emits any [BroadcastEvent].
  Stream<BroadcastEvent> get events => const Stream<BroadcastEvent>.empty();

  @override
  /// Registers [callback] for [event] and returns `this` for fluent chaining.
  ///
  /// The callback will never be invoked because this driver receives no events.
  BroadcastChannel listen(
    String event,
    void Function(BroadcastEvent) callback,
  ) => this;

  @override
  /// No-op — no listener was ever registered.
  void stopListening(String event) {}
}

/// A no-op [BroadcastPresenceChannel] with no members and silent streams.
///
/// Extends [_NullBroadcastChannel] and satisfies the [BroadcastPresenceChannel]
/// interface with empty membership data and never-emitting join/leave streams.
class _NullBroadcastPresenceChannel extends _NullBroadcastChannel
    implements BroadcastPresenceChannel {
  /// Creates a [_NullBroadcastPresenceChannel] with the given [name].
  const _NullBroadcastPresenceChannel(super.name);

  @override
  /// Always empty — no members are present when there is no real server.
  List<Map<String, dynamic>> get members => const <Map<String, dynamic>>[];

  @override
  /// Never emits — no members join on a null driver.
  Stream<Map<String, dynamic>> get onJoin =>
      const Stream<Map<String, dynamic>>.empty();

  @override
  /// Never emits — no members leave on a null driver.
  Stream<Map<String, dynamic>> get onLeave =>
      const Stream<Map<String, dynamic>>.empty();
}
