library;

/// Connection Factory - Platform Conditional Export.
///
/// This file automatically selects the correct connection factory implementation
/// based on the target platform:
///
/// - **Native (Android/iOS/Desktop)**: Uses `connection_factory_io.dart`
/// - **Web**: Uses `connection_factory_web.dart`
///
/// ## How It Works
///
/// Dart's conditional exports check for the presence of specific libraries:
/// - `dart.library.js_interop` is available only on Web
/// - Otherwise, the IO implementation is used
///
/// ## Web Setup Required
///
/// For Web support, you must download `sqlite3.wasm` from the
/// [sqlite3 package releases](https://github.com/nickreid94/sqlite3.dart/releases)
/// and place it in your project's `web/` folder.
///
/// ## Usage
///
/// ```dart
/// import 'package:magic/src/database/connectors/connection_factory.dart';
///
/// final factory = ConnectionFactory();
/// final db = await factory.connect({'database': 'my_app.db'});
/// ```
export 'connection_factory_io.dart'
    if (dart.library.js_interop) 'connection_factory_web.dart';
