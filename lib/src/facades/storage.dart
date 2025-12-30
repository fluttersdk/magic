import 'dart:typed_data';

import '../storage/contracts/storage_disk.dart';
import '../storage/magic_file.dart';
import '../storage/storage_manager.dart';

/// The Storage Facade.
///
/// Provides a clean, static API for file storage operations.
/// Mimics Laravel's `Storage` facade for familiarity.
///
/// ## Quick Start
///
/// ```dart
/// // Store a file
/// await Storage.put('avatars/user.jpg', bytes, mimeType: 'image/jpeg');
///
/// // Retrieve a file as MagicFile
/// final file = await Storage.getFile('avatars/user.jpg');
///
/// // Get a displayable URL
/// final url = await Storage.url('avatars/user.jpg');
/// Image.network(url); // Works on all platforms!
///
/// // Check if file exists
/// if (await Storage.exists('avatars/user.jpg')) { ... }
///
/// // Delete a file
/// await Storage.delete('avatars/user.jpg');
/// ```
///
/// ## Using Specific Disks
///
/// ```dart
/// // Use the public disk
/// await Storage.disk('public').put('uploads/file.pdf', bytes);
/// ```
///
/// ## Platform Behavior
///
/// | Method | Mobile/Desktop | Web |
/// |--------|----------------|-----|
/// | `put()` | Writes to file system | Stores in SharedPreferences (Base64) |
/// | `url()` | Returns `file://` path | Returns `blob:` URL |
/// | `download()` | Opens share sheet | Triggers browser download |
class Storage {
  /// The storage manager instance.
  static StorageManager? _manager;

  /// Get the storage manager instance.
  static StorageManager get _instance {
    _manager ??= StorageManager();
    return _manager!;
  }

  /// Set a custom storage manager (for testing).
  static void setManager(StorageManager manager) {
    _manager = manager;
  }

  /// Get a storage disk by name.
  ///
  /// If [name] is null, returns the default disk.
  ///
  /// ```dart
  /// final publicDisk = Storage.disk('public');
  /// await publicDisk.put('file.txt', 'Hello');
  /// ```
  static StorageDisk disk([String? name]) {
    return _instance.disk(name);
  }

  /// Store contents at the given path.
  ///
  /// **Parameters:**
  /// - [path]: The relative path where the file should be stored.
  /// - [contents]: The file contents (`Uint8List`, `List<int>`, `String`, or `MagicFile`).
  /// - [mimeType]: Optional MIME type (important for Web Blob URLs).
  ///
  /// **Returns:** The full path or URL where the file was stored.
  ///
  /// ```dart
  /// // Store image bytes
  /// await Storage.put('avatars/user.jpg', bytes, mimeType: 'image/jpeg');
  ///
  /// // Store a MagicFile from Pick
  /// final image = await Pick.image();
  /// await Storage.put('avatars/user.jpg', image);
  /// ```
  static Future<String> put(
    String path,
    dynamic contents, {
    String? mimeType,
  }) {
    return disk().put(path, contents, mimeType: mimeType);
  }

  /// Retrieve file contents as bytes.
  ///
  /// **Returns:** The file contents as `Uint8List`, or `null` if not found.
  ///
  /// ```dart
  /// final bytes = await Storage.get('avatars/user.jpg');
  /// if (bytes != null) {
  ///   // Use the bytes
  /// }
  /// ```
  static Future<Uint8List?> get(String path) {
    return disk().get(path);
  }

  /// Retrieve a file as a MagicFile.
  ///
  /// This is the preferred method for retrieving files as it returns a
  /// `MagicFile` with all metadata and helper methods available.
  ///
  /// **Returns:** A `MagicFile` or `null` if not found.
  ///
  /// ```dart
  /// final file = await Storage.getFile('avatar.jpg');
  /// if (file != null) {
  ///   print(file.name);       // 'avatar.jpg'
  ///   print(file.isImage);    // true
  ///   final bytes = await file.readAsBytes();
  /// }
  /// ```
  static Future<MagicFile?> getFile(String path) {
    return disk().getFile(path);
  }

  /// Check if a file exists at the given path.
  ///
  /// ```dart
  /// if (await Storage.exists('avatars/user.jpg')) {
  ///   print('Avatar exists!');
  /// }
  /// ```
  static Future<bool> exists(String path) {
    return disk().exists(path);
  }

  /// Delete a file at the given path.
  ///
  /// **Returns:** `true` if the file was deleted, `false` otherwise.
  ///
  /// ```dart
  /// await Storage.delete('avatars/user.jpg');
  /// ```
  static Future<bool> delete(String path) {
    return disk().delete(path);
  }

  /// Get a URL for the file.
  ///
  /// This method returns a URL that can be used to display or access the file:
  /// - **Mobile/Desktop**: Returns a `file://` path.
  /// - **Web**: Returns a `blob:` URL for use in `Image.network()`.
  ///
  /// ```dart
  /// final url = await Storage.url('avatars/user.jpg');
  /// Image.network(url); // Works on all platforms!
  /// ```
  static Future<String> url(String path) {
    return disk().url(path);
  }

  /// Trigger a download of the file.
  ///
  /// - **Mobile**: Opens share sheet.
  /// - **Web**: Triggers browser download dialog.
  ///
  /// ```dart
  /// await Storage.download('reports/monthly.pdf', name: 'report.pdf');
  /// ```
  static Future<void> download(String path, {String? name}) {
    return disk().download(path, name: name);
  }

  /// Flush the storage manager (for testing).
  static void flush() {
    _manager?.flush();
    _manager = null;
  }
}
