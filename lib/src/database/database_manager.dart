import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sqlite3/common.dart';

import '../facades/config.dart';
import 'connectors/connection_factory.dart';
import '../facades/event.dart';
import 'events/db_events.dart';

/// The Database Manager.
///
/// This singleton service manages the active database connection. It reads
/// configuration from the app config and uses the appropriate connection
/// factory based on the platform.
///
/// ## Initialization
///
/// The database is automatically initialized during [Magic.init()]. You can
/// also initialize it manually:
///
/// ```dart
/// await DatabaseManager().init();
/// ```
///
/// ## Accessing the Connection
///
/// ```dart
/// final db = DatabaseManager().connection;
/// final result = db.select('SELECT * FROM users');
/// ```
///
/// ## Schema Cache
///
/// The manager caches table column information for schema-aware operations:
///
/// ```dart
/// final columns = await DatabaseManager().getColumns('users');
/// // ['id', 'name', 'email', 'created_at', 'updated_at']
/// ```
class DatabaseManager {
  /// Singleton instance.
  static final DatabaseManager _instance = DatabaseManager._internal();

  /// Factory constructor returns the singleton.
  factory DatabaseManager() => _instance;

  /// Private constructor.
  DatabaseManager._internal();

  /// The active database connection.
  CommonDatabase? _connection;

  /// Schema cache: table name -> list of column names.
  final Map<String, List<String>> _schemaCache = {};

  /// Whether the database has been initialized.
  bool get isInitialized => _connection != null;

  /// Get the active database connection.
  ///
  /// Throws if the database has not been initialized.
  CommonDatabase get connection {
    if (_connection == null) {
      throw StateError(
        'Database not initialized. Call DatabaseManager().init() first, '
        'or ensure Magic.init() has completed.',
      );
    }
    return _connection!;
  }

  /// Inject a mock connection for testing.
  ///
  /// This allows tests to use an in-memory database without relying on
  /// platform-specific file systems or paths.
  @visibleForTesting
  void setConnection(CommonDatabase connection) {
    _connection = connection;
  }

  /// Initialize the database connection.
  ///
  /// Reads configuration from the app config and establishes a connection
  /// using the appropriate platform-specific factory.
  Future<void> init() async {
    if (_connection != null) {
      return; // Already initialized
    }

    // Get configuration
    final defaultConnection =
        Config.get<String>('database.default', 'sqlite') ?? 'sqlite';
    final connections =
        Config.get<Map<String, dynamic>>('database.connections') ?? {};
    final connectionConfig =
        connections[defaultConnection] as Map<String, dynamic>? ?? {};

    // Connect using the platform-specific factory
    final factory = ConnectionFactory();
    _connection = await factory.connect(connectionConfig);

    await Event.dispatch(DatabaseConnected(defaultConnection));
  }

  /// Get the column names for a table.
  ///
  /// Results are cached for performance. Use [clearSchemaCache] to refresh.
  Future<List<String>> getColumns(String table) async {
    // Return cached if available
    if (_schemaCache.containsKey(table)) {
      return _schemaCache[table]!;
    }

    // Query table info using PRAGMA
    final result = connection.select('PRAGMA table_info($table)');

    // Extract column names (column 1 is 'name')
    final columns = result.map((row) => row['name'] as String).toList();

    // Cache and return
    _schemaCache[table] = columns;
    return columns;
  }

  /// Check if a table has a specific column.
  Future<bool> hasColumn(String table, String column) async {
    final columns = await getColumns(table);
    return columns.contains(column);
  }

  /// Clear the schema cache for a specific table or all tables.
  void clearSchemaCache([String? table]) {
    if (table != null) {
      _schemaCache.remove(table);
    } else {
      _schemaCache.clear();
    }
  }

  /// Close the database connection.
  void dispose() {
    _connection?.close();
    _connection = null;
    _schemaCache.clear();
  }
}
