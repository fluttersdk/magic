/// The base Seeder class.
///
/// Seeders are used to populate your database with initial or test data.
/// Think of it as a way to plant seeds of data into your database.
///
/// ## Creating a Seeder
///
/// ```dart
/// class UserSeeder extends Seeder {
///   @override
///   Future<void> run() async {
///     await UserFactory().count(50).create();
///   }
/// }
/// ```
///
/// ## Running Seeders
///
/// ```dart
/// // Run a single seeder
/// await UserSeeder().run();
///
/// // Run multiple seeders via DatabaseSeeder
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
abstract class Seeder {
  /// Run the database seeds.
  ///
  /// Override this method to define what data should be seeded.
  ///
  /// ```dart
  /// @override
  /// Future<void> run() async {
  ///   await UserFactory().count(100).create();
  ///   await PostFactory().count(500).create();
  /// }
  /// ```
  Future<void> run();

  /// Call other seeders from within this seeder.
  ///
  /// Use this to organize your seeders into logical groups.
  ///
  /// ```dart
  /// await call([
  ///   UserSeeder(),
  ///   PostSeeder(),
  /// ]);
  /// ```
  Future<void> call(List<Seeder> seeders) async {
    for (final seeder in seeders) {
      await seeder.run();
    }
  }
}
