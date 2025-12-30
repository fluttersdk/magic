import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'magic_file.dart';

/// IO-specific extensions for MagicFile.
///
/// These extensions provide conversion to/from `File` and `XFile`
/// on Mobile and Desktop platforms.
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

  /// Convert to an XFile (cross-platform file).
  ///
  /// XFile is used by image_picker and file_picker packages.
  ///
  /// ```dart
  /// final xFile = magicFile.toXFile();
  /// await Share.shareXFiles([xFile]);
  /// ```
  XFile toXFile() {
    if (path == null) {
      throw UnsupportedError(
        'Cannot convert to XFile: path is null. '
        'This MagicFile may have been created from bytes only.',
      );
    }
    return XFile(path!, name: name, mimeType: mimeType);
  }
}

/// Factory methods for creating MagicFile from File/XFile on IO platforms.
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
