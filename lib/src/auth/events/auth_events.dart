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
class AuthRestored extends MagicEvent {
  /// The user who was restored.
  final Authenticatable user;

  /// The guard name used.
  final String guard;

  AuthRestored(this.user, {this.guard = 'web'});
}
