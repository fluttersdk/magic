import '../database/database_manager.dart';
import '../database/schema/blueprint.dart';

/// Laravel-style Schema Facade.
///
/// Provides a clean API for database schema operations like creating,
/// modifying, and dropping tables.
///
/// ## Creating Tables
///
/// ```dart
/// Schema.create('users', (Blueprint table) {
///   table.id();
///   table.string('name');
///   table.string('email').unique();
///   table.boolean('is_active').defaultValue(true);
///   table.timestamps();
/// });
/// ```
///
/// ## Modifying Tables
///
/// ```dart
/// Schema.table('users', (Blueprint table) {
///   table.string('avatar_url').nullable();
///   table.dropColumn('old_field');
///   table.renameColumn('name', 'full_name');
/// });
/// ```
///
/// ## Dropping Tables
///
/// ```dart
/// Schema.dropIfExists('users');
/// ```
///
/// ## Checking Structure
///
/// ```dart
/// if (await Schema.hasTable('users')) {
///   // Table exists
/// }
///
/// if (await Schema.hasColumn('users', 'email')) {
///   // Column exists
/// }
/// ```
class Schema {
  // Prevent instantiation
  Schema._();

  /// Get the database manager.
  static DatabaseManager get _db => DatabaseManager();

  /// Create a new table.
  ///
  /// The [callback] receives a [Blueprint] instance that you can use to
  /// define columns.
  ///
  /// ```dart
  /// Schema.create('posts', (table) {
  ///   table.id();
  ///   table.string('title');
  ///   table.text('content').nullable();
  ///   table.integer('user_id');
  ///   table.timestamps();
  /// });
  /// ```
  static void create(String table, void Function(Blueprint) callback) {
    final blueprint = Blueprint(table);
    callback(blueprint);
    blueprint.execute();
  }

  /// Modify an existing table.
  ///
  /// Use this to add, rename, or drop columns from an existing table.
  ///
  /// ```dart
  /// Schema.table('users', (table) {
  ///   // Add a column
  ///   table.string('avatar_url').nullable();
  ///
  ///   // Rename a column
  ///   table.renameColumn('name', 'full_name');
  ///
  ///   // Drop a column
  ///   table.dropColumn('legacy_field');
  /// });
  /// ```
  static void table(String tableName, void Function(Blueprint) callback) {
    final blueprint = Blueprint(tableName, isModification: true);
    callback(blueprint);
    blueprint.execute();
  }

  /// Drop a table if it exists.
  ///
  /// ```dart
  /// Schema.dropIfExists('temporary_data');
  /// ```
  static void dropIfExists(String table) {
    _db.connection.execute('DROP TABLE IF EXISTS $table');
    _db.clearSchemaCache(table);
  }

  /// Drop a table (throws if it doesn't exist).
  ///
  /// ```dart
  /// Schema.drop('old_table');
  /// ```
  static void drop(String table) {
    _db.connection.execute('DROP TABLE $table');
    _db.clearSchemaCache(table);
  }

  /// Check if a table exists.
  ///
  /// ```dart
  /// if (await Schema.hasTable('users')) {
  ///   // Safe to query users
  /// }
  /// ```
  static Future<bool> hasTable(String table) async {
    final result = _db.connection.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [table],
    );
    return result.isNotEmpty;
  }

  /// Check if a table has a specific column.
  ///
  /// ```dart
  /// if (await Schema.hasColumn('users', 'avatar_url')) {
  ///   // Column exists
  /// }
  /// ```
  static Future<bool> hasColumn(String table, String column) async {
    return _db.hasColumn(table, column);
  }

  /// Get all column names for a table.
  ///
  /// ```dart
  /// final columns = await Schema.getColumns('users');
  /// // ['id', 'name', 'email', 'created_at', 'updated_at']
  /// ```
  static Future<List<String>> getColumns(String table) async {
    return _db.getColumns(table);
  }

  /// Rename a table.
  ///
  /// ```dart
  /// Schema.rename('old_name', 'new_name');
  /// ```
  static void rename(String from, String to) {
    _db.connection.execute('ALTER TABLE $from RENAME TO $to');
    _db.clearSchemaCache(from);
    _db.clearSchemaCache(to);
  }
}
