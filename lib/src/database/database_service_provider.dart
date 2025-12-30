import '../support/service_provider.dart';
import '../facades/log.dart';
import '../facades/config.dart';
import 'database_manager.dart';

/// Database Service Provider.
///
/// Registers the database manager as a singleton in the service container.
/// The database is initialized automatically during the boot phase.
class DatabaseServiceProvider extends ServiceProvider {
  /// Create a new database service provider.
  DatabaseServiceProvider(super.app);

  @override
  void register() {
    // Register the database manager as a singleton
    app.singleton('db', () => DatabaseManager());
  }

  @override
  Future<void> boot() async {
    // Initialize the database connection
    final db = app.make<DatabaseManager>('db');
    await db.init();

    final dbConfig = Config.get<Map<String, dynamic>>('database', {});
    final defaultConnection = dbConfig?['default'] ?? 'sqlite';

    Log.info('Database ready [$defaultConnection]');
  }
}
