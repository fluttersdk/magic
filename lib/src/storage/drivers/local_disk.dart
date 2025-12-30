import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../contracts/storage_disk.dart';
import '../magic_file.dart';
import 'local/local_adapter.dart';
import 'local/local_adapter_contract.dart';

/// The Local Disk Implementation.
///
/// This class implements the `StorageDisk` contract using the platform-specific
/// `LocalAdapter`. It handles input conversion and delegates to the adapter.
///
/// ## Input Handling
///
/// The `put()` method accepts multiple input types for convenience:
/// - `Uint8List` (preferred, used directly)
/// - `List<int>` (converted to `Uint8List`)
/// - `String` (UTF-8 encoded to `Uint8List`)
/// - `MagicFile` (uses the file's bytes)
///
/// ## Platform Transparency
///
/// Thanks to conditional exports, this class works identically on all platforms.
/// The `LocalAdapter` is automatically resolved to the correct implementation.
class LocalDisk implements StorageDisk {
  /// The underlying platform adapter.
  final LocalAdapterContract _adapter;

  /// Create a new Local Disk.
  ///
  /// [root] The root subfolder within the storage directory.
  LocalDisk({required String root}) : _adapter = LocalAdapter(root: root);

  /// Create a Local Disk with a custom adapter (for testing).
  LocalDisk.withAdapter(this._adapter);

  @override
  Future<String> put(String path, dynamic contents, {String? mimeType}) async {
    final bytes = await _toBytes(contents);
    final mime = mimeType ?? (contents is MagicFile ? contents.mimeType : null);
    return _adapter.write(path, bytes, mimeType: mime);
  }

  @override
  Future<Uint8List?> get(String path) {
    return _adapter.read(path);
  }

  @override
  Future<MagicFile?> getFile(String path) async {
    final bytes = await _adapter.read(path);
    if (bytes == null) return null;

    final name = p.basename(path);
    final ext = p.extension(name).replaceFirst('.', '').toLowerCase();

    return MagicFile(
      path: path,
      name: name,
      size: bytes.length,
      mimeType: _getMimeType(ext),
      bytes: bytes,
    );
  }

  @override
  Future<bool> exists(String path) {
    return _adapter.exists(path);
  }

  @override
  Future<bool> delete(String path) {
    return _adapter.delete(path);
  }

  @override
  Future<String> url(String path) {
    return _adapter.getUrl(path);
  }

  @override
  Future<void> download(String path, {String? name}) {
    return _adapter.download(path, name);
  }

  /// Convert various input types to Uint8List.
  Future<Uint8List> _toBytes(dynamic contents) async {
    if (contents is Uint8List) {
      return contents;
    }
    if (contents is List<int>) {
      return Uint8List.fromList(contents);
    }
    if (contents is String) {
      return Uint8List.fromList(utf8.encode(contents));
    }
    if (contents is MagicFile) {
      final bytes = await contents.readAsBytes();
      if (bytes == null) {
        throw ArgumentError('MagicFile has no bytes to store');
      }
      return bytes;
    }
    throw ArgumentError(
      'Storage contents must be Uint8List, List<int>, String, or MagicFile. '
      'Got: ${contents.runtimeType}',
    );
  }

  /// Get MIME type from extension.
  String? _getMimeType(String extension) {
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
