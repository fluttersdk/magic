import 'package:fluttersdk_magic/fluttersdk_magic.dart';

/// The main database seeder.
///
/// This is the entry point for all your database seeders. Register your
/// seeders here using the [call] method.
///
/// ## Usage
///
/// ```dart
/// class DatabaseSeeder extends Seeder {
///   @override
///   Future<void> run() async {
///     await call([
///       UserSeeder(),
///       PostSeeder(),
///       CommentSeeder(),
///     ]);
///   }
/// }
/// ```
///
/// ## Running
///
/// ```dart
/// // In your bin/seed.dart or main.dart:
/// await Magic.init(config: appConfig);
/// await DatabaseSeeder().run();
/// ```
class DatabaseSeeder extends Seeder {
  @override
  Future<void> run() async {
    // Register your seeders here:
    // await call([
    //   UserSeeder(),
    //   PostSeeder(),
    // ]);
  }
}
