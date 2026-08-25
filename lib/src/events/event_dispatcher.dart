import 'magic_event.dart';
import 'magic_listener.dart';
import '../facades/log.dart';

/// The Event Dispatcher.
///
/// Manages the registration and dispatching of events to listeners.
/// This is the engine behind the `Event` facade.
///
/// It supports mapping an Event Type to multiple Listener factories.
class EventDispatcher {
  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------

  static EventDispatcher? _instance;

  static EventDispatcher get instance {
    _instance ??= EventDispatcher._();
    return _instance!;
  }

  EventDispatcher._();

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  /// Map of Event Types to a list of Listener Factory functions.
  ///
  /// We use factories `MagicListener Function()` to ensure we get a fresh
  /// (or properly managed) instance of the listener capability each time,
  /// and to avoid reflection.
  final Map<Type, List<MagicListener Function()>> _listeners = {};

  // ---------------------------------------------------------------------------
  // Registration
  // ---------------------------------------------------------------------------

  /// Register valid listeners for a specific event.
  ///
  /// [listeners] is a list of factory functions that return a [MagicListener].
  ///
  /// ```dart
  /// dispatcher.register(UserRegistered, [
  ///   () => SendWelcomeEmail(),
  ///   () => LogRegistration(),
  /// ]);
  /// ```
  void register(Type eventType, List<MagicListener Function()> listeners) {
    if (!_listeners.containsKey(eventType)) {
      _listeners[eventType] = [];
    }
    _listeners[eventType]!.addAll(listeners);
  }

  // ---------------------------------------------------------------------------
  // Dispatching
  // ---------------------------------------------------------------------------

  /// Dispatch an event to all registered listeners.
  ///
  /// Listeners are executed sequentially to ensure stability and predictable
  /// order.
  ///
  /// A listener that throws is caught and logged, and the remaining listeners
  /// still run. This is a deliberate divergence from Laravel, whose dispatcher
  /// lets the exception propagate: on a client, one failing listener must not
  /// take down the frame that dispatched the event. The trade is that a broken
  /// listener is only visible in the log, so check there when an event looks
  /// like it did nothing.
  ///
  /// There is no switch to make it rethrow. This docstring used to say the
  /// behaviour "can be configured", which was never true.
  Future<void> dispatch(MagicEvent event) async {
    final eventType = event.runtimeType;

    // Check strict match
    if (!_listeners.containsKey(eventType)) {
      return;
    }

    final listeners = _listeners[eventType]!;

    for (final listenerFactory in listeners) {
      try {
        final listener = listenerFactory();
        await (listener as dynamic).handle(event);
      } catch (e, stack) {
        Log.error('Error handling event $eventType: $e\n$stack');
      }
    }
  }

  /// Clear all listeners.
  void clear() {
    _listeners.clear();
  }
}
