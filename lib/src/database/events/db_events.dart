import '../../events/magic_event.dart';

/// Fired when a database connection is established.
class DatabaseConnected extends MagicEvent {
  /// The name of the connection (e.g., 'sqlite', 'mysql').
  final String connectionName;

  DatabaseConnected(this.connectionName);
}

/// Fired when a database query is executed.
///
/// Use this for debugging or profiling.
class QueryExecuted extends MagicEvent {
  /// The SQL query string.
  final String sql;

  /// The bindings/parameters used in the query.
  final List<dynamic> bindings;

  /// The time taken to execute the query in milliseconds.
  final int timeMs;

  /// The connection name.
  final String connectionName;

  QueryExecuted({
    required this.sql,
    required this.bindings,
    required this.timeMs,
    this.connectionName = 'default',
  });
}
