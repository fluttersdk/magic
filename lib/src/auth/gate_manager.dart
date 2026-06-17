import 'dart:collection';

import '../facades/auth.dart';
import '../facades/event.dart';
import '../database/eloquent/model.dart';
import 'events/gate_events.dart';
import 'gate_result.dart';

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

  /// Most-recent ability check outcomes, bounded by [_maxCacheSize].
  ///
  /// [LinkedHashMap] preserves insertion order; [_recordResult] removes
  /// then re-inserts the entry to keep the most-recently-written key at
  /// the back, and evicts the first key (the least-recently-written) on
  /// overflow. This gives the dusk integration a cheap "what was the
  /// latest decision for ability X" lookup without retaining argument
  /// references.
  final LinkedHashMap<String, GateResult> _resultCache =
      LinkedHashMap<String, GateResult>();

  /// Maximum number of cached gate results. Once exceeded, the
  /// least-recently-written entry is evicted.
  static const int _maxCacheSize = 64;

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
      _recordResult(ability, arguments, false);
      return false;
    }

    // Get the authenticated user
    user = Auth.user<Model>();
    if (user == null) {
      _dispatchAccessEvents(ability, arguments, user, false);
      _recordResult(ability, arguments, false);
      return false;
    }

    // Run "before" callbacks first
    for (final beforeCallback in _beforeCallbacks) {
      final result = beforeCallback(user, ability);
      if (result != null) {
        allowed = result;
        _dispatchAccessEvents(ability, arguments, user, allowed);
        _recordResult(ability, arguments, allowed);
        return allowed;
      }
    }

    // Find the ability callback
    final callback = _abilities[ability];
    if (callback == null) {
      // Ability not defined - deny by default
      _dispatchAccessEvents(ability, arguments, user, false);
      _recordResult(ability, arguments, false);
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
    _recordResult(ability, arguments, allowed);
    return allowed;
  }

  /// Record the outcome of an ability check in the bounded MRU cache.
  ///
  /// 1. Remove any prior entry for `ability` so the re-insert moves the
  ///    key to the back (MRU touch).
  /// 2. Insert the fresh [GateResult].
  /// 3. If the cache exceeds [_maxCacheSize], evict the least-recently
  ///    written key (the first key in the linked iteration order).
  ///
  /// Stores `arguments.runtimeType` instead of the argument itself to
  /// avoid retaining caller-owned references in long-running debug
  /// sessions.
  void _recordResult(String ability, dynamic arguments, bool allowed) {
    final result = GateResult(
      ability: ability,
      allowed: allowed,
      argumentType: arguments?.runtimeType,
      checkedAt: DateTime.now(),
    );

    // 1. Touch: remove then re-insert to move to the MRU end.
    _resultCache.remove(ability);

    // 2. Write the fresh outcome.
    _resultCache[ability] = result;

    // 3. Evict the oldest write when over capacity.
    if (_resultCache.length > _maxCacheSize) {
      _resultCache.remove(_resultCache.keys.first);
    }
  }

  /// Return the most recent [GateResult] for [ability], or `null` when
  /// the ability has never been checked (or its entry was evicted).
  ///
  /// ```dart
  /// final result = Gate.manager.lastResult('monitors.update');
  /// if (result != null && result.allowed) {
  ///   // Most recent check passed.
  /// }
  /// ```
  GateResult? lastResult(String ability) => _resultCache[ability];

  /// Return the most recently recorded [GateResult] across all
  /// abilities, or `null` when no check has run yet.
  ///
  /// Consumed by dev-tooling integrations (the dusk snapshot enricher)
  /// that want the "latest gate decision" without knowing the ability
  /// name in advance. Backed by [LinkedHashMap] insertion order — the
  /// `_recordResult` touch+insert pattern guarantees the last write is
  /// always the last linked entry.
  GateResult? get mostRecentResult {
    if (_resultCache.isEmpty) return null;
    return _resultCache[_resultCache.keys.last];
  }

  /// Dispatch access events.
  void _dispatchAccessEvents(
    String ability,
    dynamic arguments,
    Model? user,
    bool allowed,
  ) {
    // Always dispatch the general access checked event
    Event.dispatch(
      GateAccessChecked(
        ability: ability,
        arguments: arguments,
        allowed: allowed,
        user: user,
      ),
    );

    // Dispatch denied event if access was denied
    if (!allowed) {
      Event.dispatch(
        GateAccessDenied(ability: ability, arguments: arguments, user: user),
      );
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

  /// Check if the authenticated user has any of the given abilities.
  ///
  /// Short-circuits on the first ability that passes.
  ///
  /// ```dart
  /// if (Gate.allowsAny(['owner', 'admin'], project)) { ... }
  /// ```
  bool allowsAny(List<String> abilities, [dynamic arguments]) {
    for (final ability in abilities) {
      if (allows(ability, arguments)) return true;
    }
    return false;
  }

  /// Check if the authenticated user has every one of the given abilities.
  ///
  /// Short-circuits on the first ability that fails.
  ///
  /// ```dart
  /// if (Gate.allowsAll(['update', 'publish'], post)) { ... }
  /// ```
  bool allowsAll(List<String> abilities, [dynamic arguments]) {
    for (final ability in abilities) {
      if (!allows(ability, arguments)) return false;
    }
    return true;
  }

  /// Check if an ability has been defined.
  bool has(String ability) {
    return _abilities.containsKey(ability);
  }

  /// Get all defined abilities.
  List<String> get abilities => _abilities.keys.toList();

  /// Clear all defined abilities, before callbacks, and the lastResult
  /// cache.
  ///
  /// Useful for testing.
  void flush() {
    _abilities.clear();
    _beforeCallbacks.clear();
    _resultCache.clear();
  }
}
