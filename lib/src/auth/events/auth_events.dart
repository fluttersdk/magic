import '../../events/magic_event.dart';
import '../authenticatable.dart';

/// Fired when a user successfully logs in.
class AuthLogin extends MagicEvent {
  /// The user who logged in.
  final Authenticatable user;

  /// The guard name used for login.
  final String guard;

  AuthLogin(this.user, {this.guard = 'web'});
}

/// Fired when a user logs out.
class AuthLogout extends MagicEvent {
  /// The user who logged out.
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
