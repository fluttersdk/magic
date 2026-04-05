import '../broadcast_event.dart';

/// The Broadcast Channel contract.
///
/// Represents a public broadcast channel. Consumers subscribe to events by
/// calling [listen] with an event name and a callback. The raw [events] stream
/// emits every event received on this channel regardless of registration.
///
/// ```dart
/// final channel = Broadcast.channel('orders');
/// channel.listen('OrderShipped', (event) {
///   print('Order shipped: ${event.data}');
/// });
/// ```
abstract class BroadcastChannel {
  /// The fully-qualified channel name as sent to the server (e.g. `'orders'`).
  String get name;

  /// A broadcast stream of every [BroadcastEvent] received on this channel.
  ///
  /// The stream is multi-subscription — multiple listeners may be attached
  /// simultaneously without replaying prior events.
  Stream<BroadcastEvent> get events;

  /// Registers a [callback] to be invoked whenever [event] is received.
  ///
  /// Returns `this` to allow fluent chaining:
  /// ```dart
  /// channel
  ///   .listen('OrderShipped', onShipped)
  ///   .listen('OrderCancelled', onCancelled);
  /// ```
  BroadcastChannel listen(String event, void Function(BroadcastEvent) callback);

  /// Removes the listener previously registered for [event].
  ///
  /// Has no effect if no listener was registered for [event].
  void stopListening(String event);
}
