import 'magic_event.dart';

/// The base class for all event listeners.
///
/// Listeners handle logic when a specific [MagicEvent] is dispatched.
/// They are intended to decouple side-effects (like sending emails or logging)
/// from the main business logic.
///
/// ## Usage
///
/// ```dart
/// class SendWelcomeEmail extends MagicListener<UserRegistered> {
///   @override
///   Future<void> handle(UserRegistered event) async {
///     await Mail.to(event.user).send(WelcomeEmail());
///   }
/// }
/// ```
abstract class MagicListener<T extends MagicEvent> {
  /// Handle the event.
  ///
  /// This method is called automatically when [T] is dispatched.
  Future<void> handle(T event);
}
