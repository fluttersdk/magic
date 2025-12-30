/// The base class for all events.
///
/// Events serve as data containers that are dispatched throughout the application.
/// Listeners subscribe to specific Event types.
///
/// ## Usage
///
/// ```dart
/// class UserRegistered extends MagicEvent {
///   final User user;
///   UserRegistered(this.user);
/// }
/// ```
abstract class MagicEvent {}
