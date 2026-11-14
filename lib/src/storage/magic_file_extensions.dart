/// MagicFile Extensions - Conditional Export Router.
///
/// This file uses Dart's conditional exports to automatically
/// select the correct implementation based on the platform:
///
/// - **Mobile/Desktop**: Uses `magic_file_io.dart` (dart:io File)
/// - **Web**: Uses `magic_file_web.dart` (bytes only)
///
/// ## Usage
///
/// ```dart
/// import 'package:magic/magic.dart';
///
/// // To a dart:io File (IO only)
/// final file = magicFile.toFile();
///
/// // From a File (IO only)
/// final magicFile = await MagicFileFactory.fromFile(file);
///
/// // From bytes (Web)
/// final magicFile = MagicFileFactory.fromBytes(bytes, name: 'photo.jpg');
/// ```
library;

export 'magic_file_io.dart' if (dart.library.js_interop) 'magic_file_web.dart';
