import '../database/query/query_builder.dart';
import '../database/database_manager.dart';
import '../foundation/magic.dart';

/// Laravel-style DB Facade.
///
/// Provides a clean entry point for database query operations.
///
/// ## Basic Queries
///
/// ```dart
/// // Get all users
/// final users = await DB.table('users').get();
///
/// // Get first matching user
/// final user = await DB.table('users').where('id', 1).first();
///
/// // Get count
/// final count = await DB.table('users').count();
/// ```
///
/// ## Inserting
///
/// ```dart
/// final id = await DB.table('users').insert({
///   'name': 'John Doe',
///   'email': 'john@example.com',
/// });
/// ```
///
/// ## Updating
///
/// ```dart
/// await DB.table('users')
///   .where('id', 1)
///   .update({'name': 'Updated Name'});
/// ```
///
/// ## Deleting
///
/// ```dart
/// await DB.table('users').where('id', 1).delete();
/// ```
///
/// ## Raw Queries
///
/// ```dart
/// final results = DB.select('SELECT * FROM users WHERE age > ?', [18]);
/// DB.statement('DROP TABLE IF EXISTS temp');
/// ```
class DB {
  // Prevent instantiation
  DB._();

  /// Get the database manager.
  static DatabaseManager get _db {
    if (Magic.bound('db')) {
      return Magic.make<DatabaseManager>('db');
    }
    return DatabaseManager();
  }

  /// Start a query on a table.
  ///
  /// Returns a [QueryBuilder] for fluent query construction.
  ///
  /// ```dart
  /// final users = await DB.table('users')
  ///   .where('is_active', true)
  ///   .orderBy('created_at', 'desc')
  ///   .limit(10)
  ///   .get();
  /// ```
  static QueryBuilder table(String table) {
    return QueryBuilder(table);
  }

  /// Execute a raw SELECT query.
  ///
  /// ```dart
  /// final results = DB.select(
  ///   'SELECT * FROM users WHERE age > ?',
  ///   [18],
  /// );
  /// ```
  static List<Map<String, dynamic>> select(
    String sql, [
    List<Object?> params = const [],
  ]) {
    final result = _db.connection.select(sql, params);
    return result.map((row) {
      final map = <String, dynamic>{};
      for (final col in result.columnNames) {
        map[col] = row[col];
      }
      return map;
    }).toList();
  }

  /// Execute a raw SQL statement (INSERT, UPDATE, DELETE, etc.).
  ///
  /// ```dart
  /// DB.statement('DROP TABLE IF EXISTS temp_data');
  /// ```
  static void statement(String sql, [List<Object?> params = const []]) {
    _db.connection.execute(sql, params);
  }

  /// Execute an INSERT and return the last insert ID.
  ///
  /// ```dart
  /// final id = DB.insert(
  ///   'INSERT INTO users (name, email) VALUES (?, ?)',
  ///   ['John', 'john@example.com'],
  /// );
  /// ```
  static int insert(String sql, [List<Object?> params = const []]) {
    _db.connection.execute(sql, params);
    final result = _db.connection.select('SELECT last_insert_rowid() as id');
    return result.first['id'] as int;
  }

  /// Execute an UPDATE and return affected row count.
  ///
  /// ```dart
  /// final affected = DB.update(
  ///   'UPDATE users SET is_active = ? WHERE id = ?',
  ///   [true, 1],
  /// );
  /// ```
  static int update(String sql, [List<Object?> params = const []]) {
    _db.connection.execute(sql, params);
    final result = _db.connection.select('SELECT changes() as count');
    return result.first['count'] as int;
  }

  /// Execute a DELETE and return affected row count.
  ///
  /// ```dart
  /// final deleted = DB.delete('DELETE FROM users WHERE id = ?', [1]);
  /// ```
  static int delete(String sql, [List<Object?> params = const []]) {
    return update(sql, params);
  }

  /// Begin a database transaction.
  ///
  /// ```dart
  /// DB.beginTransaction();
  /// try {
  ///   await DB.table('users').insert({...});
  ///   await DB.table('profiles').insert({...});
  ///   DB.commit();
  /// } catch (e) {
  ///   DB.rollback();
  ///   rethrow;
  /// }
  /// ```
  static void beginTransaction() {
    _db.connection.execute('BEGIN TRANSACTION');
  }

  /// Commit the current transaction.
  static void commit() {
    _db.connection.execute('COMMIT');
  }

  /// Rollback the current transaction.
  static void rollback() {
    _db.connection.execute('ROLLBACK');
  }

  /// Execute code within a transaction.
  ///
  /// Automatically commits on success or rolls back on error.
  ///
  /// ```dart
  /// await DB.transaction(() async {
  ///   await DB.table('users').insert({...});
  ///   await DB.table('profiles').insert({...});
  /// });
  /// ```
  /// **A callback must not close the transaction itself**, and the two branches
  /// answer that differently on purpose.
  ///
  /// On failure the rollback is skipped. There is a real error in flight and
  /// the only thing that matters is that it reaches the caller: `rollback()`
  /// would find nothing to unwind and throw `cannot rollback - no transaction
  /// is active` over the top, so the caller would read a message about
  /// transactions in place of the cause.
  ///
  /// On success it throws instead, and skipping the commit the same way would
  /// be the worse bug. There is no error to protect here, so silence buys
  /// nothing and costs the signal: a callback that commits half way and keeps
  /// writing ran everything after that point outside any transaction, and
  /// returning normally tells the caller the block was atomic when it was not.
  /// `Migrator.run` treats the identical situation as an error worth naming
  /// the culprit for, and this is the same situation one layer down.
  ///
  /// `autocommit` on the connection is true exactly when no transaction is
  /// open, which is the only thing that can tell either case apart.
  static Future<T> transaction<T>(Future<T> Function() callback) async {
    beginTransaction();
    try {
      final result = await callback();

      if (_db.connection.autocommit) {
        throw StateError(
          'The transaction callback committed or rolled back the transaction '
          'itself. Anything it wrote afterwards ran outside a transaction and '
          'is not covered by this block. Remove the DB.commit or DB.rollback, '
          'or stop using DB.transaction and manage it manually throughout.',
        );
      }

      commit();

      return result;
    } catch (e) {
      if (!_db.connection.autocommit) rollback();
      rethrow;
    }
  }
}
