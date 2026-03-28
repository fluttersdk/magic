/// Fallback stub for platforms where neither `dart:io` nor `dart:js_interop`
/// is available. Always returns `null` so the caller falls back to rootBundle.
Future<String?> debugReadAssetFile(String path) async => null;
