import 'dart:typed_data';

import '../magic_file.dart';

/// The Storage Disk Contract.
///
/// This contract defines the interface for all storage disk implementations.
/// Each disk driver (local, s3, etc.) must implement this contract.
///
/// ## Philosophy
///
/// The Magic Storage system is **binary-first**. All operations internally
/// work with `Uint8List` to support images, PDFs, and other binary files
/// seamlessly across Mobile, Desktop, and Web platforms.
///
/// ## Example
///
/// ```dart
/// // Store a file
/// await disk.put('avatars/user.jpg', imageBytes, mimeType: 'image/jpeg');
///
/// // Retrieve a file as MagicFile
/// final file = await disk.getFile('avatars/user.jpg');
///
/// // Get URL for display
/// final url = await disk.url('avatars/user.jpg');
/// // Mobile: file:///path/to/file
/// // Web: blob:http://localhost/uuid
/// ```
abstract class StorageDisk {
  /// Store contents at the given path.
  ///
  /// **Parameters:**
  /// - [path]: The relative path where the file should be stored.
  /// - [contents]: The file contents. Can be:
  ///   - `Uint8List` (preferred)
  ///   - `List<int>` (will be converted)
  ///   - `String` (will be UTF-8 encoded)
  ///   - `MagicFile` (uses the file's bytes)
  /// - [mimeType]: Optional MIME type (important for Web Blob URLs).
  ///
  /// **Returns:** The full path or URL where the file was stored.
  ///
  /// ```dart
  /// final path = await disk.put('avatar.jpg', bytes, mimeType: 'image/jpeg');
  /// ```
  Future<String> put(String path, dynamic contents, {String? mimeType});

  /// Retrieve file contents as bytes.
  ///
  /// **Returns:** The file contents as `Uint8List`, or `null` if not found.
  ///
  /// ```dart
  /// final bytes = await disk.get('avatar.jpg');
  /// if (bytes != null) {
  ///   // Use the bytes
  /// }
  /// ```
  Future<Uint8List?> get(String path);

  /// Retrieve a file as a MagicFile.
  ///
  /// This is the preferred method for retrieving files as it returns a
  /// `MagicFile` with all metadata and helper methods available.
  ///
  /// **Returns:** A `MagicFile` or `null` if not found.
  ///
  /// ```dart
  /// final file = await disk.getFile('avatar.jpg');
  /// if (file != null) {
  ///   print(file.name);       // 'avatar.jpg'
  ///   print(file.isImage);    // true
  ///   final bytes = await file.readAsBytes();
  /// }
  /// ```
  Future<MagicFile?> getFile(String path);

  /// Check if a file exists at the given path.
  ///
  /// ```dart
  /// if (await disk.exists('avatar.jpg')) {
  ///   // File exists
  /// }
  /// ```
  Future<bool> exists(String path);

  /// Delete a file at the given path.
  ///
  /// **Returns:** `true` if the file was deleted, `false` otherwise.
  ///
  /// ```dart
  /// await disk.delete('avatar.jpg');
  /// ```
  Future<bool> delete(String path);

  /// Get a URL for the file.
  ///
  /// This method returns a URL that can be used to display or access the file:
  /// - **Mobile/Desktop**: Returns a `file://` path.
  /// - **Web**: Returns a `blob:` URL that can be used in `Image.network()`.
  ///
  /// ```dart
  /// final url = await disk.url('avatar.jpg');
  /// Image.network(url); // Works on all platforms!
  /// ```
  Future<String> url(String path);

  /// Trigger a download of the file.
  ///
  /// - **Mobile**: Opens share sheet or saves to Downloads.
  /// - **Web**: Triggers browser download dialog.
  ///
  /// **Parameters:**
  /// - [path]: The path to the file to download.
  /// - [name]: Optional filename for the download.
  ///
  /// ```dart
  /// await disk.download('report.pdf', name: 'monthly-report.pdf');
  /// ```
  Future<void> download(String path, {String? name});
}
