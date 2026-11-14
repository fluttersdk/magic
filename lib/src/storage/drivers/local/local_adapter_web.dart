import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'local_adapter_contract.dart';

/// Prefix of every localStorage entry this adapter owns.
///
/// Files written by 0.0.41 live under it, so the key and value shape stay as
/// they were: `flutter.<key>` holding the json-encoded string.
const String _localStoragePrefix = 'flutter.';

/// The Local Adapter for Web (Browser) platforms.
///
/// This adapter uses the browser's `localStorage` with Base64 encoding for
/// persistence and creates Blob URLs for displaying files.
///
/// ## Storage Strategy
///
/// Files are stored as Base64-encoded strings in `localStorage`.
/// This works well for small to medium files (< 5MB).
///
/// ## URL Generation
///
/// The `getUrl()` method creates a Blob URL that can be used directly
/// in `Image.network()`, allowing seamless display of stored images.
///
/// ```dart
/// final url = await adapter.getUrl('avatar.jpg');
/// // Returns: blob:http://localhost/abc-123-uuid
/// Image.network(url); // Works!
/// ```
class LocalAdapter implements LocalAdapterContract {
  /// The root prefix for storage keys.
  final String root;

  /// Cache of Blob URLs to prevent memory leaks.
  final Map<String, String> _blobUrls = {};

  /// Cache of MIME types for stored files.
  final Map<String, String> _mimeTypes = {};

  /// Create a new Local Adapter for Web platforms.
  ///
  /// [excludeFromBackup] has no effect here: browser storage has no device
  /// backup to opt out of. It exists to keep the constructor in step with
  /// the IO adapter.
  LocalAdapter({required this.root, bool excludeFromBackup = false});

  /// Get the storage key for a path.
  String _getKey(String path) => 'storage:$root:$path';

  /// Get the MIME type key for a path.
  String _getMimeKey(String path) => 'storage:$root:$path:mime';

  /// Read a string stored in the 0.0.41 shape.
  String? _getItem(String key) {
    final encoded = web.window.localStorage.getItem(_localStoragePrefix + key);
    return encoded == null ? null : json.decode(encoded) as String;
  }

  /// Store a string in the 0.0.41 shape.
  void _setItem(String key, String value) {
    web.window.localStorage.setItem(
      _localStoragePrefix + key,
      json.encode(value),
    );
  }

  /// Remove an entry stored in the 0.0.41 shape.
  void _removeItem(String key) {
    web.window.localStorage.removeItem(_localStoragePrefix + key);
  }

  @override
  Future<String> write(String path, Uint8List bytes, {String? mimeType}) async {
    // Store as Base64
    _setItem(_getKey(path), base64Encode(bytes));

    // Store MIME type if provided
    if (mimeType != null) {
      _setItem(_getMimeKey(path), mimeType);
      _mimeTypes[path] = mimeType;
    }

    // Revoke old Blob URL if exists
    if (_blobUrls.containsKey(path)) {
      web.URL.revokeObjectURL(_blobUrls[path]!);
      _blobUrls.remove(path);
    }

    return path;
  }

  @override
  Future<Uint8List?> read(String path) async {
    final base64Data = _getItem(_getKey(path));
    if (base64Data == null) {
      return null;
    }

    return base64Decode(base64Data);
  }

  @override
  Future<bool> exists(String path) async {
    return _getItem(_getKey(path)) != null;
  }

  @override
  Future<bool> delete(String path) async {
    final key = _getKey(path);

    if (_getItem(key) == null) {
      return false;
    }

    // Revoke Blob URL if exists
    if (_blobUrls.containsKey(path)) {
      web.URL.revokeObjectURL(_blobUrls[path]!);
      _blobUrls.remove(path);
    }

    _removeItem(key);
    _removeItem(_getMimeKey(path));
    _mimeTypes.remove(path);

    return true;
  }

  @override
  Future<String> getUrl(String path) async {
    // Return cached Blob URL if available
    if (_blobUrls.containsKey(path)) {
      return _blobUrls[path]!;
    }

    // Read the bytes
    final bytes = await read(path);
    if (bytes == null) {
      throw Exception('File not found: $path');
    }

    // Get MIME type
    final mimeType =
        _mimeTypes[path] ??
        _getItem(_getMimeKey(path)) ??
        'application/octet-stream';

    // Create Blob and URL using proper JSArrayBuffer
    final jsArrayBuffer = bytes.buffer.toJS;
    final blob = web.Blob(
      <JSArrayBuffer>[jsArrayBuffer].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final blobUrl = web.URL.createObjectURL(blob);

    // Cache the URL
    _blobUrls[path] = blobUrl;

    return blobUrl;
  }

  @override
  Future<void> download(String path, String? name) async {
    final url = await getUrl(path);
    final fileName = name ?? path.split('/').last;

    // Create invisible anchor and trigger click
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName
      ..style.display = 'none';

    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
  }
}
