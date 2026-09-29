import '../../events/magic_event.dart';
import '../authenticatable.dart';

/// Fired when a user successfully logs in.
///
/// Dispatched at the end of `BaseGuard.startSession`, once the user is set and
/// cached. It does not fire on a restore; listen to `Auth.stateNotifier` for
/// "a user became known" on a cold boot.
class AuthLogin extends MagicEvent {
  /// The user who logged in.
  final Authenticatable user;

  /// The guard name used for login.
  final String guard;

  AuthLogin(this.user, {this.guard = 'web'});
}

/// Fired when the in-memory session ended.
///
/// Not a promise that the credentials are gone: it fires even when a vault
/// delete failed, so a listener releasing server-side state has to gate on
/// `Auth.hasToken()`.
class AuthLogout extends MagicEvent {
  /// The user held when the logout began, or null for a guest.
  final Authenticatable? user;

  /// The guard name used.
  final String guard;

  AuthLogout(this.user, {this.guard = 'web'});
}

/// Fired when an authentication attempt fails.
class AuthFailed extends MagicEvent {
  /// The credentials provided during the attempt.
  final Map<String, dynamic> credentials;

  /// The guard name used.
  final String guard;

  AuthFailed(this.credentials, {this.guard = 'web'});
}

/// Fired when authentication state is restored.
///
/// Dispatched by `BaseGuard.restore()`'s user sync once the API confirmed the
/// user, on a cold boot and on every later `Auth.restore()` call alike.
class AuthRestored extends MagicEvent {
  /// The user who was restored.
  final Authenticatable user;

  /// The guard name used.
  final String guard;

  /// Whether the confirmed user differs from the one the guard held before
  /// the sync, compared on their serialized attributes (`toMap()`).
  ///
  /// False when the API only confirmed the cached user, which is what a cold
  /// boot with a warm cache usually hears: a listener that rebuilds screens
  /// from the user (a soft reload, a refetch) has nothing to refresh then.
  /// True when an attribute moved, and when the guard held no user at all (a
  /// cold start with an empty cache). Defaults to true, so an event built
  /// without it keeps meaning "the user may have changed".
  ///
  /// `toMap()` leaves out the model's `hidden` attributes, and the user cache
  /// stores the same map, so a change to a hidden attribute alone reads as
  /// unchanged. Keep anything a listener must react to out of `hidden`.
  final bool changed;

  AuthRestored(this.user, {this.guard = 'web', this.changed = true});
}
