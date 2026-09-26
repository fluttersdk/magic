import 'package:flutter/foundation.dart' show immutable, visibleForTesting;

import '../facades/echo.dart';
import '../facades/log.dart';
import 'auth_channel_subscription.dart';
import 'broadcast_event.dart';

/// An opaque handle returned by [BroadcastListeners.add], passed to
/// [BroadcastListeners.remove] to unregister exactly that one callback.
///
/// Two tokens for the same alias and event are never equal, even when the
/// callbacks they wrap are identical, since each wraps a freshly boxed
/// [_ListenerEntry] rather than the raw handler.
@immutable
class BroadcastListenerToken {
  const BroadcastListenerToken._(this._alias, this._event, this._entry);

  final String _alias;
  final String _event;
  final _ListenerEntry _entry;
}

/// One handler registered through [BroadcastListeners.add], boxed so its
/// identity survives list removal even when the same closure is registered
/// twice for the same alias and event.
class _ListenerEntry {
  _ListenerEntry(this.handler);

  final void Function(BroadcastEvent) handler;
}

/// The per-alias bookkeeping [BroadcastListeners] keeps: the name resolver
/// and `onReconnect` callback an app declared through
/// [BroadcastListeners.channel], the single [AuthChannelSubscription] that
/// owns the alias's channel, and every callback currently registered per
/// event.
class _AliasChannel {
  _AliasChannel(this.alias);

  /// The alias this bookkeeping belongs to, carried only for log messages.
  final String alias;

  /// Re-read on every [BroadcastListeners.sync]; replaced in place by a later
  /// [BroadcastListeners.channel] call for the same alias.
  String? Function() resolveName = () => null;

  /// Forwarded into [subscription]'s `onReconnect`; replaced in place by a
  /// later [BroadcastListeners.channel] call for the same alias.
  void Function()? onReconnect;

  /// The name [subscription] last resolved, or `null` when the alias
  /// currently has no live channel. [BroadcastListeners.add] and
  /// [BroadcastListeners.remove] read this to decide whether a channel is
  /// already live enough to wire an event onto directly, instead of waiting
  /// for the next [BroadcastListeners.sync].
  String? currentName;

  /// The fan-out functions passed to [subscription]; kept as the SAME map
  /// instance for the alias's lifetime, so an event added after the first
  /// [BroadcastListeners.sync] is still present the next time the channel is
  /// torn down and resubscribed.
  final Map<String, void Function(BroadcastEvent)> subscriptionListeners =
      <String, void Function(BroadcastEvent)>{};

  /// Every callback currently registered per event, in registration order.
  final Map<String, List<_ListenerEntry>> entriesByEvent =
      <String, List<_ListenerEntry>>{};

  /// The one [AuthChannelSubscription] this alias ever owns.
  ///
  /// Built lazily (on first access, typically the first [sync]) so
  /// [resolveName] and [onReconnect] can still be replaced by a later
  /// [BroadcastListeners.channel] call before anything reads them.
  late final AuthChannelSubscription subscription = AuthChannelSubscription(
    channelName: () => currentName = resolveName(),
    listeners: subscriptionListeners,
    onReconnect: () => onReconnect?.call(),
  );
}

/// Livewire's `getListeners()` for magic controllers: a process-wide registry
/// mapping a short alias (`'team'`) to the private channel it currently
/// resolves to, owning exactly one [AuthChannelSubscription] per alias no
/// matter how many controllers listen on it.
///
/// The channel is shared by name (a driver caches one [BroadcastChannel] per
/// fully-qualified name; see `reverb_broadcast_driver.dart`'s `private()`),
/// so two controllers each opening their own subscription to the same alias
/// would silently drop each other's handlers (`listen()` replaces a
/// same-event handler, it does not add one) or tear the channel down the
/// moment only one of them closes. This registry is the seam that keeps it
/// to one subscription: [add] fans a single stable callback per alias+event
/// out to every registered handler, in registration order, isolating one
/// handler's exception from the next with [Log.error].
///
/// ```dart
/// BroadcastListeners.channel(
///   'team',
///   () => currentTeamId == null ? null : 'teams.$currentTeamId',
///   onReconnect: refetchAll,
/// );
/// await BroadcastListeners.sync(); // wired to an auth state notifier
/// ```
///
/// A `null` name on one alias tears down the whole default `Echo` connection
/// ([AuthChannelSubscription]'s own contract, unchanged here), so an app
/// declaring several aliases must resolve them together: the connection is
/// shared, not per-alias.
class BroadcastListeners {
  BroadcastListeners._();

  static final Map<String, _AliasChannel> _aliases = <String, _AliasChannel>{};

  // ---------------------------------------------------------------------------
  // Declaration
  // ---------------------------------------------------------------------------

  /// Declares (or redeclares) the channel [alias] resolves to.
  ///
  /// [name] is re-read on every [sync]; a `null` result tears the alias's
  /// channel down. [onReconnect], when given, fires after the alias's
  /// [AuthChannelSubscription] observes a reconnect, so a caller can refetch
  /// whatever the socket missed while it was down.
  ///
  /// Safe to call again for an already-declared [alias]: [name] and
  /// [onReconnect] are replaced in place, and the existing subscription plus
  /// every listener already registered on it are kept.
  static void channel(
    String alias,
    String? Function() name, {
    void Function()? onReconnect,
  }) {
    final _AliasChannel channel = _aliases.putIfAbsent(
      alias,
      () => _AliasChannel(alias),
    );
    channel.resolveName = name;
    channel.onReconnect = onReconnect;
  }

