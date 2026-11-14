import 'dart:typed_data';

import 'magic_file.dart';

/// Factory methods for creating MagicFile on Web platforms.
class MagicFileFactory {
  /// Create a MagicFile from bytes.
  ///
  /// This is the primary way to create a MagicFile on Web.
  ///
  /// ```dart
  /// final magicFile = MagicFileFactory.fromBytes(
  ///   bytes,
  ///   name: 'image.jpg',
  ///   mimeType: 'image/jpeg',
  /// );
  /// ```
  static MagicFile fromBytes(
    Uint8List bytes, {
    required String name,
    String? mimeType,
  }) {
    return MagicFile(
      name: name,
      size: bytes.length,
      mimeType: mimeType,
      bytes: bytes,
    );
  }
}
