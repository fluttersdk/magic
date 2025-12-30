/// The Migration Contract.
///
/// All database migrations must extend this class and implement the [up] and
/// [down] methods to define how changes are applied and reverted.
///
/// ## Creating Migrations
///
/// ```dart
/// class CreateUsersTable extends Migration {
///   @override
///   String get name => '2024_01_01_000001_create_users_table';
///
///   @override
///   void up() {
///     Schema.create('users', (table) {
///       table.id();
///       table.string('name');
///       table.string('email').unique();
///       table.timestamps();
///     });
///   }
///
///   @override
///   void down() {
///     Schema.dropIfExists('users');
///   }
/// }
/// ```
///
/// ## Migration Naming Convention
///
/// Use a timestamp prefix for proper ordering:
/// `YYYY_MM_DD_HHMMSS_action_table_name`
///
/// Examples:
/// - `2024_01_15_120000_create_users_table`
/// - `2024_01_15_120001_add_avatar_to_users`
/// - `2024_01_15_120002_create_posts_table`
abstract class Migration {
  /// The unique name/identifier for this migration.
  ///
  /// This should follow the timestamp naming convention:
  /// `YYYY_MM_DD_HHMMSS_description`
  String get name;

  /// Run the migration.
  ///
  /// Define your schema changes here using [Schema.create], [Schema.drop],
  /// or raw SQL via [DB].
  void up();

  /// Reverse the migration.
  ///
  /// Define how to undo the changes made in [up].
  void down();
}
