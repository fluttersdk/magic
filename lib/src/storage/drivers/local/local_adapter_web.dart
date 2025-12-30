import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import 'local_adapter_contract.dart';

/// The Local Adapter for Web (Browser) platforms.
///
/// This adapter uses `SharedPreferences` with Base64 encoding for
/// persistence and creates Blob URLs for displaying files.
///
/// ## Storage Strategy
///
/// Files are stored as Base64-encoded strings in SharedPreferences.
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
  LocalAdapter({required this.root});

  /// Get the storage key for a path.
  String _getKey(String path) => 'storage:$root:$path';

  /// Get the MIME type key for a path.
  String _getMimeKey(String path) => 'storage:$root:$path:mime';

  @override
  Future<String> write(String path, Uint8List bytes, {String? mimeType}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKey(path);

    // Store as Base64
    final base64Data = base64Encode(bytes);
    await prefs.setString(key, base64Data);

    // Store MIME type if provided
    if (mimeType != null) {
      await prefs.setString(_getMimeKey(path), mimeType);
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
    final prefs = await SharedPreferences.getInstance();
    final key = _getKey(path);

    final base64Data = prefs.getString(key);
    if (base64Data == null) {
      return null;
    }

    return base64Decode(base64Data);
  }

  @override
  Future<bool> exists(String path) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_getKey(path));
  }

  @override
  Future<bool> delete(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKey(path);

    if (!prefs.containsKey(key)) {
      return false;
    }

    // Revoke Blob URL if exists
    if (_blobUrls.containsKey(path)) {
      web.URL.revokeObjectURL(_blobUrls[path]!);
      _blobUrls.remove(path);
    }

    await prefs.remove(key);
    await prefs.remove(_getMimeKey(path));
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
    final prefs = await SharedPreferences.getInstance();
    final mimeType = _mimeTypes[path] ??
        prefs.getString(_getMimeKey(path)) ??
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
