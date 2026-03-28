import 'dart:io';

/// Reads an asset file directly from disk, bypassing rootBundle cache.
///
/// Resolves the path relative to the current working directory. This works
/// reliably on desktop (macOS/Linux/Windows) where `flutter run` sets the
/// working directory to the project root. On mobile (iOS/Android) the asset
/// file typically does not exist on disk, so this returns `null` and the
/// caller falls back to rootBundle.
///
/// Returns `null` if the file does not exist or cannot be read.
Future<String?> debugReadAssetFile(String path) async {
  try {
    final file = File(path).absolute;

    if (await file.exists()) {
      return await file.readAsString();
    }
  } catch (_) {
    // Ignore IO / permission errors — fall through to rootBundle.
  }

  return null;
}
