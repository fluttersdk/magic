import 'package:flutter/foundation.dart';

import '../auth/auth_manager.dart';
import '../auth/authenticatable.dart';
import '../auth/contracts/guard.dart';
import '../database/eloquent/model.dart';

/// A fake [AuthManager] for testing.
///
/// Routes all guard operations through an in-memory [_FakeGuard] instead of
/// resolving real guards from config. Supports assertions and login tracking.
///
/// ```dart
/// final fake = Auth.fake(user: myUser);
///
/// expect(Auth.check(), isTrue);
/// expect(Auth.user<User>(), same(myUser));
///
/// await Auth.logout();
/// fake.assertLoggedOut();
/// ```
class FakeAuthManager extends AuthManager {
  /// The internal fake guard used for all guard resolutions.
  final _FakeGuard _fakeGuard;

  /// Creates a fake auth manager.
  ///
  /// Optionally pre-authenticates with the given [user].
  FakeAuthManager({Authenticatable? user})
    : _fakeGuard = _FakeGuard(user: user),
      super.forTesting();

  /// Always returns the internal [_FakeGuard], regardless of guard name.
  @override
  Guard guard([String? name]) => _fakeGuard;

  /// Clears the fake guard state.
  @override
  void forgetGuards() {
    _fakeGuard.reset();
  }

  // ---------------------------------------------------------------------------
  // Assertions
  // ---------------------------------------------------------------------------

  /// Assert that a user is currently authenticated.
  ///
  /// Throws [AssertionError] if no user is set.
  void assertLoggedIn() {
    if (!_fakeGuard.check()) {
      throw AssertionError(
        'Expected a user to be authenticated but none was found.',
      );
    }
  }

  /// Assert that no user is currently authenticated.
  ///
  /// Throws [AssertionError] if a user is set.
  void assertLoggedOut() {
    if (_fakeGuard.check()) {
      throw AssertionError('Expected no authenticated user but one was found.');
    }
  }

  /// Assert that at least one login attempt was made.
  ///
  /// Throws [AssertionError] if no login calls were recorded.
  void assertLoginAttempted() {
    if (_fakeGuard._loginAttempts.isEmpty) {
      throw AssertionError(
        'Expected at least one login attempt but none were recorded.',
      );
    }
  }

  /// Assert that exactly [expected] login attempts were made.
  ///
  /// Throws [AssertionError] if the count does not match.
  void assertLoginCount(int expected) {
    final actual = _fakeGuard._loginAttempts.length;
    if (actual != expected) {
      throw AssertionError(
        'Expected $expected login attempt(s) but found $actual.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Reset
  // ---------------------------------------------------------------------------

  /// Clear all fake state — user, token, and login attempts.
  void reset() {
    _fakeGuard.reset();
  }
}

// ---------------------------------------------------------------------------
// Internal fake guard
// ---------------------------------------------------------------------------

class _FakeGuard implements Guard {
  Authenticatable? _user;
  String? _token;
  final List<Map<String, dynamic>> _loginAttempts = [];

  @override
  final ValueNotifier<int> stateNotifier = ValueNotifier<int>(0);

  _FakeGuard({Authenticatable? user}) : _user = user;

  @override
  bool check() => _user != null;

  @override
  bool get guest => !check();

  @override
  T? user<T extends Model>() => _user as T?;

  @override
  dynamic id() => _user?.authIdentifier;

  @override
  void setUser(Authenticatable user) {
    _user = user;
  }

  @override
  Future<void> login(Map<String, dynamic> data, Authenticatable user) async {
    _user = user;
    _token = data['token'] as String?;
    _loginAttempts.add(data);
    stateNotifier.value++;
  }

  @override
  Future<void> logout() async {
    _user = null;
    _token = null;
    stateNotifier.value++;
  }

  @override
  Future<bool> hasToken() => Future<bool>.value(_token != null);

  @override
  Future<String?> getToken() => Future<String?>.value(_token);

  @override
  Future<bool> refreshToken() => Future<bool>.value(false);

  @override
  Future<void> restore() => Future<void>.value();

  /// Reset all internal state.
  void reset() {
    _user = null;
    _token = null;
    _loginAttempts.clear();
  }
}
