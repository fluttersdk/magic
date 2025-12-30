/// Database configuration for the Magic framework.
///
/// This configuration defines the default database connection and available
/// drivers. By default, Magic uses SQLite with local file storage.
///
/// ## Usage
///
/// Include this config in your `Magic.init()` call:
///
/// ```dart
/// await Magic.init(configs: [databaseConfig]);
/// ```
///
/// ## Environment Variables
///
/// You can override settings using environment variables:
/// - `DB_CONNECTION`: The default connection name (default: 'sqlite')
/// - `DB_DATABASE`: The database filename (default: 'magic_app.db')
Map<String, dynamic> defaultDatabaseConfig = {
  'database': {
    'default': 'sqlite',
    'connections': {
      'sqlite': {
        'driver': 'sqlite',
        'database': 'magic_app.db',
        'prefix': '',
      }
    }
  }
};
