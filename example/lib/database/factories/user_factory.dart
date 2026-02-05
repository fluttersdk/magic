import 'package:magic/magic.dart';

import '../../app/models/user.dart';

/// UserFactory
///
/// Generates fake User instances for seeding and testing.
class UserFactory extends Factory<User> {
  @override
  User newInstance() => User();

  @override
  Map<String, dynamic> definition() {
    return {
      'name': faker.person.name(),
      'email': faker.internet.email(),
      'born_at':
          faker.date.dateTime(minYear: 1970, maxYear: 2000).toIso8601String(),
    };
  }

  /// Create an admin user.
  UserFactory admin() {
    return state({'role': 'admin'}) as UserFactory;
  }

  /// Create a recently born user (for testing age-related logic).
  UserFactory young() {
    return state({
      'born_at':
          faker.date.dateTime(minYear: 1995, maxYear: 2005).toIso8601String(),
    }) as UserFactory;
  }
}
