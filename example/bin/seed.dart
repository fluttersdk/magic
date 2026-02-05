import 'package:magic/magic.dart';
import 'package:magic_example/config/app.dart';
import 'package:magic_example/config/database.dart';
import 'package:magic_example/database/seeders/database_seeder.dart';

/// Database Seeder Entry Point.
///
/// Run with:
/// ```bash
/// cd example
/// dart run bin/seed.dart
/// ```
void main() async {
  // Initialize Magic framework
  // Initialize Magic
  await Magic.init(configFactories: [() => appConfig, () => databaseConfig]);

  // ignore: avoid_print
  print('🌱 Starting database seeding...');

  // Run all seeders
  await DatabaseSeeder().run();

  // ignore: avoid_print
  print('✅ Database seeded successfully!');
}
