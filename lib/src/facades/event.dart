import '../events/magic_event.dart';
import '../events/event_dispatcher.dart';
import '../events/magic_listener.dart';

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

  /// Register a listener for events of type [T], as Laravel's `Event::listen`.
  ///
  /// [T] is the registration key, so it has to be named: without it Dart
  /// infers [MagicEvent], and no dispatched event matches that exactly.
  /// Register from a provider's `register()`, not `boot()`: the auth guard
  /// can dispatch during `AuthServiceProvider.boot`, before a later provider
  /// boots. Registrations last until `MagicApp.flush()`.
  ///
  /// ```dart
  /// Event.listen<AuthLogin>(() => TrackSignIn());
  /// ```
  static void listen<T extends MagicEvent>(MagicListener Function() factory) {
    EventDispatcher.instance.register(T, [factory]);
  }
}
