import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'local_adapter_contract.dart';

/// The Local Adapter for Mobile/Desktop (IO) platforms.
///
/// This adapter uses `dart:io` and `path_provider` to manage files
/// in the application's documents directory.
///
/// ## Storage Location
///
/// Files are stored in: `{AppDocumentsDir}/{root}/{path}`
///
/// For example, with root `storage`:
/// - iOS: `/var/mobile/.../Documents/storage/avatars/user.jpg`
/// - Android: `/data/data/.../files/storage/avatars/user.jpg`
class LocalAdapter implements LocalAdapterContract {
  /// The root subfolder within the documents directory.
  final String root;

  /// Cached base directory path.
  String? _basePath;

  /// Create a new Local Adapter for IO platforms.
  LocalAdapter({required this.root});

  /// Get the base directory path, creating it if needed.
  Future<String> _getBasePath() async {
    if (_basePath != null) return _basePath!;

    final docsDir = await getApplicationDocumentsDirectory();
    final baseDir = Directory(p.join(docsDir.path, root));

    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }

    _basePath = baseDir.path;
    return _basePath!;
  }

  /// Get the full path for a relative file path.
  Future<String> _getFullPath(String path) async {
    final base = await _getBasePath();
    return p.join(base, path);
  }

  @override
  Future<String> write(String path, Uint8List bytes, {String? mimeType}) async {
    final fullPath = await _getFullPath(path);
    final file = File(fullPath);

    // Ensure parent directory exists
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    await file.writeAsBytes(bytes);
    return fullPath;
  }

  @override
  Future<Uint8List?> read(String path) async {
    final fullPath = await _getFullPath(path);
    final file = File(fullPath);

    if (!await file.exists()) {
      return null;
    }

    return await file.readAsBytes();
  }

  @override
  Future<bool> exists(String path) async {
    final fullPath = await _getFullPath(path);
    return await File(fullPath).exists();
  }

  @override
  Future<bool> delete(String path) async {
    final fullPath = await _getFullPath(path);
    final file = File(fullPath);

    if (!await file.exists()) {
      return false;
    }

    await file.delete();
    return true;
  }

  @override
  Future<String> getUrl(String path) async {
    final fullPath = await _getFullPath(path);
    // Return file:// URI for consistency
    return 'file://$fullPath';
  }

  @override
  Future<void> download(String path, String? name) async {
    final fullPath = await _getFullPath(path);
    final file = File(fullPath);

    if (!await file.exists()) {
      throw Exception('File not found: $path');
    }

    await SharePlus.instance.share(
      ShareParams(files: [XFile(fullPath, name: name ?? p.basename(path))]),
    );
  }
}
