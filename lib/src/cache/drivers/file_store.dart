/// Native File-based Cache Driver.
library;

///
/// This file conditionally exports the correct implementation
/// based on the platform (IO vs Web).
export 'file_store_io.dart' if (dart.library.js_interop) 'file_store_web.dart';
