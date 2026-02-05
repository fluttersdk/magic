import 'package:magic/magic.dart';

import '../factories/todo_factory.dart';

/// TodoSeeder
///
/// Seeds the database with sample todo data.
class TodoSeeder extends Seeder {
  @override
  Future<void> run() async {
    // Create 20 random todos
    await TodoFactory().count(20).create();

    // Create 5 high priority incomplete todos
    await TodoFactory().highPriority().incomplete().count(5).create();
  }
}
