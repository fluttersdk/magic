import 'dart:async';

import '../facades/echo.dart';
import '../facades/log.dart';
import 'broadcast_connection_state.dart';
import 'broadcast_event.dart';
import 'contracts/broadcast_channel.dart';

/// Keeps a single private broadcast channel subscription in sync with a
/// caller-supplied channel name, re-read on every [sync] call.
///
/// This is the seam behind an auth-scoped realtime channel: which channel is
/// currently subscribed, leaving the old one and standing up the replacement
/// when the name changes, and re-firing [onReconnect] after a connection
/// drop so a caller can refetch whatever the socket missed while it was down
/// (Reverb does not replay). Event routing, reload targets, and any
/// coalescing/debounce stay with the caller: this class only ever forwards a
/// raw [BroadcastEvent] to the listener registered for its event name.
///
/// The caller decides when to call [sync], typically wired to an auth state
/// notifier:
///
/// ```dart
/// final subscription = AuthChannelSubscription(
///   channelName: () => currentTeamId == null ? null : 'teams.$currentTeamId',
///   listeners: {'incident.opened': onIncidentEvent},
///   onReconnect: refetchAll,
/// );
/// Auth.stateNotifier.addListener(subscription.sync);
/// ```
///
/// This class does not read `Auth` (or any other auth source) itself: the
/// caller supplies both the current name and the trigger to re-check it.
///
/// One Reverb reconnect can surface as both an `Echo.onReconnect` signal and
/// a `connectionState` transition to `connected`, since the driver announces
/// its own recovery and the connection stream reports the same recovery
/// independently. A single reconnect can therefore call [onReconnect] twice;
/// a caller doing a refetch on it should coalesce (e.g. drop a call already
/// in flight) rather than assume one call per drop.
///
/// A `null` [channelName] tears the subscription down by calling
/// `Echo.disconnect()` on the default connection, which drops every channel
/// the app subscribed elsewhere through `Echo`, not just this one. That is
/// deliberate (a signed-out app has no business staying on the socket) but
/// worth knowing before wiring a second, unrelated `AuthChannelSubscription`
/// or a raw `Echo` channel onto the same connection.
class AuthChannelSubscription {
  /// Creates a subscription reconciler.
  ///
  /// [channelName] is re-invoked on every [sync]; returning `null` means "no
  /// channel right now" and tears down any live subscription. [listeners]
  /// maps an event name to the callback [sync] registers on every
  /// (re)subscribe. [onReconnect], when given, fires after a connection drop
  /// and after an explicit `Echo.onReconnect` signal, so a caller can refetch
  /// whatever a replay-less socket missed while it was down.
  AuthChannelSubscription({
    required this.channelName,
    required this.listeners,
    this.onReconnect,
  });

  /// Re-read on every [sync]; `null` means no channel should be subscribed.
  final String? Function() channelName;

  /// The event handlers registered on the channel on every (re)subscribe.
  final Map<String, void Function(BroadcastEvent)> listeners;

  /// Invoked after a reconnect (either an `Echo.onReconnect` signal or a
  /// `connectionState` transition to `connected`), so a caller can refetch
  /// what the socket missed while it was down.
  final void Function()? onReconnect;

  /// The channel name last reconciled onto, or `null` when not subscribed.
  ///
  /// Compared against a fresh [channelName] call on each [sync] to detect a
  /// change; also doubles as the subscribed marker for [_teardown]'s no-op
  /// guard.
  String? _subscribedName;

  /// The subscribed [BroadcastChannel], retained so it can be left by its own
  /// fully-qualified (prefixed) name.
  BroadcastChannel? _channel;

  /// Whether a [sync] is currently running; serializes overlapping calls.
  bool _syncing = false;

  /// Set when [sync] is called while another is in flight, so the running
  /// call re-runs once more afterwards and settles on the latest
  /// [channelName].
  bool _resyncRequested = false;

  /// The `Echo.onReconnect` subscription, or `null` when not subscribed.
  StreamSubscription<void>? _reconnectSubscription;

