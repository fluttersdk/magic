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
  /// Runs every pending migration, or none of them.
  ///
  /// ### The whole run is one transaction
  ///
  /// It was none, and the state that produced is a host that never boots
  /// again. Each migration was applied and recorded in turn, so a failure part
  /// way left that migration's earlier statements applied and its ledger row
  /// absent. The next launch re-ran it from its first statement, met the table
  /// it had already created, and failed identically. A host that migrates
  /// inside `Magic.init` before `runApp` has no UI to report that from, and
  /// the only repair is deleting the database.
  ///
  /// SQLite rolls DDL back like anything else, so one `BEGIN` is the whole
  /// fix. The run is the unit rather than each migration: a ledger recording
  /// one migration and not the next describes a schema nobody designed, and
  /// the host has no way to learn which half it has.
  ///
  /// ### Why it defers to a caller that already opened one
  ///
  /// sqlite refuses a nested `BEGIN` with `cannot start a transaction within a
  /// transaction`, so opening one unconditionally would break every host that
  /// wraps this call itself, which is what a host had to do before this
  /// landed. [CommonDatabase.autocommit] is false exactly while a transaction
  /// is open, and is the only thing that can tell the two cases apart.
  ///
  /// The tracking table is created OUTSIDE the transaction, deliberately. A
  /// database with a ledger and no rows is what a fresh install has anyway, so
  /// there is nothing to roll back about it, and creating it inside would mean
  /// a failed first run left no way to record the retry.
  Future<List<String>> run(List<Migration> migrations) async {
    // Ensure migrations table exists
    await _ensureMigrationsTable();

    // Get already executed migrations
    final executed = await _getExecutedMigrations();

    // Filter to pending only
    final pending = migrations
        .where((m) => !executed.contains(m.name))
        .toList();

    if (pending.isEmpty) {
      return [];
    }

    // Get next batch number
    _batch = await _getNextBatchNumber();

    final owned = _db.connection.autocommit;
    if (owned) _db.connection.execute('BEGIN');

    final ranMigrations = <String>[];

    try {
      for (final migration in pending) {
        migration.up();
        await _recordMigration(migration.name);
        ranMigrations.add(migration.name);
      }
    } catch (_) {
      // Only unwind what this call started. A caller that owns the
      // transaction gets the throw and rolls back its own, which is what the
      // `outer` case in `migrator_atomicity_test.dart` asserts.
      if (owned) _db.connection.execute('ROLLBACK');

      rethrow;
    }

    if (owned) _db.connection.execute('COMMIT');

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
  ///
  /// The cache line is not housekeeping. A raw `execute` changes the schema
  /// behind [DatabaseManager]'s back, and `getColumns` caches the EMPTY answer
  /// a missing table gives. [_recordMigration] goes through `QueryBuilder`,
  /// which filters every key against that cache, and an empty filter makes
  /// `insert` return 0 without inserting and without throwing
  /// (`query_builder.dart:278-280`). So anything that read this table's
  /// columns before it existed would leave every migration applied and never
  /// recorded, and re-applied on every launch for ever.
  Future<void> _ensureMigrationsTable() async {
    _db.connection.execute('''
      CREATE TABLE IF NOT EXISTS $_table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        migration TEXT NOT NULL,
        batch INTEGER NOT NULL
      )
    ''');

    _db.clearSchemaCache(_table);
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
    await QueryBuilder(_table).insert({'migration': name, 'batch': _batch});
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
