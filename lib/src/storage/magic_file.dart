import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../facades/http.dart';
import '../facades/storage.dart';
import '../network/magic_response.dart';

/// A picked file from the file or image picker.
///
/// This class wraps the result of a file/image pick operation and provides
/// convenient methods for working with the picked file, including direct
/// integration with the Magic Storage and HTTP systems.
///
/// ## Usage
///
/// ```dart
/// // Pick and store
/// final file = await Pick.image();
/// if (file != null) {
///   await file.store('avatars/user.jpg');
/// }
///
/// // Pick and upload to server
/// final image = await Pick.image();
/// final response = await image!.upload('/api/upload', fieldName: 'avatar');
///
/// // Access file data
/// print(file.name);       // 'photo.jpg'
/// print(file.extension);  // 'jpg'
/// print(file.mimeType);   // 'image/jpeg'
/// final bytes = await file.readAsBytes();
/// ```
class MagicFile {
  /// The original file path (may be null on Web).
  final String? path;

  /// The file name with extension.
  final String name;

  /// The file size in bytes.
  final int? size;

  /// The MIME type (e.g., 'image/jpeg').
  final String? mimeType;

  /// The file bytes (may be loaded lazily).
  Uint8List? _bytes;

  /// Function to read bytes if not already loaded.
  final Future<Uint8List?> Function()? _bytesReader;

  /// Create a new MagicFile.
  MagicFile({
    this.path,
    required this.name,
    this.size,
    this.mimeType,
    Uint8List? bytes,
    Future<Uint8List?> Function()? bytesReader,
  })  : _bytes = bytes,
        _bytesReader = bytesReader;

  /// Get the file extension (without dot).
  ///
  /// ```dart
  /// final file = MagicFile(name: 'photo.jpg', ...);
  /// print(file.extension); // 'jpg'
  /// ```
  String get extension => p.extension(name).replaceFirst('.', '').toLowerCase();

  /// Check if this is an image file.
  bool get isImage {
    const imageExtensions = [
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
      'heic'
    ];
    return imageExtensions.contains(extension);
  }

  /// Check if this is a video file.
  bool get isVideo {
    const videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'];
    return videoExtensions.contains(extension);
  }

  /// Read the file as bytes.
  ///
  /// This method will return cached bytes if already loaded, otherwise
  /// it will read from the file path or use the bytes reader function.
  ///
  /// ```dart
  /// final bytes = await file.readAsBytes();
  /// ```
  Future<Uint8List?> readAsBytes() async {
    if (_bytes != null) return _bytes;

    if (_bytesReader != null) {
      _bytes = await _bytesReader();
      return _bytes;
    }

    return null;
  }

  /// Store the file to Storage at the given path.
  ///
  /// Uses the Magic Storage system to persist the file. The MIME type
  /// is automatically passed for proper Web Blob URL generation.
  ///
  /// **Parameters:**
  /// - [storagePath]: The path in storage (e.g., 'avatars/user.jpg').
  /// - [disk]: Optional disk name (defaults to configured default).
  ///
  /// **Returns:** The storage path where the file was saved.
  ///
  /// ```dart
  /// final file = await Pick.image();
  /// final path = await file!.store('avatars/user.jpg');
  /// print(path); // 'avatars/user.jpg'
  /// ```
  Future<String> store(String storagePath, {String? disk}) async {
    final bytes = await readAsBytes();
    if (bytes == null) {
      throw Exception('Unable to read file bytes for storage');
    }

    if (disk != null) {
      return Storage.disk(disk).put(storagePath, bytes, mimeType: mimeType);
    }

    return Storage.put(storagePath, bytes, mimeType: mimeType);
  }

  /// Store the file with an auto-generated unique name.
  ///
  /// Generates a timestamped filename to avoid collisions:
  /// `{directory}/{timestamp}_{originalName}`
  ///
  /// ```dart
  /// final file = await Pick.image();
  /// final path = await file!.storeAs('avatars');
  /// print(path); // 'avatars/1703836800000_photo.jpg'
  /// ```
  Future<String> storeAs(String directory, {String? disk}) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uniqueName = '${timestamp}_$name';
    final storagePath = p.join(directory, uniqueName);

    return store(storagePath, disk: disk);
  }

  /// Upload the file to a server endpoint.
  ///
  /// Uses the Magic HTTP system to upload the file via multipart form data.
  ///
  /// **Parameters:**
  /// - [url]: The endpoint URL (e.g., '/api/upload').
  /// - [fieldName]: The form field name (default: 'file').
  /// - [data]: Additional form data to include.
  /// - [headers]: Additional HTTP headers.
  ///
  /// **Returns:** A `MagicResponse` from the server.
  ///
  /// ```dart
  /// final image = await Pick.image();
  /// final response = await image!.upload('/api/upload', fieldName: 'avatar');
  ///
  /// if (response.successful) {
  ///   print('Uploaded: ${response['url']}');
  /// }
  /// ```
  Future<MagicResponse> upload(
    String url, {
    String fieldName = 'file',
    Map<String, dynamic> data = const {},
    Map<String, String>? headers,
  }) {
    return Http.upload(
      url,
      data: data,
      files: {fieldName: this},
      headers: headers,
    );
  }

  @override
  String toString() =>
      'MagicFile(name: $name, size: $size, mimeType: $mimeType)';
}
