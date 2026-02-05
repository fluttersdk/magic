/// MagicFile Extensions - Conditional Export Router.
///
/// This file uses Dart's conditional exports to automatically
/// select the correct implementation based on the platform:
///
/// - **Mobile/Desktop**: Uses `magic_file_io.dart` (dart:io File)
/// - **Web**: Uses `magic_file_web.dart` (XFile only)
///
/// ## Usage
///
/// ```dart
/// import 'package:magic/magic.dart';
///
/// // On IO platforms
/// final file = magicFile.toFile();
/// final xFile = magicFile.toXFile();
///
/// // From File (IO only)
/// final magicFile = await MagicFileFactory.fromFile(file);
///
/// // From XFile (all platforms)
/// final magicFile = await MagicFileFactory.fromXFile(xFile);
/// ```
library;

export 'magic_file_io.dart' if (dart.library.js_interop) 'magic_file_web.dart';
