import 'dart:convert';

import 'package:sqlite3/common.dart';

import '../database_manager.dart';
import '../../support/carbon.dart';

/// Laravel-style Query Builder.
///
/// Provides a fluent API for building and executing SQL queries. The builder
/// is schema-aware and will automatically filter insert/update data to only
/// include columns that exist in the table.
///
/// ## Getting Started
///
/// ```dart
/// // Get all users
/// final users = await DB.table('users').get();
///
/// // Get first user matching condition
/// final user = await DB.table('users').where('id', 1).first();
/// ```
///
/// ## Selecting Data
///
/// ```dart
/// // Select specific columns
/// final names = await DB.table('users')
///   .select(['name', 'email'])
///   .get();
///
/// // With conditions
/// final activeUsers = await DB.table('users')
///   .where('is_active', true)
///   .where('role', 'admin')
///   .get();
///
/// // With ordering and limits
/// final recent = await DB.table('posts')
///   .orderBy('created_at', 'desc')
///   .limit(10)
///   .get();
/// ```
///
/// ## Inserting Data
///
/// ```dart
/// // Insert single record
/// await DB.table('users').insert({
///   'name': 'John Doe',
///   'email': 'john@example.com',
/// });
///
/// // Schema-aware: unknown columns are automatically filtered out
/// await DB.table('users').insert({
///   'name': 'Jane',
///   'unknown_field': 'ignored', // Won't cause error
/// });
/// ```
///
/// ## Updating Data
///
/// ```dart
/// await DB.table('users')
///   .where('id', 1)
///   .update({'name': 'Updated Name'});
/// ```
///
/// ## Deleting Data
///
/// ```dart
/// await DB.table('users')
///   .where('id', 1)
///   .delete();
/// ```
class QueryBuilder {
  /// The table name.
  final String _table;

  /// Selected columns (null means all).
  List<String>? _selectColumns;

  /// Where clauses.
  final List<_WhereClause> _wheres = [];

  /// Order by clauses.
  final List<_OrderClause> _orders = [];

  /// Limit value.
  int? _limitValue;

  /// Offset value.
  int? _offsetValue;

  /// Create a new query builder for a table.
  QueryBuilder(this._table);

  /// Get the database manager.
  DatabaseManager get _db => DatabaseManager();

  /// Select specific columns.
  ///
  /// ```dart
  /// DB.table('users').select(['name', 'email']).get();
  /// ```
  QueryBuilder select(List<String> columns) {
    _selectColumns = columns;
    return this;
  }

  /// Add a where clause.
  ///
  /// ```dart
  /// // Equality
  /// DB.table('users').where('id', 1);
  ///
  /// // With operator
  /// DB.table('users').where('age', '>=', 18);
  /// ```
  QueryBuilder where(String column, dynamic operatorOrValue, [dynamic value]) {
    String operator;
    dynamic actualValue;

    if (value == null) {
      operator = '=';
      actualValue = operatorOrValue;
    } else {
      operator = operatorOrValue as String;
      actualValue = value;
    }

    _wheres.add(_WhereClause(column, operator, actualValue));
    return this;
  }

  /// Add a where null clause.
  ///
  /// ```dart
  /// DB.table('users').whereNull('deleted_at');
  /// ```
  QueryBuilder whereNull(String column) {
    _wheres.add(_WhereClause(column, 'IS', null, isNull: true));
    return this;
  }

  /// Add a where not null clause.
  ///
  /// ```dart
  /// DB.table('users').whereNotNull('email');
  /// ```
  QueryBuilder whereNotNull(String column) {
    _wheres.add(_WhereClause(column, 'IS NOT', null, isNull: true));
    return this;
  }

  /// Add an order by clause.
  ///
  /// ```dart
  /// DB.table('posts').orderBy('created_at', 'desc');
  /// ```
  QueryBuilder orderBy(String column, [String direction = 'asc']) {
    _orders.add(_OrderClause(column, direction.toUpperCase()));
    return this;
  }

  /// Limit the number of results.
  ///
  /// ```dart
  /// DB.table('posts').limit(10);
  /// ```
  QueryBuilder limit(int count) {
    _limitValue = count;
    return this;
  }

