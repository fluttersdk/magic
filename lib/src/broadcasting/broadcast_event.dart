/// An event received from the broadcast server.
///
/// Encapsulates the raw event name, the channel it arrived on, the decoded
/// payload, and the local timestamp at which it was received. Instances are
/// immutable and created by drivers when messages arrive.
class BroadcastEvent {
  /// Creates a [BroadcastEvent].
  ///
  /// All fields are required so that consumers always have full context about
  /// the origin of the event.
  const BroadcastEvent({
    required this.event,
    required this.channel,
    required this.data,
    required this.receivedAt,
  });

  /// The event name as broadcast by the server (e.g. `'App\\Events\\OrderShipped'`).
  final String event;

  /// The channel name the event was received on (e.g. `'orders'`, `'private-inbox.1'`).
  final String channel;

  /// The decoded JSON payload sent with the event.
  final Map<String, dynamic> data;

  /// The local [DateTime] at which this event was received by the driver.
  final DateTime receivedAt;

  @override
  String toString() =>
      'BroadcastEvent(event: $event, channel: $channel, '
      'data: $data, receivedAt: $receivedAt)';
}
