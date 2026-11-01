import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'image_cache_io.dart';

/// A network image drawn from the device's own copy, with a second address as
/// the stand-in until the first is there.
///
/// An app often meets one picture at two origins: a third party sends one with
/// a listing, and its own server holds a better one once it knows the item.
/// The better one is the [url]; the other is the [fallback]. Each is read from
/// the disk when held and fetched once when not (see [MagicImageCache]), so a
/// picture is a request the first time and never again.
///
/// While [url]'s picture is not held and the [fallback]'s is, the fallback's
/// draws at once and [url]'s replaces it when it lands. When [url]'s host
/// cannot be reached or has no image yet, the fallback's is fetched and stays;
/// the next resolve after `MagicImageCache.retryAfter` asks [url] again.
///
/// ```dart
/// WImage(image: MagicImage.of(item.poster, fallback: item.listedPoster)!)
/// ```
///
/// A still image: the first frame of an animated GIF is the one drawn. On the
/// web there is no file store and the browser's HTTP cache keeps images, so
/// [of] answers a plain `NetworkImage` there.
@immutable
final class MagicImage extends ImageProvider<MagicImage> {
  const MagicImage._(this.url, this.fallback, this.cacheWidth);

  /// The picture to keep.
  final String url;

  /// The picture to draw while [url]'s is not held, or when it cannot be had.
  /// Null when there is none, or when it is [url] itself.
  final String? fallback;

  /// The width in pixels to decode at, or null for the picture's own size.
  /// A picture narrower than this is not scaled up.
  final int? cacheWidth;

  /// The provider that draws [url], standing in [fallback] for it, or null
  /// when neither is an address.
  ///
  /// [cacheWidth] decodes the picture no wider than that many pixels, which is
  /// what a grid of posters wants. It is part of the provider's identity, so
  /// the memory cache holds one decode per width.
  static ImageProvider? of(String? url, {String? fallback, int? cacheWidth}) {
    assert(
      cacheWidth == null || cacheWidth > 0,
      'cacheWidth must be a positive number of pixels.',
    );

    final String? first = _filled(url);
    final String? second = _filled(fallback);
    final String? primary = first ?? second;

    if (primary == null) return null;

    return MagicImage._(
      primary,
      first == null || second == primary ? null : second,
      cacheWidth,
    );
  }

  static String? _filled(String? address) =>
      address == null || address.isEmpty ? null : address;

