import 'package:fluttersdk_magic/fluttersdk_magic.dart';

/// Database Configuration
///
/// Configures the SQLite database connection for the Magic framework.
///
/// Environment variables:
/// - `DB_CONNECTION`: Connection name (default: 'sqlite')
/// - `DB_DATABASE`: Database filename (default: 'magic_app.db')
Map<String, dynamic> get databaseConfig => {
  'database': {
    'default': env('DB_CONNECTION', 'sqlite'),
    'connections': {
      'sqlite': {
        'driver': 'sqlite',
        'database': env('DB_DATABASE', 'magic_app.db'),
        'prefix': '',
      },
    },
  },
};
