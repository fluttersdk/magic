import 'package:flutter/painting.dart';

/// A network image on the web.
///
/// There is no file store in a browser, and its own HTTP cache keeps images, so
/// [of] answers a plain `NetworkImage` and the stand-in is not drawn. The
/// native build of this class draws from a copy on the device; see
/// `magic_image_io.dart`.
abstract final class MagicImage {
  /// The provider that draws [url], or [fallback] when [url] is empty, or null
  /// when neither is an address. [cacheWidth] decodes no wider than that many
  /// pixels.
  static ImageProvider? of(String? url, {String? fallback, int? cacheWidth}) {
    final String? primary = _filled(url) ?? _filled(fallback);

    if (primary == null) return null;

    return ResizeImage.resizeIfNeeded(cacheWidth, null, NetworkImage(primary));
  }

  static String? _filled(String? address) =>
      address == null || address.isEmpty ? null : address;
}