  // ---------------------------------------------------------------------------
  // Listener registration
  // ---------------------------------------------------------------------------

  /// Registers [handler] for [event] on [alias], returning a token [remove]
  /// later unregisters.
  ///
  /// [alias] must already be declared through [channel]. An [event] with no
  /// existing listener on this alias gets a stable fan-out function, wired
  /// directly onto the live channel (`Echo.private(name).listen`) when the
  /// alias is already subscribed: [sync] returns early once a channel's name
  /// has not changed, so it would never notice this new event on its own. An
  /// [event] that already has a listener only appends [handler] to the
  /// fan-out's callback list; the channel is untouched.
  static BroadcastListenerToken add(
    String alias,
    String event,
    void Function(BroadcastEvent) handler,
  ) {
    final _AliasChannel channel = _requireAlias(alias);
    final _ListenerEntry entry = _ListenerEntry(handler);
    final List<_ListenerEntry> entries = channel.entriesByEvent.putIfAbsent(
      event,
      () => <_ListenerEntry>[],
    );
    final bool isNewEvent = entries.isEmpty;
    entries.add(entry);

    if (isNewEvent) {
      final void Function(BroadcastEvent) fanOut = _fanOutFor(channel, event);
      channel.subscriptionListeners[event] = fanOut;

      final String? currentName = channel.currentName;
      if (currentName != null) {
        Echo.private(currentName).listen(event, fanOut);
      }
    }

    return BroadcastListenerToken._(alias, event, entry);
  }

  /// Unregisters the callback [token] refers to.
  ///
  /// A no-op when the alias or event was already torn down (e.g. a
  /// controller closing twice). Once the last callback for an event is
  /// removed, the event is dropped from the alias's fan-out map and, when the
  /// alias currently has a live channel, unregistered from it so nothing is
  /// left listening for an event no controller cares about any more.
  static void remove(BroadcastListenerToken token) {
    final _AliasChannel? channel = _aliases[token._alias];
    if (channel == null) return;

    final List<_ListenerEntry>? entries = channel.entriesByEvent[token._event];
    if (entries == null || !entries.remove(token._entry)) return;
    if (entries.isNotEmpty) return;

    channel.entriesByEvent.remove(token._event);
    channel.subscriptionListeners.remove(token._event);

    final String? currentName = channel.currentName;
    if (currentName != null) {
      Echo.private(currentName).stopListening(token._event);
    }
  }

  // ---------------------------------------------------------------------------
  // Sync
  // ---------------------------------------------------------------------------

  /// Reconciles every declared alias's subscription against its current
  /// resolved name.
  ///
  /// Safe to call on every auth-state change: each alias's own
  /// [AuthChannelSubscription.sync] is a no-op when its name has not moved.
  static Future<void> sync() async {
    for (final _AliasChannel channel in _aliases.values) {
      await channel.subscription.sync();
    }
  }

  // ---------------------------------------------------------------------------
  // Fan-out
  // ---------------------------------------------------------------------------

  /// Builds the stable fan-out callback for [channel]'s [event].
  ///
  /// Reads [_AliasChannel.entriesByEvent] fresh on every dispatch (rather
  /// than closing over a snapshot) so a callback removed since the fan-out
  /// was built is never invoked, and copies the list before iterating so a
  /// handler that removes another during the same dispatch cannot invalidate
  /// the iteration.
  static void Function(BroadcastEvent) _fanOutFor(
    _AliasChannel channel,
    String event,
  ) {
    return (BroadcastEvent broadcastEvent) {
      final List<_ListenerEntry> entries = List<_ListenerEntry>.from(
        channel.entriesByEvent[event] ?? const <_ListenerEntry>[],
      );
      for (final _ListenerEntry entry in entries) {
        try {
          entry.handler(broadcastEvent);
        } catch (error, stackTrace) {
          // One controller's handler must never take another's down with it:
          // the channel is shared, so an uncaught throw here would escape
          // into the driver's own dispatch and stop every later handler for
          // this event from running.
          Log.error(
            '[BroadcastListeners] listener for "$event" on "${channel.alias}" '
            'failed: $error\n$stackTrace',
          );
        }
      }
    };
  }

  static _AliasChannel _requireAlias(String alias) {
    final _AliasChannel? channel = _aliases[alias];
    if (channel == null) {
      throw StateError(
        'BroadcastListeners.add: alias "$alias" was never declared. '
        'Call BroadcastListeners.channel("$alias", ...) first.',
      );
    }
    return channel;
  }

  // ---------------------------------------------------------------------------
  // Testing
  // ---------------------------------------------------------------------------

  /// Exposes the [AuthChannelSubscription] backing [alias], for a test that
  /// needs to prove `onReconnect` forwarding directly.
  ///
  /// `Echo.fake()`'s driver cannot emit a synthetic reconnect (its
  /// `onReconnect` and `connectionState` streams are both `Stream.empty()`),
  /// so the only way to exercise the forwarding wire is to read the
  /// subscription's own `onReconnect` field and call it.
  @visibleForTesting
  static AuthChannelSubscription? subscriptionForTesting(String alias) =>
      _aliases[alias]?.subscription;

  /// Clears every declared alias, disposing its subscription's reconnect
  /// listeners first.
  ///
  /// Test-only: a real app declares its aliases once at bootstrap and never
  /// needs to clear them.
  @visibleForTesting
  static void reset() {
    for (final _AliasChannel channel in _aliases.values) {
      channel.subscription.dispose();
    }
    _aliases.clear();
  }
}
