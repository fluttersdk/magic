import '../auth/gate_manager.dart';

/// The Gate Facade.
///
/// Provides static access to the authorization system. Use this to define
/// abilities and check permissions.
///
/// ## Quick Start
///
/// ```dart
/// // Define abilities (in GateServiceProvider.boot())
/// Gate.define('update-post', (user, post) => user.id == post.userId);
/// Gate.define('delete-post', (user, post) => user.isAdmin || user.id == post.userId);
///
/// // Check permissions
/// if (Gate.allows('update-post', post)) {
///   showEditButton();
/// }
///
/// if (Gate.denies('delete-post', post)) {
///   showAccessDenied();
/// }
/// ```
///
/// ## Super Admin Bypass
///
/// ```dart
/// Gate.before((user, ability) {
///   if (user.isAdmin) return true;
///   return null; // Continue normal check
/// });
/// ```
///
/// ## With MagicCan Widget
///
/// ```dart
/// MagicCan(
///   ability: 'update-post',
///   arguments: post,
///   child: WButton(text: 'Edit Post'),
/// )
/// ```
class Gate {
  /// The gate manager instance.
  static final GateManager _manager = GateManager();

  /// Get the gate manager instance.
  static GateManager get manager => _manager;

  /// Define an ability with a callback.
  ///
  /// The callback receives the authenticated user as the first argument
  /// and optional arguments as the second.
  ///
  /// ```dart
  /// Gate.define('edit-post', (user, post) => user.id == post.userId);
  /// ```
  static void define(String ability, AbilityCallback callback) {
    _manager.define(ability, callback);
  }

  /// Register a "before" callback.
  ///
  /// Before callbacks run before all other checks. Return `true` to allow,
  /// `false` to deny, or `null` to continue with normal check.
  ///
  /// ```dart
  /// Gate.before((user, ability) {
  ///   if (user.isAdmin) return true;
  ///   return null;
  /// });
  /// ```
  static void before(BeforeCallback callback) {
    _manager.before(callback);
  }

  /// Check if the authenticated user has the given ability.
  ///
  /// ```dart
  /// if (Gate.allows('update-post', post)) {
  ///   // User can edit
  /// }
  /// ```
  static bool allows(String ability, [dynamic arguments]) {
    return _manager.allows(ability, arguments);
  }

  /// Check if the authenticated user is denied the given ability.
  ///
  /// ```dart
  /// if (Gate.denies('delete-post', post)) {
  ///   showAccessDenied();
  /// }
  /// ```
  static bool denies(String ability, [dynamic arguments]) {
    return _manager.denies(ability, arguments);
  }

  /// Alias for [allows].
  static bool check(String ability, [dynamic arguments]) {
    return _manager.check(ability, arguments);
  }

  /// Check if an ability has been defined.
  static bool has(String ability) {
    return _manager.has(ability);
  }

  /// Get all defined abilities.
  static List<String> get abilities => _manager.abilities;

  /// Flush all abilities (for testing).
  static void flush() {
    _manager.flush();
  }
}
