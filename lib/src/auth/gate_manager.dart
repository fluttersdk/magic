import '../facades/auth.dart';
import '../facades/event.dart';
import '../database/eloquent/model.dart';
import 'events/gate_events.dart';

/// Ability callback type.
///
/// The callback should accept a [Model] user as the first argument,
/// and optionally a second argument of any type (typed, nullable, or dynamic).
///
/// Valid signatures:
/// - `bool callback(Model user, Post post)` - Typed
/// - `bool callback(Model user, Post? post)` - Nullable typed
/// - `bool callback(Model user, dynamic post)` - Dynamic
/// - `bool callback(Model user)` - No second argument
typedef AbilityCallback = Function;

/// Callback signature for "before" checks (super admin bypass).
typedef BeforeCallback = bool? Function(Model user, String ability);

/// The Gate Manager.
///
/// Manages authorization abilities and their checks. This class stores
/// ability definitions and executes permission checks against the
/// authenticated user.
///
/// ## Philosophy
///
/// Authorization is **client-side** for simplicity. We check `Auth.user()`
/// properties against defined rules. For sensitive operations, always
/// validate on the server as well.
///
/// ## Events
///
/// The Gate system fires the following events:
///
/// - `GateAbilityDefined` - When a new ability is registered
/// - `GateAccessChecked` - After every ability check (allowed or denied)
/// - `GateAccessDenied` - When an ability check results in denial
///
/// ## Usage
///
/// ```dart
/// // Define abilities
/// gate.define('edit-post', (user, post) => user.id == post.userId);
///
/// // Check abilities
/// if (gate.allows('edit-post', post)) {
///   // User can edit
/// }
/// ```
class GateManager {
  /// Registered ability callbacks.
  final Map<String, AbilityCallback> _abilities = {};

  /// Registered "before" callbacks for super admin bypass.
  final List<BeforeCallback> _beforeCallbacks = [];

  /// Define an ability with a callback.
  ///
  /// The callback receives the authenticated user as the first argument
  /// and an optional second argument (model or data).
  ///
  /// Fires: `GateAbilityDefined`
  ///
  /// ```dart
  /// Gate.define('update-post', (user, post) {
  ///   return user.id == post.userId;
  /// });
  ///
  /// Gate.define('delete-post', (user, post) {
  ///   return user.isAdmin || user.id == post.userId;
  /// });
  /// ```
  void define(String ability, AbilityCallback callback) {
    _abilities[ability] = callback;

    // Fire event
    Event.dispatch(GateAbilityDefined(ability));
  }

  /// Register a "before" callback.
  ///
  /// Before callbacks run before all other ability checks. If a before
  /// callback returns `true`, the user is granted access. If it returns
  /// `false`, access is denied. If it returns `null`, the regular ability
  /// check runs.
  ///
  /// Fires: `GateBeforeRegistered`
  ///
  /// Use this for "super admin" bypass:
  ///
  /// ```dart
  /// Gate.before((user, ability) {
  ///   if (user.isAdmin) {
  ///     return true; // Admins can do everything
  ///   }
  ///   return null; // Continue with normal check
  /// });
  /// ```
  void before(BeforeCallback callback) {
    _beforeCallbacks.add(callback);

    // Fire event
    Event.dispatch(GateBeforeRegistered());
  }

  /// Check if the authenticated user has the given ability.
  ///
  /// Returns `false` if:
  /// - User is not authenticated
  /// - Ability is not defined
  /// - Ability check returns false
  ///
  /// Fires: `GateAccessChecked`, `GateAccessDenied` (if denied)
  ///
  /// ```dart
  /// if (Gate.allows('update-post', post)) {
  ///   showEditButton();
  /// }
  /// ```
  bool allows(String ability, [dynamic arguments]) {
    Model? user;
    bool allowed = false;

    // Guests cannot do anything by default
    if (!Auth.check()) {
      _dispatchAccessEvents(ability, arguments, user, false);
      return false;
    }

    // Get the authenticated user
    user = Auth.user<Model>();
    if (user == null) {
      _dispatchAccessEvents(ability, arguments, user, false);
      return false;
    }

    // Run "before" callbacks first
    for (final beforeCallback in _beforeCallbacks) {
      final result = beforeCallback(user, ability);
      if (result != null) {
        allowed = result;
        _dispatchAccessEvents(ability, arguments, user, allowed);
        return allowed;
      }
    }

    // Find the ability callback
    final callback = _abilities[ability];
    if (callback == null) {
      // Ability not defined - deny by default
      _dispatchAccessEvents(ability, arguments, user, false);
      return false;
    }

    // Execute the ability check
    try {
      allowed = callback(user, arguments);
    } catch (_) {
      // If callback throws, deny access
      allowed = false;
    }

    _dispatchAccessEvents(ability, arguments, user, allowed);
    return allowed;
  }

  /// Dispatch access events.
  void _dispatchAccessEvents(
    String ability,
    dynamic arguments,
    Model? user,
    bool allowed,
  ) {
    // Always dispatch the general access checked event
    Event.dispatch(GateAccessChecked(
      ability: ability,
      arguments: arguments,
      allowed: allowed,
      user: user,
    ));

    // Dispatch denied event if access was denied
    if (!allowed) {
      Event.dispatch(GateAccessDenied(
        ability: ability,
        arguments: arguments,
        user: user,
      ));
    }
  }

  /// Check if the authenticated user is denied the given ability.
  ///
  /// This is the inverse of [allows].
  ///
  /// ```dart
  /// if (Gate.denies('delete-post', post)) {
  ///   showAccessDenied();
  /// }
  /// ```
  bool denies(String ability, [dynamic arguments]) {
    return !allows(ability, arguments);
  }

  /// Alias for [allows].
  ///
  /// ```dart
  /// if (Gate.check('view-dashboard')) {
  ///   showDashboard();
  /// }
  /// ```
  bool check(String ability, [dynamic arguments]) {
    return allows(ability, arguments);
  }

  /// Check if an ability has been defined.
  bool has(String ability) {
    return _abilities.containsKey(ability);
  }

  /// Get all defined abilities.
  List<String> get abilities => _abilities.keys.toList();

  /// Clear all defined abilities and before callbacks.
  ///
  /// Useful for testing.
  void flush() {
    _abilities.clear();
    _beforeCallbacks.clear();
  }
}
