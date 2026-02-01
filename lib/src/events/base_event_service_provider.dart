import '../support/service_provider.dart';
import 'event_dispatcher.dart';
import 'magic_listener.dart';

/// The Event Service Provider.
///
/// This provider is responsible for registering all event listeners.
/// Subclass this in your application to map events to listeners.
///
/// ## Usage
///
/// ```dart
/// class EventServiceProvider extends BaseEventServiceProvider {
///   @override
///   Map<Type, List<MagicListener Function()>> get listen => {
///     UserRegistered: [
///       () => SendWelcomeEmail(),
///       () => LogRegistration(),
///     ],
///   };
/// }
/// ```
class BaseEventServiceProvider extends ServiceProvider {
  BaseEventServiceProvider(super.app);

  /// The event listener mappings for the application.
  ///
  /// Returns a map where the key is the Event Type, and the value is a list
  /// of factory functions that return the Listener instances.
  Map<Type, List<MagicListener Function()>> get listen => {};

  @override
  void register() {
    // Register the Event Dispatcher singleton
    app.singleton('events', () => EventDispatcher.instance);

    // Register all configured listeners
    final dispatcher = EventDispatcher.instance;
    listen.forEach((event, listeners) {
      dispatcher.register(event, listeners);
    });
  }
}
