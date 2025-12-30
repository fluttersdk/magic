import 'dart:typed_data';

/// The Local Adapter Contract.
///
/// This abstract class defines the platform-specific operations for
/// local file storage. Implementations exist for:
/// - **IO** (Mobile/Desktop): Uses `dart:io` and `path_provider`
/// - **Web** (Browser): Uses `package:web`, Blob URLs, and Base64 storage
///
/// The adapter handles the low-level platform differences while
/// `LocalDisk` provides a unified API.
abstract class LocalAdapterContract {
  /// Write bytes to the given path.
  ///
  /// [path] The relative path within the disk's root.
  /// [bytes] The binary data to write.
  /// [mimeType] Optional MIME type for Blob creation (Web).
  ///
  /// **Returns:** The full path or URL where the file was stored.
  Future<String> write(String path, Uint8List bytes, {String? mimeType});

  /// Read bytes from the given path.
  ///
  /// **Returns:** The file contents, or `null` if not found.
  Future<Uint8List?> read(String path);

  /// Check if a file exists at the given path.
  Future<bool> exists(String path);

  /// Delete a file at the given path.
  ///
  /// **Returns:** `true` if deleted successfully.
  Future<bool> delete(String path);

  /// Get a displayable URL for the file.
  ///
  /// - **IO**: Returns `file:///` path.
  /// - **Web**: Returns `blob:` URL.
  Future<String> getUrl(String path);

  /// Trigger a download of the file.
  ///
  /// - **IO**: Opens share sheet or saves to Downloads.
  /// - **Web**: Triggers browser download dialog.
  Future<void> download(String path, String? name);
}
