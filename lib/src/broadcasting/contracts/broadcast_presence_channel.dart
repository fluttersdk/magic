import 'broadcast_channel.dart';

/// The Broadcast Presence Channel contract.
///
/// Extends [BroadcastChannel] with membership awareness. Presence channels
/// expose the list of currently-connected members and emit streams when members
/// join or leave, enabling features such as online indicators and typing
/// notifications.
///
/// ```dart
/// final channel = Broadcast.join('presence-room.1');
/// channel.onJoin.listen((member) => print('${member['name']} joined'));
/// channel.onLeave.listen((member) => print('${member['name']} left'));
/// ```
abstract class BroadcastPresenceChannel extends BroadcastChannel {
  /// The current list of members connected to this presence channel.
  ///
  /// Each entry is the member payload returned by the server's auth endpoint.
  /// The list is updated automatically as members join and leave.
  List<Map<String, dynamic>> get members;

  /// A stream that emits a member payload each time a new member joins.
  ///
  /// The emitted map contains the same fields as entries in [members].
  Stream<Map<String, dynamic>> get onJoin;

  /// A stream that emits a member payload each time a member leaves.
  ///
  /// The emitted map contains the same fields as entries in [members].
  Stream<Map<String, dynamic>> get onLeave;
}
