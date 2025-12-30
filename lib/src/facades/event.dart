import '../events/magic_event.dart';
import '../events/event_dispatcher.dart';

/// The Event Facade.
///
/// Provides a static interface for dispatching events throughout the application.
///
/// ## Usage
///
/// ```dart
/// await Event.dispatch(UserRegistered(user));
/// ```
class Event {
  // Prevent instantiation
  Event._();

  /// Dispatch an event to all registered listeners.
  ///
  /// ```dart
  /// await Event.dispatch(OrderShipped(order));
  /// ```
  static Future<void> dispatch(MagicEvent event) async {
    // Resolve the dispatcher from the container or singleton
    // We use the singleton instance directly via Magic.find if registered,
    // or fallback to singleton access if needed.
    // However, EventServiceProvider registers it as 'events'.
    return EventDispatcher.instance.dispatch(event);
  }
}
