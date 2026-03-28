import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Fetches an asset file via HTTP with cache-busting, bypassing browser cache.
///
/// Returns `null` if the request fails.
Future<String?> debugReadAssetFile(String path) async {
  try {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final response = await web.window.fetch('$path?_=$timestamp'.toJS).toDart;

    if (response.ok) {
      final text = await response.text().toDart;
      return text.toDart;
    }

    return null;
  } catch (_) {
    return null;
  }
}