  /// Offset the results.
  ///
  /// ```dart
  /// DB.table('posts').limit(10).offset(20); // Page 3
  /// ```
  QueryBuilder offset(int count) {
    _offsetValue = count;
    return this;
  }

  /// Execute the query and get all results.
  ///
  /// ```dart
  /// final users = await DB.table('users').get();
  /// for (final user in users) {
  ///   print(user['name']);
  /// }
  /// ```
  Future<List<Map<String, dynamic>>> get() async {
    final sql = _buildSelectSql();
    final params = _buildWhereParams();

    final ResultSet result = _db.connection.select(sql, params);
    return _resultSetToList(result);
  }

  /// Get the first result.
  ///
  /// ```dart
  /// final user = await DB.table('users').where('id', 1).first();
  /// if (user != null) {
  ///   print(user['name']);
  /// }
  /// ```
  Future<Map<String, dynamic>?> first() async {
    _limitValue = 1;
    final results = await get();
    return results.isEmpty ? null : results.first;
  }

  /// Get a single value from the first result.
  ///
  /// ```dart
  /// final name = await DB.table('users')
  ///   .where('id', 1)
  ///   .value<String>('name');
  /// ```
  Future<T?> value<T>(String column) async {
    _selectColumns = [column];
    final row = await first();
    return row?[column] as T?;
  }

  /// Get a list of values for a single column.
  ///
  /// ```dart
  /// final emails = await DB.table('users').pluck<String>('email');
  /// ```
  Future<List<T>> pluck<T>(String column) async {
    _selectColumns = [column];
    final results = await get();
    return results.map((row) => row[column] as T).toList();
  }

  /// Count the number of matching rows.
  ///
  /// ```dart
  /// final count = await DB.table('users').where('is_active', true).count();
  /// ```
  Future<int> count() async {
    final sql = _buildCountSql();
    final params = _buildWhereParams();
    final result = _db.connection.select(sql, params);
    return result.first['count'] as int;
  }

  /// Check if any rows exist matching the query.
  ///
  /// ```dart
  /// if (await DB.table('users').where('email', email).exists()) {
  ///   throw Exception('Email already in use');
  /// }
  /// ```
  Future<bool> exists() async {
    return await count() > 0;
  }

  /// Insert a new record (schema-aware).
  ///
  /// Unknown columns are automatically filtered out to prevent errors when
  /// the API returns fields that don't exist in the local database.
  ///
  /// ```dart
  /// await DB.table('users').insert({
  ///   'name': 'John',
  ///   'email': 'john@example.com',
  /// });
  /// ```
  Future<int> insert(Map<String, dynamic> data) async {
    // Filter data to only include existing columns
    final filteredData = await _filterDataBySchema(data);

    if (filteredData.isEmpty) {
      return 0;
    }

    final columns = filteredData.keys.join(', ');
    final placeholders = List.filled(filteredData.length, '?').join(', ');
    final values = filteredData.values.toList();

    final sql = 'INSERT INTO $_table ($columns) VALUES ($placeholders)';
    _db.connection.execute(sql, _prepareValues(values));

    // Return last insert ID
    final result = _db.connection.select('SELECT last_insert_rowid() as id');
    return result.first['id'] as int;
  }

  /// Insert multiple records.
  ///
  /// ```dart
  /// await DB.table('users').insertAll([
  ///   {'name': 'John', 'email': 'john@example.com'},
  ///   {'name': 'Jane', 'email': 'jane@example.com'},
  /// ]);
  /// ```
  Future<void> insertAll(List<Map<String, dynamic>> records) async {
    for (final record in records) {
      await insert(record);
    }
  }

  /// Update records matching the query (schema-aware).
  ///
  /// ```dart
  /// await DB.table('users')
  ///   .where('id', 1)
  ///   .update({'name': 'Updated Name'});
  /// ```
  Future<int> update(Map<String, dynamic> data) async {
    // Filter data to only include existing columns
    final filteredData = await _filterDataBySchema(data);

    if (filteredData.isEmpty) {
      return 0;
    }

    final setClauses = filteredData.keys.map((col) => '$col = ?').join(', ');
    final values = filteredData.values.toList();

    final whereSql = _buildWhereSql();
    final whereParams = _buildWhereParams();

    final sql = 'UPDATE $_table SET $setClauses$whereSql';
    _db.connection.execute(sql, [..._prepareValues(values), ...whereParams]);

    // Return affected rows
    final result = _db.connection.select('SELECT changes() as count');
    return result.first['count'] as int;
  }

