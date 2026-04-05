/// The possible connection states for a broadcast driver.
///
/// Represents the lifecycle of a WebSocket (or equivalent) connection managed
/// by a [BroadcastDriver]. Consumers can react to state transitions by
/// subscribing to [BroadcastDriver.connectionState].
enum BroadcastConnectionState {
  /// The driver is in the process of establishing a connection.
  connecting,

  /// The driver has an active, healthy connection to the broadcast server.
  connected,

  /// The driver is not connected and is not attempting to reconnect.
  disconnected,

  /// The driver lost its connection and is attempting to re-establish it.
  reconnecting,
}
