import 'package:magic/magic.dart';

import 'user_seeder.dart';
import 'todo_seeder.dart';

/// DatabaseSeeder
///
/// Main entry point for seeding the database.
///
/// Run with:
/// ```bash
/// dart run bin/seed.dart
/// ```
class DatabaseSeeder extends Seeder {
  @override
  Future<void> run() async {
    await call([UserSeeder(), TodoSeeder()]);
  }
}
