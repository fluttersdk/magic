import 'dart:io';

/// Reads an asset file directly from disk, bypassing rootBundle cache.
///
/// Returns `null` if the file does not exist.
Future<String?> debugReadAssetFile(String path) async {
  final file = File(path);

  if (await file.exists()) {
    return file.readAsString();
  }

  return null;
}