  /// Drops the stand-in the memory cache holds for this key once the retry
  /// window has passed, so this resolve asks [url] again. Without it the
  /// stand-in would stay cached under this key for the whole session.
  @override
  Future<MagicImage> obtainKey(ImageConfiguration configuration) {
    if (MagicImageCache.instance.standInDue(this)) {
      PaintingBinding.instance.imageCache.evict(this);
    }

    return SynchronousFuture<MagicImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(MagicImage key, ImageDecoderCallback decode) {
    return _MagicImageCompleter(
      _pictures(key, decode),
      // A failed key left in the memory cache is served as the same failure
      // for the rest of the session, as `NetworkImage` knows.
      onFailed: () => scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      }),
    );
  }

  /// The pictures to draw, in order: [url]'s alone when it is held, else the
  /// fallback's when it is held, then [url]'s once fetched, or the fallback's
  /// fetched when [url] cannot be had and nothing is up yet.
  static Stream<ui.Image> _pictures(
    MagicImage key,
    ImageDecoderCallback decode,
  ) async* {
    final MagicImageCache cache = MagicImageCache.instance;
    final String? other = key.fallback;

    // 1. Our picture on the disk is the whole answer.
    final ui.Image? kept = await _held(cache, key.url, key.cacheWidth, decode);

    if (kept != null) {
      yield kept;

      return;
    }

    // 2. Ours is not here: the stand-in, when held, draws meanwhile.
    bool shown = false;

    if (other != null) {
      final ui.Image? standIn = await _held(
        cache,
        other,
        key.cacheWidth,
        decode,
      );

      if (standIn != null) {
        shown = true;

        yield standIn;
      }
    }

    // 3. Ours is fetched. The stand-in is not, unless this fails: a request
    //    for both would double the traffic of every first look at a grid.
    try {
      yield await _fetched(cache, key.url, key.cacheWidth, decode);
    } on Exception {
      // The picture already up stays: the cache has noted the failure, and
      // there is nothing better to show.
      if (shown) {
        cache.noteStandIn(key);

        return;
      }

      if (other == null) rethrow;

      // 4. Nothing up and ours cannot be had: the stand-in.
      final ui.Image fetched = await _fetched(
        cache,
        other,
        key.cacheWidth,
        decode,
      );

      cache.noteStandIn(key);

      yield fetched;
    }
  }

  /// [url]'s first frame decoded from the disk, or null when it is not held or
  /// the file cannot be decoded, in which case it is removed.
  static Future<ui.Image?> _held(
    MagicImageCache cache,
    String url,
    int? width,
    ImageDecoderCallback decode,
  ) async {
    final File? file = await cache.stored(url);

    if (file == null) return null;

    try {
      return await _decoded(
        await ui.ImmutableBuffer.fromFilePath(file.path),
        width,
        decode,
      );
    } on Exception {
      await cache.forget(url);

      return null;
    }
  }

  /// [url]'s first frame, fetched first when the disk has none. Bytes that do
  /// not decode are removed and refused for the retry window, so they are not
  /// downloaded again at once, and the failure stands.
  static Future<ui.Image> _fetched(
    MagicImageCache cache,
    String url,
    int? width,
    ImageDecoderCallback decode,
  ) async {
    ui.ImmutableBuffer buffer;

    try {
      buffer = await ui.ImmutableBuffer.fromFilePath(
        (await cache.file(url)).path,
      );
    } on MagicImageNotStored catch (unstored) {
      // The disk would not keep it: draw what the host sent from memory.
      buffer = await ui.ImmutableBuffer.fromUint8List(unstored.bytes);
    }

    try {
      return await _decoded(buffer, width, decode);
    } on Exception {
      await cache.reject(url);

      rethrow;
    }
  }

  /// The first frame of [buffer], decoded whole: a truncated file fails here,
  /// where the callers can drop it, and not later at the paint.
  static Future<ui.Image> _decoded(
    ui.ImmutableBuffer buffer,
    int? width,
    ImageDecoderCallback decode,
  ) async {
    final ui.Codec codec = await decode(
      buffer,
      getTargetSize: width == null
          ? null
          : (int intrinsicWidth, int intrinsicHeight) => intrinsicWidth <= width
                ? const ui.TargetImageSize()
                : ui.TargetImageSize(width: width),
    );

    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is MagicImage &&
      other.url == url &&
      other.fallback == fallback &&
      other.cacheWidth == cacheWidth;

  @override
  int get hashCode => Object.hash(url, fallback, cacheWidth);

  /// Hosts only: a path or query can carry a token, and an image provider is
  /// printed into errors.
  @override
  String toString() {
    final String? other = fallback;

    return 'MagicImage(${_host(url)}'
        '${other == null ? '' : ', stand-in ${_host(other)}'})';
  }

  static String _host(String address) => Uri.tryParse(address)?.host ?? '';
}

/// A stream completer that can show more than one picture: the stand-in and
/// then the real one, where the framework's own completers take a single
/// codec.
final class _MagicImageCompleter extends ImageStreamCompleter {
  _MagicImageCompleter(Stream<ui.Image> pictures, {required this.onFailed}) {
    unawaited(_draw(pictures));
  }

  /// Called once when no picture could be had at all.
  final void Function() onFailed;

  /// Set when nothing listens any more and the cache let go: a picture that
  /// arrives after this is released rather than handed to `setImage`, which
  /// refuses a disposed completer.
  bool _gone = false;

  @override
  void onDisposed() {
    _gone = true;

    super.onDisposed();
  }

  Future<void> _draw(Stream<ui.Image> pictures) async {
    bool drawn = false;

    try {
      await for (final ui.Image picture in pictures) {
        if (_gone) {
          picture.dispose();

          break;
        }

        setImage(ImageInfo(image: picture));
        drawn = true;
      }
    } catch (error, stack) {
      // A failure after a picture is up is a better picture that did not
      // arrive; the one on screen stays.
      if (drawn || _gone) return;

      onFailed();

      reportError(
        context: ErrorDescription('while resolving a network image'),
        exception: error,
        stack: stack,
      );
    }
  }
}
