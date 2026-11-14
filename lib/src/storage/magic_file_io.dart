import 'dart:io';

import 'package:path/path.dart' as p;

import 'magic_file.dart';

/// IO-specific extensions for MagicFile.
///
/// These extensions provide conversion to a `dart:io` `File` on Mobile and
/// Desktop platforms.
extension MagicFileIOExtensions on MagicFile {
  /// Convert to a dart:io File.
  ///
  /// **Note:** Requires a valid [path]. On Web, this will throw.
  ///
  /// ```dart
  /// final file = await magicFile.toFile();
  /// await file.copy('/backup/file.jpg');
  /// ```
  File toFile() {
    if (path == null) {
      throw UnsupportedError(
        'Cannot convert to File: path is null. '
        'This MagicFile may have been created from bytes only.',
      );
    }
    return File(path!);
  }
}

/// Factory methods for creating MagicFile from a File on IO platforms.
class MagicFileFactory {
  /// Create a MagicFile from a dart:io File.
  ///
  /// ```dart
  /// final file = File('/path/to/image.jpg');
  /// final magicFile = await MagicFileFactory.fromFile(file);
  /// await magicFile.store('uploads/image.jpg');
  /// ```
  static Future<MagicFile> fromFile(File file, {String? mimeType}) async {
    final name = p.basename(file.path);
    final ext = p.extension(name).replaceFirst('.', '').toLowerCase();
    final stat = await file.stat();

    return MagicFile(
      path: file.path,
      name: name,
      size: stat.size,
      mimeType: mimeType ?? _getMimeType(ext),
      bytesReader: () => file.readAsBytes(),
    );
  }

  /// Get MIME type from extension.
  static String? _getMimeType(String extension) {
    const mimeTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'bmp': 'image/bmp',
      'heic': 'image/heic',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'avi': 'video/x-msvideo',
      'pdf': 'application/pdf',
      'txt': 'text/plain',
      'json': 'application/json',
    };
    return mimeTypes[extension];
  }
}
