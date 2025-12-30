import 'package:flutter/material.dart';
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

import '../models/user.dart';
import '../../resources/views/user/profile_view.dart';

/// User Controller - Laravel-style with actions returning views.
///
/// ## Usage
///
/// ```dart
/// // Routes
/// MagicRoute.get('/user', () => UserController.instance.index());
/// MagicRoute.get('/user/:id', (id) => UserController.instance.show(id));
/// ```
class UserController extends MagicController with MagicStateMixin<User> {
  /// Singleton accessor with lazy registration.
  static UserController get instance => Magic.findOrPut(UserController.new);

  // ---------------------------------------------------------------------------
  // Actions (return Widget from resources/views)
  // ---------------------------------------------------------------------------

  /// GET /user - Show user profile.
  Widget index() {
    if (isEmpty) {
      fetchUser();
    }
    return UserProfileView(controller: this);
  }

  /// GET /user/:id - Show specific user.
  Widget show(String id) {
    fetchUser(id: id);
    return UserProfileView(controller: this);
  }

  // ---------------------------------------------------------------------------
  // Business Logic
  // ---------------------------------------------------------------------------

  /// Fetch user data from API (simulated).
  Future<void> fetchUser({String? id}) async {
    setLoading(); // <-- Laravel-style helper

    try {
      // Simulate caching: Fetch user or use cached version (TTL: 1 minute)
      // We store keys as Maps to handle serialization.
      final userMap = await Cache.remember(
        'user_${id ?? "me"}',
        const Duration(minutes: 1),
        () async {
          await Future.delayed(const Duration(seconds: 2));
          // Using new Eloquent model pattern
          final user = User()
            ..fill({
              'id': int.tryParse(id ?? '1') ?? 1,
              'name': 'Magic Developer',
              'email': 'dev@magic.app',
            });
          return user.toArray();
        },
      );

      // Hydrate user from cached map
      final user = User()
        ..setRawAttributes(userMap, sync: true)
        ..exists = true;
      setSuccess(user);
    } catch (e) {
      setError(e.toString());
    }
  }

  /// Refresh user data.
  Future<void> refresh() async {
    await fetchUser();
  }

  /// Simulate an error.
  void simulateError() {
    setError('Something went wrong!');
  }
}
