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

  /// Clear all listeners.
  void clear() {
    _listeners.clear();
  }

  // ---------------------------------------------------------------------------
  // Dispatching
  // ---------------------------------------------------------------------------

  /// Dispatch an event to all registered listeners.
  ///
  /// Listeners are executed sequentially to ensure stability and predictable order.
  /// If a listener throws an error, it is caught and logged (rethrowing can be configured).
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

        // Ensure type safety manually since we are using raw MagicListener in the map
        // but the listener itself is typed MagicListener<T>.
        // We trust the registration logic (compiler checks generic constraints if used properly).
        // Since `handle` takes `T`, passing `event` works via dynamic dispatch or explicit check.
        // We use dynamic call here for simplicity as Dart handles the `handle(event)`
        // call correctly if the object has that method with matching type.
        // Alternatively, we can cast:
        // (listener as MagicListener<MagicEvent>).handle(event); -> This fails dart generics variance.
        // So we strictly rely on `runtimeType` matching in `register`.

        // This is safe because we map UserRegistered -> MagicListener<UserRegistered>
        await (listener as dynamic).handle(event);
      } catch (e, stack) {
        Log.error('Error handling event $eventType: $e\n$stack');
      }
    }
  }
}