  /// The `Echo.connectionState` subscription, or `null` when not subscribed.
  StreamSubscription<BroadcastConnectionState>? _connectionSubscription;

  /// The most recently observed [BroadcastConnectionState], or `null` before
  /// the first one is seen.
  ///
  /// Populated by [_stateTrackingSubscription] independently of
  /// `BroadcastDriver.isConnected`: after a drop, the driver reports
  /// [BroadcastConnectionState.reconnecting] and arms its own reconnect timer
  /// before `isConnected` flips to `false`, so this is what lets [_reconcile]
  /// tell "no connection, and nobody is trying" apart from "no connection,
  /// but a reconnect is already in flight".
  BroadcastConnectionState? _lastConnectionState;

  /// The `Echo.connectionState` subscription backing [_lastConnectionState].
  ///
  /// Started on the first [sync] and kept alive through [_teardown] (a
  /// `null` [channelName] does not cancel it), so a drop observed while the
  /// subscription is torn down is still reflected in [_lastConnectionState]
  /// the next time a channel name reappears. Only [dispose] cancels it.
  StreamSubscription<BroadcastConnectionState>? _stateTrackingSubscription;

  // ---------------------------------------------------------------------------
  // Sync
  // ---------------------------------------------------------------------------

  /// Reconciles the subscription against the current [channelName].
  ///
  /// Serialised: a call arriving while another is in flight defers and runs
  /// once more after the current one finishes, rather than running
  /// concurrently and risking two live subscriptions across the same await
  /// point. Safe to call repeatedly, e.g. wired directly as a `ChangeNotifier`
  /// listener.
  Future<void> sync() async {
    if (_syncing) {
      _resyncRequested = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _resyncRequested = false;
        try {
          await _reconcile();
        } catch (error, stackTrace) {
          // A caller typically wires `sync` straight to a `ChangeNotifier`
          // listener (e.g. `Auth.stateNotifier`), so a rethrow here would
          // escape into the notifier's dispatch rather than the caller's own
          // error handling. Logging keeps the listener alive for the next
          // state change. The catch sits inside the loop, not around it, so
          // a `sync` requested while this pass was failing still gets its
          // one re-run below, the same as a request during a successful pass.
          Log.error(
            '[AuthChannelSubscription] sync failed: $error\n$stackTrace',
          );
        }
      } while (_resyncRequested);
    } finally {
      _syncing = false;
    }
  }

  /// The single-flight body of [sync]; assumes [sync]'s latch serialises it,
  /// so it never runs concurrently with itself.
  Future<void> _reconcile() async {
    _ensureTrackingConnectionState();
    final String? name = channelName();

    // 1. No channel to subscribe to: tear down any live subscription.
    if (name == null) {
      await _teardown();
      return;
    }

    // 2. Already on this channel: nothing to do, whatever the connection is
    //    doing. The marker is only set after a subscribe succeeded, and a drop
    //    after that is the driver's to recover (Reverb reconnects and
    //    re-subscribes on its own). Resubscribing here while the socket is
    //    mid-reconnect would call `Echo.connect()` beside the driver's own
    //    reconnect and open a second socket.
    if (_subscribedName == name) {
      return;
    }

    // 3. The name changed (or first subscribe): leave the old channel and
    //    clear the marker BEFORE the first await, so a failed `Echo.connect()`
    //    leaves a clean state the next sync retries rather than a stale marker
    //    pointing at a channel that is not actually subscribed.
    _leaveCurrentChannel();
    _subscribedName = null;
    // Connect only when there is no live connection AND no connect or
    // reconnect is already in flight: `connect()` is not idempotent in the
    // Reverb driver (a second call opens a second socket and leaks the
    // first). After a drop, the driver reports `reconnecting` and arms its
    // own reconnect Timer before `isConnected` flips to `false`, so a name
    // change in that window must only touch the channel; the driver's own
    // reconnect resubscribes every channel it already knows about (including
    // one created while disconnected) once it reconnects.
    final bool driverReconnectPending =
        _lastConnectionState == BroadcastConnectionState.reconnecting ||
        _lastConnectionState == BroadcastConnectionState.connecting;
    if (!Echo.connection.isConnected && !driverReconnectPending) {
      await Echo.connect();
    }

    final BroadcastChannel channel = Echo.private(name);
    for (final MapEntry<String, void Function(BroadcastEvent)> entry
        in listeners.entries) {
      channel.listen(entry.key, entry.value);
    }
    _channel = channel;
    _subscribedName = name;

    // 4. Wire the connect-time refetch so a reconnect closes the replay gap.
    _listenForReconnect();
  }

  /// Tears down the live subscription, connection, and reconnect listeners.
  ///
  /// Disconnects the whole default connection (`Echo.disconnect()`), not
  /// just this channel: any other channel the app subscribed through `Echo`
  /// on the same connection is dropped too. Deliberate, since a signed-out
  /// app has no business staying on the socket. Does not cancel
  /// [_stateTrackingSubscription], so a drop seen while torn down is still
  /// reflected in [_lastConnectionState] the next time a channel name
  /// reappears.
  ///
  /// A no-op when never subscribed, so a repeated `null` [channelName] stays
  /// idempotent.
  Future<void> _teardown() async {
    if (_subscribedName == null) {
      return;
    }
    _leaveCurrentChannel();
    _cancelReconnectListeners();
    _subscribedName = null;
    await Echo.disconnect();
  }

  /// Leaves the current channel by its fully-qualified (prefixed) name.
  void _leaveCurrentChannel() {
    final BroadcastChannel? channel = _channel;
    if (channel == null) {
      return;
    }
    Echo.leave(channel.name);
    _channel = null;
  }

  // ---------------------------------------------------------------------------
  // Connection-state tracking
  // ---------------------------------------------------------------------------

  /// Starts tracking `Echo.connectionState` into [_lastConnectionState].
  ///
  /// Idempotent: a no-op once [_stateTrackingSubscription] is set. Called at
  /// the top of every [_reconcile] pass so tracking starts on the first
  /// [sync], not just after a successful subscribe.
  void _ensureTrackingConnectionState() {
    if (_stateTrackingSubscription != null) {
      return;
    }
    _stateTrackingSubscription = Echo.connectionState.listen(
      (BroadcastConnectionState state) => _lastConnectionState = state,
    );
  }

  // ---------------------------------------------------------------------------
  // Reconnect refetch
  // ---------------------------------------------------------------------------

  /// Subscribes to both reconnect signals, firing [onReconnect] on each.
  ///
  /// Two signals rather than one: `Echo.onReconnect` covers a driver that
  /// announces its own recovery, and the `connectionState` transition to
  /// `connected` covers the same recovery observed independently, since
  /// Reverb re-subscribes channels on reconnect silently and replays nothing.
  void _listenForReconnect() {
    _cancelReconnectListeners();
    _reconnectSubscription = Echo.onReconnect.listen(
      (_) => onReconnect?.call(),
    );
    _connectionSubscription = Echo.connectionState
        .where(
          (BroadcastConnectionState state) =>
              state == BroadcastConnectionState.connected,
        )
        .listen((_) => onReconnect?.call());
  }

  /// Cancels the reconnect + connection-state subscriptions, if any.
  void _cancelReconnectListeners() {
    _reconnectSubscription?.cancel();
    _reconnectSubscription = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
  }

  // ---------------------------------------------------------------------------
  // Disposal
  // ---------------------------------------------------------------------------

  /// Releases the reconnect stream subscriptions and the connection-state
  /// tracking used to detect a pending driver reconnect.
  ///
  /// Idempotent. Does not touch the channel or connection, which stay live
  /// until the next [sync] resolves a `null` [channelName].
  void dispose() {
    _cancelReconnectListeners();
    _stateTrackingSubscription?.cancel();
    _stateTrackingSubscription = null;
  }
}
