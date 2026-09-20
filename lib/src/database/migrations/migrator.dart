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

  /// The savepoint name [run] wraps itself in.
  static const String _savepoint = 'magic_migrator';

  /// Runs every pending migration, or none of them.
  ///
  /// [migrations] is an ordered list of every migration class; the ones
  /// already recorded are skipped.
  ///
  /// ```dart
  /// await Migrator().run([
  ///   CreateUsersTable(),
  ///   CreatePostsTable(),
  /// ]);
  /// ```
  ///
  /// ### The whole run is one unit
  ///
  /// It was not, and the state that produced is a host that never boots again.
  /// Each migration was applied and recorded in turn with nothing around them,
  /// so a failure part way left that migration's earlier statements applied
  /// and its ledger row absent. The next launch re-ran it from its first
  /// statement, met the table it had already created, and failed identically.
  /// A host that migrates inside `Magic.init` before `runApp` has no UI to
  /// report that from, and the only repair is deleting the database.
  ///
  /// The run is the unit rather than each migration: a ledger recording one
  /// migration and not the next describes a schema nobody designed, and the
  /// host has no way to learn which half it has.
  ///
  /// ### A SAVEPOINT rather than a BEGIN
  ///
  /// A savepoint nests and a `BEGIN` does not, so this composes with a host
  /// that wraps the call in its own transaction instead of throwing `cannot
  /// start a transaction within a transaction` at it. Verified in all three
  /// shapes: with no transaction open, inside one, and unwinding through
  /// `ROLLBACK TO`. The alternative was branching on
  /// the connection's `autocommit`, which works and leaves the host's shape
  /// deciding which code path runs.
  ///
  /// ### A migration must not manage its own transaction
  ///
  /// `DB.beginTransaction`, `commit` and `rollback` are a documented pattern
  /// (`doc/database/getting-started.md`), so a migration written that way was
  /// legitimate before this. It is not now, and the guard below is there
  /// because failing silently was the alternative: a `COMMIT` inside `up`
  /// closes this savepoint, so every later migration runs unprotected and the
  /// `RELEASE` throws `no such savepoint` AFTER every migration has succeeded
  /// and committed its ledger row. The caller would see a failure from a run
  /// that fully worked, and the retry would find nothing pending.
  ///
  /// The check names the migration that broke the contract and stops the loop
  /// there. A `DB.beginTransaction` inside `up` throws from sqlite instead,
  /// which is self-describing and unwinds through the same rollback.
  ///
  /// **That one case is early and named but NOT atomic**, and the headline
  /// above does not hold for it: the offending migration's own statements and
  /// every earlier migration's ledger row are already committed by the time
  /// the guard sees anything, so there is nothing left to unwind. Nothing can
  /// recover that, which is the whole reason a migration must not do it. A
  /// migration in this shape that is not written with `IF NOT EXISTS` will
  /// still boot-loop on retry.
  ///
  /// The tracking table is created BEFORE the savepoint, so an owned run that
  /// fails still leaves somewhere to record the retry. A host that wrapped the
  /// call in its own transaction and rolls back takes the table with it; that
  /// is harmless, because every entry point creates it again.
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

    _db.connection.execute('SAVEPOINT $_savepoint');

    final ranMigrations = <String>[];

    try {
      for (final migration in pending) {
        migration.up();

        // `autocommit` is false while a savepoint is open, so a true here
        // means this migration ended the transaction under us.
        if (_db.connection.autocommit) {
          throw StateError(
            'Migration [${migration.name}] committed or rolled back the '
            'transaction the migrator opened. A migration must not call '
            'DB.beginTransaction, DB.commit or DB.rollback: the whole run is '
            'already one unit.',
          );
        }

        await _recordMigration(migration.name);
        ranMigrations.add(migration.name);
      }
    } catch (_) {
      // `ROLLBACK TO` leaves the savepoint in place, so the `RELEASE` after it
      // is what actually discards it. Guarded on `autocommit` because the one
      // failure this cannot unwind is a migration that already closed it.
      if (!_db.connection.autocommit) {
        _db.connection.execute('ROLLBACK TO $_savepoint');
        _db.connection.execute('RELEASE $_savepoint');
      }

      // Anything cached during the undone migrations would describe schema
      // that no longer exists. No case reaches it today and the line stays
      // anyway: `up()` is synchronous while every cache-populating API is a
      // future, so the only entry the cache can hold mid-run is
      // `magic_migrations`, which survives the rollback. It costs one map
      // clear and stops being a no-op the day a synchronous introspection
      // helper lands. Deliberately untested rather than tested vacuously: a
      // test for it passes with the line deleted.
      _db.clearSchemaCache();

      rethrow;
    }

    _db.connection.execute('RELEASE $_savepoint');

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
