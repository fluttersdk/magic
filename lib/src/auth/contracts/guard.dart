import 'package:flutter/foundation.dart';

import '../../database/eloquent/model.dart';
import '../authenticatable.dart';

/// The Guard Contract.
///
/// Guards manage authentication state for the application.
/// This is a minimal, frontend-focused interface.
///
/// ## Built-in Guards
///
/// - **BearerTokenGuard**: Token-based auth (most common)
/// - **BasicAuthGuard**: HTTP Basic authentication
/// - **ApiKeyGuard**: API key authentication
///
/// ## Usage
///
/// ```dart
/// // Login (app handles API call, passes result)
/// final response = await Http.post('/login', data: credentials);
/// final user = User.fromMap(response['data']['user']);
/// await Auth.login({'token': response['data']['token']}, user);
///
/// // Check auth state
/// if (Auth.check()) {
///   print('Logged in as ${Auth.user<User>()?.name}');
/// }
///
/// // Logout
/// await Auth.logout();
/// ```
abstract class Guard {
  /// Login with data and set the authenticated user.
  ///
  /// The app handles the API call and parsing.
  /// The guard stores credentials and sets the user.
  ///
  /// ```dart
  /// await Auth.login({'token': '...'}, user);
  /// ```
  Future<void> login(Map<String, dynamic> data, Authenticatable user);

  /// Log the user out.
  Future<void> logout();

  /// Check if user is authenticated.
  bool check();

  /// Check if user is a guest (not authenticated).
  bool get guest => !check();

  /// Get the authenticated user.
  T? user<T extends Model>();

  /// Get the authenticated user's ID.
  dynamic id();

  /// Set the user directly.
  void setUser(Authenticatable user);

  /// Check if a token exists in storage.
  Future<bool> hasToken();

  /// Get the stored token.
  Future<String?> getToken();

  /// Refresh the access token using the refresh token.
  ///
  /// Returns `true` if refresh was successful.
  /// Called automatically by interceptor on 401 responses.
  Future<bool> refreshToken();

  /// Restore session from storage.
  ///
  /// Called on app boot to restore user from stored token.
  Future<void> restore();

  /// Notifier that bumps on every auth state change.
  ///
  /// Listeners are notified when the user changes (login, logout, restore).
  /// Use this to rebuild UI after auth state transitions.
  ///
  /// ```dart
  /// Auth.stateNotifier.addListener(() => setState(() {}));
  /// ```
  ValueNotifier<int> get stateNotifier;
}
