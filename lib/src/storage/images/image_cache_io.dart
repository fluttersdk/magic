import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../facades/log.dart';
import '../../foundation/magic.dart';
import 'image_exception.dart';
import 'image_store_io.dart';
import 'image_wire_io.dart';

/// Reads the bytes behind an image address.
typedef MagicImageFetch = Future<Uint8List> Function(Uri url);

/// The host gave an image and the disk would not keep it (it is full, the
/// folder is gone, or the disk cannot be opened).
///
/// Carries the [bytes], so the picture can still be drawn from memory. It is
/// not a failure of the host and is not remembered as one.
final class MagicImageNotStored implements Exception {
  /// An image that was fetched and could not be written.
  const MagicImageNotStored(this.bytes);

  /// What the host sent.
  final Uint8List bytes;

  @override
  String toString() => 'MagicImageNotStored: the image could not be written.';
}

/// The on-device copy of every network image the app has drawn: the disk
/// [MagicImageStore] and the network [MagicImageWire] behind one call.
///
/// An image is fetched once. Two draws of one URL at the same moment share the
/// request, and a URL that failed is not asked again for [retryAfter], so a
/// grid scrolled past a dead picture does not hit the host on every frame.
///
/// The folder is trimmed to its size cap on the first use of each launch, and
/// again whenever a quarter of the cap has been written since, so a long
/// session cannot outgrow it.
final class MagicImageCache {
  /// A cache over the local storage disk named [disk], capped at [maxBytes].
  ///
  /// A [store] given here replaces the disk, and a [fetch] the network; a test
  /// passes both, and [now] for the retry window. A given store is not trimmed
  /// when it is first used, only after writes.
  MagicImageCache({
    this.disk = 'images',
    int maxBytes = MagicImageStore.defaultMaxBytes,
    this.retryAfter = const Duration(minutes: 5),
    MagicImageStore? store,
    MagicImageFetch? fetch,
    DateTime Function()? now,
  }) : _maxBytes = maxBytes,
       _store = store,
       _fetch = fetch,
       _now = now ?? DateTime.now;

  /// The cache `MagicImage` draws through. A test swaps it and restores it.
  static MagicImageCache instance = MagicImageCache();

  /// Failed URLs remembered before expired ones are forgotten.
  static const int _failuresKept = 1000;

  /// The storage disk the images live on, from `filesystems.disks`.
  final String disk;

  /// How long a failed URL is left alone.
  final Duration retryAfter;

  final int _maxBytes;
  final MagicImageStore? _store;

  /// The wire, built on the first fetch rather than at construction: an
  /// `HttpClient` takes the process-wide overrides in force when it is made.
  MagicImageFetch? _fetch;
  final DateTime Function() _now;

  /// The disk store, opened on the first use and kept: it resolves its folder
  /// through the platform, which a widget test has no answer for until a test
  /// asks for an image. Null when the disk cannot be opened.
  Future<MagicImageStore?>? _opening;

  /// Whether the unavailable disk has been reported: once is enough.
  bool _reported = false;

  /// Bytes written since the folder was last trimmed.
  int _written = 0;

  final Map<String, Future<File>> _running = <String, Future<File>>{};
  final Map<String, DateTime> _failed = <String, DateTime>{};

  /// The keys whose picture on screen is a stand-in, with when it settled.
  /// Insertion ordered, so the oldest note is the first.
  final Map<Object, DateTime> _standIns = <Object, DateTime>{};

  Future<MagicImageStore?> get _disk => _opening ??= _open();

  /// Opens the store and trims it once, behind the call that asked: the first
  /// image of a launch does not wait for the folder to be walked.
  ///
  /// A disk that cannot be opened (not declared, not a local disk, no folder
  /// from the platform) leaves the cache without a copy: images are fetched and
  /// drawn as `NetworkImage` would, once reported, and the open is tried again
  /// on the next call.
  Future<MagicImageStore?> _open() async {
    final MagicImageStore? given = _store;

    if (given != null) return given;

    final MagicImageStore store;

    try {
      store = await MagicImageStore.onDisk(disk: disk, maxBytes: _maxBytes);
    } on Exception catch (error) {
      _opening = null;

      if (!_reported) {
        _reported = true;
        _warn(
          'images are drawn without a copy on the device: the "$disk" '
          'disk cannot be opened (${error.runtimeType})',
        );
      }

      return null;
    }

    unawaited(_trim(store));

    return store;
  }

  Future<void> _trim(MagicImageStore store) async {
    try {
      await store.sweep();
    } on FileSystemException catch (error) {
      // A folder that cannot be walked keeps its images, which costs space and
      // nothing else.
      _warn('images not trimmed: ${error.runtimeType}');
    }
  }

