import '../auth/auth_manager.dart';
import '../auth/contracts/guard.dart';
import '../auth/authenticatable.dart';
import '../database/eloquent/model.dart';

/// The Auth Facade.
///
/// Provides static access to the authentication system.
/// Proxies calls to the default guard.
///
/// ## Quick Reference
///
/// ```dart
/// // Login (app handles API call, passes result)
/// final response = await Http.post('/login', data: credentials);
/// final user = User.fromMap(response['data']['user']);
/// await Auth.login({'token': response['data']['token']}, user);
///
/// // Check if logged in
/// if (Auth.check()) {
///   print('User: ${Auth.user<User>()?.name}');
/// }
///
/// // Logout
/// await Auth.logout();
///
/// // Restore on app boot
/// await Auth.restore();
/// ```
///
/// ## Multiple Guards
///
/// ```dart
/// final apiGuard = Auth.guard('api');
/// await apiGuard.login(data, user);
/// ```
class Auth {
  /// The auth manager instance.
  static final AuthManager _manager = AuthManager();

  /// Get the auth manager.
  static AuthManager get manager => _manager;

  /// Get a guard instance.
  ///
  /// If no name is provided, returns the default guard.
  static Guard guard([String? name]) => _manager.guard(name);

  // ---------------------------------------------------------------------------
  // Authentication Methods
  // ---------------------------------------------------------------------------

  /// Login with data and set the authenticated user.
  ///
  /// The app is responsible for making the API call and parsing the response.
  /// This method stores credentials and sets the user.
  ///
  /// ```dart
  /// final response = await Http.post('/login', data: {'email': ..., 'password': ...});
  /// if (response.successful) {
  ///   final user = User.fromMap(response['data']['user']);
  ///   await Auth.login({'token': response['data']['token']}, user);
  ///   Route.to('/dashboard');
  /// }
  /// ```
  static Future<void> login(
    Map<String, dynamic> data,
    Authenticatable user,
  ) =>
      guard().login(data, user);

  /// Log the user out.
  ///
  /// Clears stored credentials and user from memory.
  ///
  /// ```dart
  /// await Http.post('/logout'); // Optional API call
  /// await Auth.logout();
  /// Route.to('/login');
  /// ```
  static Future<void> logout() => guard().logout();

  // ---------------------------------------------------------------------------
  // State Methods
  // ---------------------------------------------------------------------------

  /// Check if the user is authenticated.
  ///
  /// ```dart
  /// if (Auth.check()) {
  ///   showDashboard();
  /// } else {
  ///   showLogin();
  /// }
  /// ```
  static bool check() => guard().check();

  /// Check if the user is a guest (not authenticated).
  static bool get guest => guard().guest;

  /// Get the authenticated user.
  ///
  /// Returns `null` if not authenticated.
  ///
  /// ```dart
  /// final user = Auth.user<User>();
  /// print(user?.name ?? 'Guest');
  /// ```
  static T? user<T extends Model>() => guard().user<T>();

  /// Get the authenticated user's ID.
  static dynamic id() => guard().id();

  // ---------------------------------------------------------------------------
  // Token Methods
  // ---------------------------------------------------------------------------

  /// Check if a stored token exists.
  ///
  /// ```dart
  /// if (await Auth.hasToken()) {
  ///   await Auth.restore();
  /// }
  /// ```
  static Future<bool> hasToken() => guard().hasToken();

  /// Get the stored token.
  ///
  /// ```dart
  /// final token = await Auth.getToken();
  /// headers['Authorization'] = 'Bearer $token';
  /// ```
  static Future<String?> getToken() => guard().getToken();

  // ---------------------------------------------------------------------------
  // Configuration Methods
  // ---------------------------------------------------------------------------

  /// Register the user model factory.
  ///
  /// ```dart
  /// Auth.registerModel<User>(User.fromMap);
  /// ```
  static void registerModel<T>(
    Authenticatable Function(Map<String, dynamic> data) factory,
  ) {
    _manager.setUserFactory(factory);
  }

  // ---------------------------------------------------------------------------
  // Token Refresh
  // ---------------------------------------------------------------------------

  /// Manually refresh the authentication token.
  ///
  /// Returns `true` if refresh was successful.
  ///
  /// ```dart
  /// final success = await Auth.refreshToken();
  /// ```
  static Future<bool> refreshToken() => guard().refreshToken();

  // ---------------------------------------------------------------------------
  // Session Methods
  // ---------------------------------------------------------------------------

  /// Restore session from storage.
  ///
  /// Called on app boot to restore user from stored token.
  ///
  /// ```dart
  /// await Auth.restore();
  /// if (Auth.check()) {
  ///   Route.to('/dashboard');
  /// } else {
  ///   Route.to('/login');
  /// }
  /// ```
  static Future<void> restore() => guard().restore();
}
