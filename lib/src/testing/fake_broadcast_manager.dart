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

  /// Assert that a handler for [event] is registered on [channel].
  ///
  /// Subscribing to a channel and listening for an event are separate steps, and
  /// [assertSubscribed] only covers the first: an application can hold a live
  /// channel and register no handler at all. This is the assertion that fails
  /// when a `listen()` line is deleted.
  ///
  /// Throws [AssertionError] if no handler is registered.
  void assertListening(String channel, String event) {
    final Map<String, void Function(BroadcastEvent)>? handlers =
        _driver._listeners[channel];

    if (handlers == null || !handlers.containsKey(event)) {
      throw AssertionError(
        'Expected a handler for "$event" on channel "$channel" but none was '
        'registered. Registered: ${_driver.listeners}',
      );
    }
  }

  /// Assert that NO handler for [event] is registered on [channel].
  ///
  /// Throws [AssertionError] if a handler is registered.
  void assertNotListening(String channel, String event) {
    if (_driver._listeners[channel]?.containsKey(event) ?? false) {
      throw AssertionError(
        'Expected no handler for "$event" on channel "$channel" but one was '
        'registered.',
      );
    }
  }

  /// Deliver [data] to the handler registered for [event] on [channel], exactly
  /// as the driver would on an incoming frame.
  ///
  /// This is what turns "a handler exists" into "a handler runs on a frame".
  /// [data] is handed over already decoded, matching [BroadcastEvent.data] on the
  /// real driver, which performs the Pusher double-JSON-decode before a handler
  /// ever sees it.
  ///
  /// Throws [AssertionError] if no handler is registered, because dispatching
  /// into silence is the failure this method exists to make visible.
  void dispatch(String channel, String event, Map<String, dynamic> data) {
    assertListening(channel, event);

    _driver._listeners[channel]![event]!(
      BroadcastEvent(
        event: event,
        channel: channel,
        data: data,
        receivedAt: DateTime.now(),
      ),
    );
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
    return _FakeBroadcastChannel(name, this);
  }

  @override
  BroadcastChannel private(String name) {
    _subscribedChannels.add('private-$name');
    return _FakeBroadcastChannel('private-$name', this);
  }

  @override
  BroadcastPresenceChannel join(String name) {
    _subscribedChannels.add('presence-$name');
    return _FakeBroadcastPresenceChannel('presence-$name', this);
  }

  /// Event handlers registered through [BroadcastChannel.listen], keyed by
  /// channel name and then by event name.
  ///
  /// The driver owns this rather than the channel because the channel factories
  /// above mint a NEW channel object on every call and keep no reference, so a
  /// registration recorded on the channel would vanish the moment the caller let
  /// go of it. That is what made a listener registration untestable.
  final Map<String, Map<String, void Function(BroadcastEvent)>> _listeners = {};

  /// Registered event names per channel, for low-level inspection.
  Map<String, List<String>> get listeners => Map.unmodifiable({
    for (final MapEntry<String, Map<String, void Function(BroadcastEvent)>> e
        in _listeners.entries)
      e.key: List<String>.unmodifiable(e.value.keys),
  });

  void _register(
    String channel,
    String event,
    void Function(BroadcastEvent) callback,
  ) {
    // Last registration wins, matching ReverbBroadcastDriver, which cancels the
    // previous subscription before storing the new one. A fake that appended
    // instead would hide a double-registration bug rather than reproduce it.
    (_listeners[channel] ??= {})[event] = callback;
  }

  void _unregister(String channel, String event) =>
      _listeners[channel]?.remove(event);

  @override
  void leave(String name) => _subscribedChannels.remove(name);

  @override
  void addInterceptor(BroadcastInterceptor interceptor) =>
      _addedInterceptors.add(interceptor);

  void _reset() {
    _connected = false;
    _subscribedChannels.clear();
    _addedInterceptors.clear();
    _listeners.clear();
  }
}

// ---------------------------------------------------------------------------
// Internal fake channel — stub with empty events stream
// ---------------------------------------------------------------------------

class _FakeBroadcastChannel implements BroadcastChannel {
  _FakeBroadcastChannel(this._name, this._driver);

  final String _name;
  final FakeBroadcastDriver _driver;

  @override
  String get name => _name;

  @override
  Stream<BroadcastEvent> get events => const Stream.empty();

  @override
  BroadcastChannel listen(
    String event,
    void Function(BroadcastEvent) callback,
  ) {
    // Recorded rather than discarded, and the difference is what a consumer's
    // test can prove. This used to return `this` and drop both arguments, so a
    // subscription line could be deleted from an application and its whole suite
    // stayed green: the one line every broadcast depends on was the one line
    // nothing covered.
    _driver._register(_name, event, callback);

    return this;
  }

  @override
  void stopListening(String event) => _driver._unregister(_name, event);
}

// ---------------------------------------------------------------------------
// Internal fake presence channel — empty members and streams
// ---------------------------------------------------------------------------

class _FakeBroadcastPresenceChannel extends _FakeBroadcastChannel
    implements BroadcastPresenceChannel {
  _FakeBroadcastPresenceChannel(super.name, super.driver);

  @override
  List<Map<String, dynamic>> get members => const [];

  @override
  Stream<Map<String, dynamic>> get onJoin => const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onLeave => const Stream.empty();
}
