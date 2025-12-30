import '../database_manager.dart';
import '../query/query_builder.dart';
import 'migration.dart';

/// The Migrator Service.
///
/// Handles running and tracking database migrations. The migrator keeps track
/// of which migrations have already been executed using a `magic_migrations`
/// table in the database.
///
/// ## Running Migrations
///
/// ```dart
/// final migrator = Migrator();
///
/// await migrator.run([
///   CreateUsersTable(),
///   CreatePostsTable(),
///   AddAvatarToUsers(),
/// ]);
/// ```
///
/// ## How It Works
///
/// 1. Creates the `magic_migrations` tracking table if it doesn't exist
/// 2. Loads all previously executed migrations
/// 3. Filters the provided migrations to only pending ones
/// 4. Executes each pending migration's [up] method
/// 5. Records each successful migration in the tracking table
/// 6. Clears the schema cache for affected tables
///
/// ## Rolling Back
///
/// ```dart
/// // Rollback the last batch
/// await migrator.rollback([
///   CreateUsersTable(),
///   CreatePostsTable(),
/// ]);
/// ```
class Migrator {
  /// Singleton instance.
  static final Migrator _instance = Migrator._internal();

  /// Factory constructor returns the singleton.
  factory Migrator() => _instance;

  /// Private constructor.
  Migrator._internal();

  /// Get the database manager.
  DatabaseManager get _db => DatabaseManager();

  /// The migrations tracking table name.
  static const String _table = 'magic_migrations';

  /// Current batch number.
  int _batch = 0;

  /// Run all pending migrations.
  ///
  /// [migrations] should be an ordered list of all migration classes.
  /// Only migrations that haven't been executed yet will run.
  ///
  /// ```dart
  /// await Migrator().run([
  ///   CreateUsersTable(),
  ///   CreatePostsTable(),
  /// ]);
  /// ```
  Future<List<String>> run(List<Migration> migrations) async {
    // Ensure migrations table exists
    await _ensureMigrationsTable();

    // Get already executed migrations
    final executed = await _getExecutedMigrations();

    // Filter to pending only
    final pending =
        migrations.where((m) => !executed.contains(m.name)).toList();

    if (pending.isEmpty) {
      return [];
    }

    // Get next batch number
    _batch = await _getNextBatchNumber();

    // Run each pending migration
    final ranMigrations = <String>[];

    for (final migration in pending) {
      try {
        // Execute the up method
        migration.up();

        // Record it
        await _recordMigration(migration.name);

        ranMigrations.add(migration.name);
      } catch (e) {
        // Log the error but continue with other migrations
        // In production, you might want to stop here
        rethrow;
      }
    }

    // Clear schema cache after migrations
    _db.clearSchemaCache();

    return ranMigrations;
  }

  /// Rollback the last batch of migrations.
  ///
  /// [migrations] should include all migration classes so we can find
  /// the corresponding [down] methods.
  ///
  /// ```dart
  /// await Migrator().rollback([
  ///   CreateUsersTable(),
  ///   CreatePostsTable(),
  /// ]);
  /// ```
  Future<List<String>> rollback(List<Migration> migrations) async {
    await _ensureMigrationsTable();

    // Get the last batch
    final lastBatch = await _getLastBatch();
    if (lastBatch.isEmpty) {
      return [];
    }

    // Create a map for quick lookup
    final migrationMap = {for (var m in migrations) m.name: m};

    // Rollback in reverse order
    final rolledBack = <String>[];
    for (final name in lastBatch.reversed) {
      final migration = migrationMap[name];
      if (migration != null) {
        try {
          migration.down();
          await _removeMigration(name);
          rolledBack.add(name);
        } catch (e) {
          rethrow;
        }
      }
    }

    _db.clearSchemaCache();
    return rolledBack;
  }

  /// Reset the database by rolling back all migrations.
  Future<List<String>> reset(List<Migration> migrations) async {
    await _ensureMigrationsTable();

    final executed = await _getExecutedMigrations();
    final migrationMap = {for (var m in migrations) m.name: m};

    final rolledBack = <String>[];
    for (final name in executed.reversed) {
      final migration = migrationMap[name];
      if (migration != null) {
        migration.down();
        await _removeMigration(name);
        rolledBack.add(name);
      }
    }

    _db.clearSchemaCache();
    return rolledBack;
  }

  /// Refresh the database (reset then run all migrations).
  Future<void> refresh(List<Migration> migrations) async {
    await reset(migrations);
    await run(migrations);
  }

  /// Get the list of executed migrations.
  Future<List<String>> getExecuted() async {
    await _ensureMigrationsTable();
    return _getExecutedMigrations();
  }

  /// Get pending migrations.
  Future<List<String>> getPending(List<Migration> migrations) async {
    await _ensureMigrationsTable();
    final executed = await _getExecutedMigrations();
    return migrations
        .where((m) => !executed.contains(m.name))
        .map((m) => m.name)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------

  /// Create the migrations tracking table if it doesn't exist.
  Future<void> _ensureMigrationsTable() async {
    _db.connection.execute('''
      CREATE TABLE IF NOT EXISTS $_table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        migration TEXT NOT NULL,
        batch INTEGER NOT NULL
      )
    ''');
  }

  /// Get list of executed migration names.
  Future<List<String>> _getExecutedMigrations() async {
    final result = _db.connection.select(
      'SELECT migration FROM $_table ORDER BY id',
    );
    return result.map((row) => row['migration'] as String).toList();
  }

  /// Get the next batch number.
  Future<int> _getNextBatchNumber() async {
    final result = _db.connection.select(
      'SELECT MAX(batch) as max_batch FROM $_table',
    );
    final maxBatch = result.first['max_batch'] as int?;
    return (maxBatch ?? 0) + 1;
  }

  /// Record a migration as executed.
  Future<void> _recordMigration(String name) async {
    await QueryBuilder(_table).insert({
      'migration': name,
      'batch': _batch,
    });
  }

  /// Remove a migration record.
  Future<void> _removeMigration(String name) async {
    await QueryBuilder(_table).where('migration', name).delete();
  }

  /// Get migrations from the last batch.
  Future<List<String>> _getLastBatch() async {
    // Get max batch
    final batchResult = _db.connection.select(
      'SELECT MAX(batch) as max_batch FROM $_table',
    );
    final maxBatch = batchResult.first['max_batch'] as int?;

    if (maxBatch == null) {
      return [];
    }

    // Get migrations from that batch
    final result = _db.connection.select(
      'SELECT migration FROM $_table WHERE batch = ? ORDER BY id',
      [maxBatch],
    );
    return result.map((row) => row['migration'] as String).toList();
  }
}
