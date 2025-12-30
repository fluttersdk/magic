library;

/// Local Adapter - Conditional Export Router.
///
/// This file uses Dart's conditional exports to automatically
/// select the correct implementation based on the platform:
///
/// - **Mobile/Desktop**: Uses `local_adapter_io.dart` (dart:io)
/// - **Web**: Uses `local_adapter_web.dart` (package:web)
///
/// ## How It Works
///
/// The `dart.library.js_interop` condition is `true` on Web platforms,
/// allowing us to route to the Web-specific implementation without
/// importing `dart:io` which would crash the Web build.
export 'local_adapter_io.dart'
    if (dart.library.js_interop) 'local_adapter_web.dart';
