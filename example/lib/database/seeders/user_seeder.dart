import 'package:fluttersdk_magic/fluttersdk_magic.dart';

import '../factories/user_factory.dart';

/// UserSeeder
///
/// Seeds the database with sample user data.
class UserSeeder extends Seeder {
  @override
  Future<void> run() async {
    // Create 50 random users
    await UserFactory().count(50).create();

    // Create 5 young users
    await UserFactory().young().count(5).create();
  }
}
