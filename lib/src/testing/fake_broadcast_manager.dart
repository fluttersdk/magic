import '../broadcasting/broadcast_connection_state.dart';
import '../broadcasting/broadcast_event.dart';
import '../broadcasting/broadcast_manager.dart';
import '../broadcasting/contracts/broadcast_channel.dart';
import '../broadcasting/contracts/broadcast_driver.dart';
import '../broadcasting/contracts/broadcast_interceptor.dart';
import '../broadcasting/contracts/broadcast_presence_channel.dart';

/// A fake [BroadcastManager] for testing.
///
/// Routes all broadcasting operations through an in-memory fake driver instead
/// of a real WebSocket connection. Provides assertion helpers for verifying
/// expected broadcasting activity.
///
/// ```dart
/// final fake = Echo.fake();
///
/// Echo.channel('orders');
///
/// fake.assertSubscribed('orders');
/// fake.assertConnected();
/// ```
class FakeBroadcastManager extends BroadcastManager {
  final FakeBroadcastDriver _driver = FakeBroadcastDriver();

  /// The underlying fake driver, exposed for direct inspection in tests.
  FakeBroadcastDriver get driver => _driver;

  @override
  BroadcastDriver connection([String? name]) => _driver;

  // ---------------------------------------------------------------------------
  // Assertions
  // ---------------------------------------------------------------------------

  /// Assert that the fake driver is currently connected.
  ///
  /// Throws [AssertionError] if the driver is not connected.
  void assertConnected() {
    if (!_driver._connected) {
      throw AssertionError(
        'Expected the broadcast driver to be connected but it was disconnected.',
      );
    }
  }

  /// Assert that the fake driver is currently disconnected.
  ///
  /// Throws [AssertionError] if the driver is connected.
  void assertDisconnected() {
    if (_driver._connected) {
      throw AssertionError(
        'Expected the broadcast driver to be disconnected but it was connected.',
      );
    }
  }

  /// Assert that [channel] is currently in the subscribed channels list.
  ///
  /// Throws [AssertionError] if [channel] was not subscribed.
  void assertSubscribed(String channel) {
    if (!_driver._subscribedChannels.contains(channel)) {
      throw AssertionError(
        'Expected channel "$channel" to be subscribed but it was not found. '
        'Subscribed channels: ${_driver._subscribedChannels}',
      );
    }
  }

  /// Assert that [channel] is NOT in the subscribed channels list.
  ///
  /// Throws [AssertionError] if [channel] is currently subscribed.
  void assertNotSubscribed(String channel) {
    if (_driver._subscribedChannels.contains(channel)) {
      throw AssertionError(
        'Expected channel "$channel" to not be subscribed but it was found.',
      );
    }
  }

  /// Assert that at least one interceptor has been added to the driver.
  ///
  /// Throws [AssertionError] if no interceptors have been added.
  void assertInterceptorAdded() {
    if (_driver._addedInterceptors.isEmpty) {
      throw AssertionError(
        'Expected at least one interceptor to have been added but none were recorded.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Reset
  // ---------------------------------------------------------------------------

  /// Clear all recorded state on the fake driver.
  void reset() => _driver._reset();
}

// ---------------------------------------------------------------------------
// Fake driver — records operations, no real connection
// ---------------------------------------------------------------------------

/// An in-memory [BroadcastDriver] that records all operations for assertions.
///
/// Accessed via [FakeBroadcastManager.driver] in tests.
class FakeBroadcastDriver implements BroadcastDriver {
  bool _connected = false;
  final List<String> _subscribedChannels = [];
  final List<BroadcastInterceptor> _addedInterceptors = [];

  /// Whether the driver is currently connected.
  @override
  bool get isConnected => _connected;

  /// The list of channel names currently recorded as subscribed.
  List<String> get subscribedChannels => List.unmodifiable(_subscribedChannels);

  /// The list of interceptors that have been added.
  List<BroadcastInterceptor> get addedInterceptors =>
      List.unmodifiable(_addedInterceptors);

  @override
  Future<void> connect() async => _connected = true;

  @override
  Future<void> disconnect() async => _connected = false;

  @override
  String? get socketId => _connected ? 'fake-socket-id' : null;

  @override
  Stream<BroadcastConnectionState> get connectionState => const Stream.empty();

  @override
  Stream<void> get onReconnect => const Stream.empty();

  @override
  BroadcastChannel channel(String name) {
    _subscribedChannels.add(name);
    return _FakeBroadcastChannel(name);
  }

  @override
  BroadcastChannel private(String name) {
    _subscribedChannels.add('private-$name');
    return _FakeBroadcastChannel('private-$name');
  }

  @override
  BroadcastPresenceChannel join(String name) {
    _subscribedChannels.add('presence-$name');
    return _FakeBroadcastPresenceChannel('presence-$name');
  }

  @override
  void leave(String name) => _subscribedChannels.remove(name);

  @override
  void addInterceptor(BroadcastInterceptor interceptor) =>
      _addedInterceptors.add(interceptor);

  void _reset() {
    _connected = false;
    _subscribedChannels.clear();
    _addedInterceptors.clear();
  }
}

// ---------------------------------------------------------------------------
// Internal fake channel — stub with empty events stream
// ---------------------------------------------------------------------------

class _FakeBroadcastChannel implements BroadcastChannel {
  _FakeBroadcastChannel(this._name);

  final String _name;

  @override
  String get name => _name;

  @override
  Stream<BroadcastEvent> get events => const Stream.empty();

  @override
  BroadcastChannel listen(
    String event,
    void Function(BroadcastEvent) callback,
  ) => this;

  @override
  void stopListening(String event) {}
}

// ---------------------------------------------------------------------------
// Internal fake presence channel — empty members and streams
// ---------------------------------------------------------------------------

class _FakeBroadcastPresenceChannel extends _FakeBroadcastChannel
    implements BroadcastPresenceChannel {
  _FakeBroadcastPresenceChannel(super.name);

  @override
  List<Map<String, dynamic>> get members => const [];

  @override
  Stream<Map<String, dynamic>> get onJoin => const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onLeave => const Stream.empty();
}
