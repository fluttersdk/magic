import 'package:sqlite3/common.dart';

/// The Connection Factory Contract.
///
/// Defines the interface for database connection factories. Each platform
/// (Native/Web) implements this contract to provide the appropriate database
/// connection mechanism.
///
/// ## Implementation Notes
///
/// - **Native (IO)**: Uses `sqlite3.open()` with file path from `path_provider`
/// - **Web (WASM)**: Uses `WasmSqlite3` with `IndexedDbFileSystem`
///
/// The correct implementation is automatically selected at compile time using
/// Dart's conditional imports.
abstract class ConnectionFactoryContract {
  /// Connect to the database using the provided configuration.
  ///
  /// [config] should contain at minimum:
  /// - `database`: The database name/filename
  ///
  /// Returns a [CommonDatabase] instance that works on both platforms.
  Future<CommonDatabase> connect(Map<String, dynamic> config);
}
