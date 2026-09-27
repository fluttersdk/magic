import '../http/magic_controller.dart';
import 'broadcast_event.dart';
import 'broadcast_listeners.dart';

/// Livewire's `getListeners()` binding for a [MagicController]: declares
/// which broadcast events the controller cares about and registers them
/// through [BroadcastListeners] instead of talking to `Echo` directly.
///
/// [listeners] is keyed `'<alias>:<event>'` (for example
/// `'team:check.recorded'`), where `alias` is whatever name a caller already
/// declared with `BroadcastListeners.channel`. [startListening] is
/// idempotent and is called automatically from [onInit] (after
/// `super.onInit()`), which covers every controller that backs a
/// `MagicStatefulViewState` (magic runs `onInit` exactly once, the first time
/// a controller backs a view). A controller read only through `.instance`
/// and never mounted in a view never gets `onInit` called for it, so its own
/// constructor must call [startListening] itself.
///
/// [onClose] removes every token this mixin registered and leaves any other
/// controller listening on the same alias untouched: the underlying
/// subscription and channel belong to [BroadcastListeners], never to this
/// controller.
mixin ListensToBroadcasts on MagicController {
  /// The broadcast events this controller wants, keyed `'<alias>:<event>'`.
  Map<String, void Function(BroadcastEvent)> get listeners;

  /// The tokens [startListening] registered, removed by [onClose].
  final List<BroadcastListenerToken> _broadcastTokens =
      <BroadcastListenerToken>[];

  /// Whether [startListening] has already run for this controller instance.
  bool _listeningStarted = false;

  /// Registers every entry of [listeners] with [BroadcastListeners].
  ///
  /// Idempotent, so a controller that calls this from both its own
  /// constructor and [onInit] registers each listener exactly once.
  void startListening() {
    if (_listeningStarted) return;
    _listeningStarted = true;

    for (final MapEntry<String, void Function(BroadcastEvent)> entry
        in listeners.entries) {
      final int separator = entry.key.indexOf(':');
      if (separator == -1) {
        throw ArgumentError(
          'ListensToBroadcasts key "${entry.key}" must be "alias:event".',
        );
      }
      final String alias = entry.key.substring(0, separator);
      final String event = entry.key.substring(separator + 1);
      _broadcastTokens.add(BroadcastListeners.add(alias, event, entry.value));
    }
  }

  @override
  void onInit() {
    super.onInit();
    startListening();
  }

  @override
  void onClose() {
    for (final BroadcastListenerToken token in _broadcastTokens) {
      BroadcastListeners.remove(token);
    }
    _broadcastTokens.clear();
    super.onClose();
  }
}