  /// Logs when a log is bound: an app has one, a unit test often does not, and
  /// drawing a picture must not depend on it.
  void _warn(String message) {
    if (Magic.bound('log')) Log.warning(message);
  }

  /// The file holding [url]'s image when it is on the disk, null when it is
  /// not, or when there is no disk. Never touches the network.
  Future<File?> stored(String url) async => (await _disk)?.find(url);

  /// The file holding [url]'s image, fetched and stored first when the disk
  /// has none.
  ///
  /// Throws a [MagicImageException] when the address is not a URL or the host
  /// does not give an image, and repeats that failure without a request while
  /// [retryAfter] has not passed. When the host answered and the disk would
  /// not keep the bytes, it throws a [MagicImageNotStored] holding them.
  Future<File> file(String url) {
    final Future<File>? running = _running[url];

    if (running != null) return running;

    // A block body: `remove` answers the very future being built, and
    // `whenComplete` waits for a future its action returns.
    final Future<File> started = _fill(url).whenComplete(() {
      _running.remove(url);
    });

    _running[url] = started;

    return started;
  }

  /// Notes that the picture drawn for [key] is a stand-in, because the address
  /// it stands in for could not be had. [standInDue] says when to try again.
  void noteStandIn(Object key) {
    if (_standIns.length >= _failuresKept) {
      _standIns.remove(_standIns.keys.first);
    }

    // Removed first, so the entry moves to the end of the insertion order.
    _standIns.remove(key);
    _standIns[key] = _now();
  }

  /// Whether the stand-in noted for [key] has stood for [retryAfter]. Answers
  /// true once: the note is dropped, so one resolve replaces the stand-in and
  /// the ones after it find the load already under way.
  bool standInDue(Object key) {
    final DateTime? since = _standIns[key];

    if (since == null || _now().difference(since) < retryAfter) return false;

    _standIns.remove(key);

    return true;
  }

  /// Removes [url]'s stored bytes, for a file the engine could not decode.
  Future<void> forget(String url) async => (await _disk)?.evict(url);

  /// Removes [url]'s stored bytes and refuses it for [retryAfter]: the host
  /// answered with something that is not a picture, and asking again at once
  /// would download it again.
  Future<void> reject(String url) async {
    _remember(url);

    await forget(url);
  }

  /// Trims the disk to its cap and answers the bytes freed.
  Future<int> sweep() async => await (await _disk)?.sweep() ?? 0;

  /// Removes every stored image and forgets which URLs failed, for a sign-out
  /// or a "clear cache" action.
  Future<void> clear() async {
    _failed.clear();
    _standIns.clear();

    await (await _disk)?.clear();
  }

  Future<File> _fill(String url) async {
    // 1. What is on the disk is final: a URL's bytes never change under it.
    final MagicImageStore? store = await _disk;
    final File? held = await store?.find(url);

    if (held != null) return held;

    // 2. A URL that just failed is not worth another request.
    final DateTime? failedAt = _failed[url];

    if (failedAt != null && _now().difference(failedAt) < retryAfter) {
      throw const MagicImageException('This image failed a moment ago.');
    }

    final Uri? address = Uri.tryParse(url);

    if (address == null) throw const MagicImageException('Not an address.');

    // 3. Fetch it, and remember a failure of the host for the retry window.
    final Uint8List bytes;

    try {
      final MagicImageFetch fetch = _fetch ??= MagicImageWire().get;

      bytes = await fetch(address);
    } on Exception {
      _remember(url);

      rethrow;
    }

    _failed.remove(url);

    // 4. Keep it. A disk that refuses, or is not there, is not the host's
    //    fault: the bytes go to the caller to draw, and nothing is remembered
    //    against the URL.
    if (store == null) throw MagicImageNotStored(bytes);

    try {
      final File file = await store.write(url, bytes);

      _trimAfter(store, bytes.length);

      return file;
    } on FileSystemException {
      throw MagicImageNotStored(bytes);
    }
  }

  /// A quarter of the cap written since the last trim starts another.
  void _trimAfter(MagicImageStore store, int bytes) {
    _written += bytes;

    if (_written < store.maxBytes ~/ 4) return;

    _written = 0;
    unawaited(_trim(store));
  }

  void _remember(String url) {
    final DateTime at = _now();

    if (_failed.length >= _failuresKept) {
      _failed.removeWhere(
        (String _, DateTime when) => at.difference(when) >= retryAfter,
      );
    }

    _failed[url] = at;
  }
}
