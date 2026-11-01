/// Network images kept on the device: `MagicImage` draws one, `MagicImageCache`
/// holds the files, and the store and wire behind it are exported for a test
/// or an app that wants them. The web has `MagicImage` alone, as a plain
/// `NetworkImage`.
library;

export 'images_io.dart' if (dart.library.js_interop) 'images_web.dart';