  /// Delete records matching the query.
  ///
  /// ```dart
  /// await DB.table('users').where('id', 1).delete();
  /// ```
  Future<int> delete() async {
    final whereSql = _buildWhereSql();
    final whereParams = _buildWhereParams();

    final sql = 'DELETE FROM $_table$whereSql';
    _db.connection.execute(sql, whereParams);

    // Return affected rows
    final result = _db.connection.select('SELECT changes() as count');
    return result.first['count'] as int;
  }

  /// Truncate the table (delete all rows).
  ///
  /// ```dart
  /// await DB.table('logs').truncate();
  /// ```
  Future<void> truncate() async {
    _db.connection.execute('DELETE FROM $_table');
  }

  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------

  /// Build the SELECT SQL statement.
  String _buildSelectSql() {
    final columns = _selectColumns?.join(', ') ?? '*';
    final buffer = StringBuffer('SELECT $columns FROM $_table');

    buffer.write(_buildWhereSql());
    buffer.write(_buildOrderSql());
    buffer.write(_buildLimitSql());

    return buffer.toString();
  }

  /// Build the COUNT SQL statement.
  String _buildCountSql() {
    final buffer = StringBuffer('SELECT COUNT(*) as count FROM $_table');
    buffer.write(_buildWhereSql());
    return buffer.toString();
  }

  /// Build the WHERE clause.
  String _buildWhereSql() {
    if (_wheres.isEmpty) return '';

    final clauses = _wheres.map((w) {
      if (w.isNull) {
        return '${w.column} ${w.operator} NULL';
      }
      return '${w.column} ${w.operator} ?';
    }).join(' AND ');

    return ' WHERE $clauses';
  }

  /// Get the WHERE parameter values.
  List<Object?> _buildWhereParams() {
    return _wheres
        .where((w) => !w.isNull)
        .map((w) => _prepareValue(w.value))
        .toList();
  }

  /// Build the ORDER BY clause.
  String _buildOrderSql() {
    if (_orders.isEmpty) return '';
    final clauses = _orders.map((o) => '${o.column} ${o.direction}').join(', ');
    return ' ORDER BY $clauses';
  }

  /// Build the LIMIT/OFFSET clause.
  String _buildLimitSql() {
    final buffer = StringBuffer();
    if (_limitValue != null) {
      buffer.write(' LIMIT $_limitValue');
    }
    if (_offsetValue != null) {
      buffer.write(' OFFSET $_offsetValue');
    }
    return buffer.toString();
  }

  /// Filter data map to only include columns that exist in the table.
  Future<Map<String, dynamic>> _filterDataBySchema(
      Map<String, dynamic> data) async {
    final columns = await _db.getColumns(_table);
    final filtered = <String, dynamic>{};

    for (final entry in data.entries) {
      if (columns.contains(entry.key)) {
        filtered[entry.key] = entry.value;
      }
    }

    return filtered;
  }

  /// Convert ResultSet to List of Maps.
  List<Map<String, dynamic>> _resultSetToList(ResultSet result) {
    return result.map((row) {
      final map = <String, dynamic>{};
      for (final col in result.columnNames) {
        map[col] = row[col];
      }
      return map;
    }).toList();
  }

  /// Prepare a value for SQLite (convert booleans, etc.).
  Object? _prepareValue(dynamic value) {
    if (value is bool) {
      return value ? 1 : 0;
    }
    if (value is Carbon) {
      return value.toIso8601String();
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is Map || value is List) {
      return jsonEncode(value);
    }
    return value;
  }

  /// Prepare multiple values.
  List<Object?> _prepareValues(List<dynamic> values) {
    return values.map(_prepareValue).toList();
  }
}

/// Internal where clause representation.
class _WhereClause {
  final String column;
  final String operator;
  final dynamic value;
  final bool isNull;

  _WhereClause(this.column, this.operator, this.value, {this.isNull = false});
}

/// Internal order clause representation.
class _OrderClause {
  final String column;
  final String direction;

  _OrderClause(this.column, this.direction);
}
