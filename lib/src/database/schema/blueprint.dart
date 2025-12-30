import '../database_manager.dart';

/// Column definition for Blueprint.
///
/// Represents a single column in a table schema with its type, constraints,
/// and modifiers.
class ColumnDefinition {
  /// The column name.
  final String name;

  /// The SQLite column type.
  final String type;

  /// Whether the column can be null.
  bool isNullable = false;

  /// Whether this is a primary key.
  bool isPrimaryKey = false;

  /// Whether this column auto-increments.
  bool isAutoIncrement = false;

  /// Whether this column must be unique.
  bool isUnique = false;

  /// Default value for the column.
  dynamic defaultVal;

  /// Create a new column definition.
  ColumnDefinition(this.name, this.type);

  /// Mark this column as nullable.
  ColumnDefinition nullable() {
    isNullable = true;
    return this;
  }

  /// Mark this column as unique.
  ColumnDefinition unique() {
    isUnique = true;
    return this;
  }

  /// Set a default value for this column.
  ColumnDefinition defaultValue(dynamic value) {
    defaultVal = value;
    return this;
  }

  /// Generate the SQL for this column.
  String toSql() {
    final parts = <String>[name, type];

    if (isPrimaryKey) {
      parts.add('PRIMARY KEY');
    }

    if (isAutoIncrement) {
      parts.add('AUTOINCREMENT');
    }

    if (!isNullable && !isPrimaryKey) {
      parts.add('NOT NULL');
    }

    if (isUnique && !isPrimaryKey) {
      parts.add('UNIQUE');
    }

    if (defaultVal != null) {
      if (defaultVal is String) {
        parts.add("DEFAULT '$defaultVal'");
      } else if (defaultVal is bool) {
        parts.add('DEFAULT ${defaultVal ? 1 : 0}');
      } else {
        parts.add('DEFAULT $defaultVal');
      }
    }

    return parts.join(' ');
  }

  /// Generate ALTER TABLE ADD COLUMN SQL.
  String toAddColumnSql(String tableName) {
    return 'ALTER TABLE $tableName ADD COLUMN ${toSql()}';
  }
}

/// The Blueprint Class.
///
/// Provides a fluent API for defining table schemas programmatically.
/// Think of it as a Laravel migration's Schema facade.
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
/// ## Available Column Types
///
/// - `id()` - Auto-incrementing primary key
/// - `string(name, [length])` - VARCHAR/TEXT column
/// - `text(name)` - TEXT column for long content
/// - `integer(name)` - INTEGER column
/// - `bigInteger(name)` - INTEGER column (same in SQLite)
/// - `boolean(name)` - INTEGER column (0/1)
/// - `real(name)` - REAL/FLOAT column
/// - `blob(name)` - BLOB column for binary data
/// - `timestamps()` - created_at and updated_at columns
class Blueprint {
  /// The table name.
  final String tableName;

  /// Whether this is a modification blueprint (not create).
  final bool isModification;

  /// The column definitions (for CREATE or ADD).
  final List<ColumnDefinition> _columns = [];

  /// Columns to drop.
  final List<String> _columnsToDrop = [];

  /// Columns to rename (old name -> new name).
  final Map<String, String> _columnsToRename = {};

  /// Create a new blueprint for a table.
  Blueprint(this.tableName, {this.isModification = false});

  /// Add an auto-incrementing primary key column.
  ///
  /// ```dart
  /// table.id(); // Creates 'id' column
  /// table.id('user_id'); // Creates 'user_id' column
  /// ```
  ColumnDefinition id([String name = 'id']) {
    final col = ColumnDefinition(name, 'INTEGER')
      ..isPrimaryKey = true
      ..isAutoIncrement = true;
    _columns.add(col);
    return col;
  }

  /// Add a string (TEXT) column.
  ///
  /// ```dart
  /// table.string('name');
  /// table.string('email').unique();
  /// ```
  ColumnDefinition string(String name, [int? length]) {
    // SQLite doesn't enforce length, but we accept it for Laravel compatibility
    final col = ColumnDefinition(name, 'TEXT');
    _columns.add(col);
    return col;
  }

