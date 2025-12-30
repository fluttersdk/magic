import 'package:sqlite3/wasm.dart';

import 'connection_factory_contract.dart';

/// Web Connection Factory (WASM).
///
/// This factory creates SQLite database connections for web platforms using
/// the WASM-compiled SQLite library with IndexedDB for persistence.
///
/// ## Setup Required
///
/// You must download `sqlite3.wasm` from the
/// [sqlite3 package releases](https://github.com/nickreid94/sqlite3.dart/releases)
/// and place it in your project's `web/` folder.
///
/// ## How It Works
///
/// 1. Loads the SQLite WASM binary from `sqlite3.wasm`
/// 2. Creates an IndexedDB-backed virtual file system
/// 3. Registers the file system as the default
/// 4. Opens the database with persistence
///
/// ## Example
///
/// ```dart
/// final factory = ConnectionFactory();
/// final db = await factory.connect({'database': 'my_app.db'});
/// ```
class ConnectionFactory implements ConnectionFactoryContract {
  /// Cached SQLite3 WASM instance.
  static WasmSqlite3? _sqlite3;

  /// Cached file system instance.
  static IndexedDbFileSystem? _fileSystem;

  @override
  Future<CommonDatabase> connect(Map<String, dynamic> config) async {
    final dbName = config['database'] as String? ?? 'magic_app.db';

    // Load WASM if not already loaded
    _sqlite3 ??= await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));

    // Setup IndexedDB file system if not already setup
    if (_fileSystem == null) {
      _fileSystem = await IndexedDbFileSystem.open(dbName: dbName);
      _sqlite3!.registerVirtualFileSystem(_fileSystem!, makeDefault: true);
    }

    // Open and return the database
    return _sqlite3!.open(dbName);
  }
}
