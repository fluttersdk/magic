import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'magic_file.dart';

/// Web-specific extensions for MagicFile.
///
/// On Web, `dart:io` File is not available. These extensions provide
/// limited functionality using only `XFile` and bytes.
extension MagicFileWebExtensions on MagicFile {
  /// Convert to an XFile (cross-platform file).
  ///
  /// On Web, this creates an XFile from the file's bytes.
  ///
  /// ```dart
  /// final xFile = await magicFile.toXFile();
  /// ```
  Future<XFile> toXFile() async {
    final bytes = await readAsBytes();
    if (bytes == null) {
      throw UnsupportedError(
        'Cannot convert to XFile: no bytes available.',
      );
    }

    // Create XFile from bytes on Web
    return XFile.fromData(
      bytes,
      name: name,
      mimeType: mimeType,
    );
  }
}

/// Factory methods for creating MagicFile from XFile on Web platforms.
class MagicFileFactory {
  /// Create a MagicFile from an XFile.
  ///
  /// ```dart
  /// final xFile = await picker.pickImage(source: ImageSource.gallery);
  /// final magicFile = await MagicFileFactory.fromXFile(xFile);
  /// await magicFile.store('photos/image.jpg');
  /// ```
  static Future<MagicFile> fromXFile(XFile xFile) async {
    final length = await xFile.length();

    return MagicFile(
      path: xFile.path,
      name: xFile.name,
      size: length,
      mimeType: xFile.mimeType,
      bytesReader: () => xFile.readAsBytes(),
    );
  }

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