  /// Add a text column for long content.
  ///
  /// ```dart
  /// table.text('description');
  /// ```
  ColumnDefinition text(String name) {
    final col = ColumnDefinition(name, 'TEXT');
    _columns.add(col);
    return col;
  }

  /// Add an integer column.
  ///
  /// ```dart
  /// table.integer('age');
  /// table.integer('status').defaultValue(0);
  /// ```
  ColumnDefinition integer(String name) {
    final col = ColumnDefinition(name, 'INTEGER');
    _columns.add(col);
    return col;
  }

  /// Add a big integer column.
  ///
  /// Note: SQLite uses the same INTEGER type for all integer sizes.
  ColumnDefinition bigInteger(String name) {
    return integer(name);
  }

  /// Add a boolean column.
  ///
  /// SQLite stores booleans as INTEGER (0 or 1).
  ///
  /// ```dart
  /// table.boolean('is_active').defaultValue(true);
  /// ```
  ColumnDefinition boolean(String name) {
    final col = ColumnDefinition(name, 'INTEGER');
    _columns.add(col);
    return col;
  }

  /// Add a real (float) column.
  ///
  /// ```dart
  /// table.real('price');
  /// ```
  ColumnDefinition real(String name) {
    final col = ColumnDefinition(name, 'REAL');
    _columns.add(col);
    return col;
  }

  /// Add a blob column for binary data.
  ///
  /// ```dart
  /// table.blob('avatar');
  /// ```
  ColumnDefinition blob(String name) {
    final col = ColumnDefinition(name, 'BLOB');
    _columns.add(col);
    return col;
  }

  /// Add timestamp columns (created_at and updated_at).
  ///
  /// Both columns are nullable TEXT columns storing ISO 8601 strings.
  ///
  /// ```dart
  /// table.timestamps();
  /// ```
  void timestamps() {
    string('created_at').nullable();
    string('updated_at').nullable();
  }

  /// Drop a column from the table.
  ///
  /// Note: SQLite has limited ALTER TABLE support. Dropping columns requires
  /// SQLite 3.35.0+ (2021). On older versions, this may fail.
  ///
  /// ```dart
  /// Schema.table('users', (table) {
  ///   table.dropColumn('legacy_field');
  /// });
  /// ```
  void dropColumn(String name) {
    _columnsToDrop.add(name);
  }

  /// Rename a column.
  ///
  /// Note: Requires SQLite 3.25.0+ (2018).
  ///
  /// ```dart
  /// Schema.table('users', (table) {
  ///   table.renameColumn('name', 'full_name');
  /// });
  /// ```
  void renameColumn(String from, String to) {
    _columnsToRename[from] = to;
  }

  /// Generate the CREATE TABLE SQL statement.
  String toSql() {
    final columnsSql = _columns.map((col) => col.toSql()).join(', ');
    return 'CREATE TABLE IF NOT EXISTS $tableName ($columnsSql)';
  }

  /// Execute the CREATE TABLE statement.
  void execute() {
    if (isModification) {
      _executeModifications();
    } else {
      final sql = toSql();
      DatabaseManager().connection.execute(sql);
      DatabaseManager().clearSchemaCache(tableName);
    }
  }

  /// Execute table modifications (ALTER TABLE statements).
  void _executeModifications() {
    final db = DatabaseManager();

    // Add new columns
    for (final col in _columns) {
      final sql = col.toAddColumnSql(tableName);
      db.connection.execute(sql);
    }

    // Rename columns
    for (final entry in _columnsToRename.entries) {
      final sql =
          'ALTER TABLE $tableName RENAME COLUMN ${entry.key} TO ${entry.value}';
      db.connection.execute(sql);
    }

    // Drop columns
    for (final colName in _columnsToDrop) {
      final sql = 'ALTER TABLE $tableName DROP COLUMN $colName';
      db.connection.execute(sql);
    }

    db.clearSchemaCache(tableName);
  }
}
