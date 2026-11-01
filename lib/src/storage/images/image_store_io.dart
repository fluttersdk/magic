import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../facades/storage.dart';

/// The folder network images are kept in on the device, one file per URL.
///
/// A file is named by the hash of its URL, so nothing a remote host sent
/// reaches a path. A URL's bytes are treated as final: a host that changes a
/// picture hands out a new URL, so a stored file needs no validators, only a
/// size. [sweep] drops the least recently used files once the folder outgrows
/// [maxBytes].
///
/// Native platforms only: `Storage.url` throws on the web, where the browser's
/// own HTTP cache keeps images.
final class MagicImageStore {
  /// A store over [directory], which may not exist yet.
  MagicImageStore(this.directory, {this.maxBytes = defaultMaxBytes});

  /// What the folder may hold before [sweep] trims it.
  static const int defaultMaxBytes = 300 * 1024 * 1024;

  /// A side file younger than this belongs to a write in flight; an older one
  /// is what a crashed write left behind.
  static const Duration partGrace = Duration(minutes: 1);

  /// `Storage.url` answers a `file://` address by concatenation, so the path is
  /// what follows the prefix, undecoded.
  static const String _fileScheme = 'file://';

  static const String _partSuffix = '.part';

  /// A sweep keeps going until the folder is under this share of [maxBytes],
  /// so the next write does not trigger another one.
  static const double _sweepTarget = 0.9;

  /// The folder every file lives in.
  final Directory directory;

  /// The size above which [sweep] starts dropping files.
  final int maxBytes;

  /// The store on the local storage disk named [disk].
  ///
  /// Throws a [StateError] when that disk does not resolve to a local folder.
  /// Give the disk `'exclude_from_backup': true`: a copy that can be fetched
  /// again does not belong in an iCloud backup.
  static Future<MagicImageStore> onDisk({
    String disk = 'images',
    int maxBytes = defaultMaxBytes,
  }) async {
    final String url = await Storage.disk(disk).url('');

    if (!url.startsWith(_fileScheme)) {
      throw StateError('The "$disk" storage disk is not a local disk.');
    }

    return MagicImageStore(
      Directory(url.substring(_fileScheme.length)),
      maxBytes: maxBytes,
    );
  }

  /// The file name for [url]: forty hex characters, whatever [url] holds.
  static String nameFor(String url) =>
      sha1.convert(utf8.encode(url)).toString();

  /// Where [url]'s bytes are or would be stored.
  File fileOf(String url) {
    return File('${directory.path}${Platform.pathSeparator}${nameFor(url)}');
  }

  /// The file holding [url]'s bytes, or null when none is stored. A hit counts
  /// as a use, which is what [sweep] orders by.
  Future<File?> find(String url) async {
    final File file = fileOf(url);

    if (!await file.exists()) return null;

    try {
      await file.setLastModified(DateTime.now());
    } on PathNotFoundException {
      // A sweep removed it between the check and the stamp: it is not stored.
      return null;
    }

    return file;
  }

  /// Stores [bytes] as [url]'s image and answers the file. The bytes land in a
  /// side file first, so a reader never sees half an image.
  Future<File> write(String url, Uint8List bytes) async {
    await directory.create(recursive: true);

    final File file = fileOf(url);
    final File side = File('${file.path}$_partSuffix');

    await side.writeAsBytes(bytes, flush: true);

    return side.rename(file.path);
  }

  /// Removes [url]'s file; one that is not stored is not an error.
  Future<void> evict(String url) => _remove(fileOf(url));

  /// Removes every stored file and keeps the folder itself: a disk marks its
  /// root out of backup once per launch, and a root deleted here would come
  /// back from the next write unmarked.
  Future<void> clear() async {
    if (!await directory.exists()) return;

    await for (final FileSystemEntity entry in directory.list()) {
      try {
        await entry.delete(recursive: true);
      } on PathNotFoundException {
        // Gone since the listing: a sweep or an evict got there first.
      }
    }
  }

  /// Drops the least recently used files once the folder holds more than
  /// [maxBytes], down to 90% of it, and answers the bytes freed.
  ///
  /// A side file inside [partGrace] is a write in flight and is left alone;
  /// an older one is removed whatever the total.
  Future<int> sweep() async {
    if (!await directory.exists()) return 0;

    final DateTime now = DateTime.now();
    final List<({File file, int size, DateTime used})> held =
        <({File file, int size, DateTime used})>[];

    await for (final FileSystemEntity entry in directory.list()) {
      if (entry is! File) continue;

      final FileStat stat = await entry.stat();

      // Gone since the listing: another sweep or an evict got there first.
      if (stat.type == FileSystemEntityType.notFound) continue;

      if (entry.path.endsWith(_partSuffix)) {
        if (now.difference(stat.modified) > partGrace) await _remove(entry);

        continue;
      }

      held.add((file: entry, size: stat.size, used: stat.modified));
    }

    int total = held.fold(0, (int sum, entry) => sum + entry.size);

    if (total <= maxBytes) return 0;

    held.sort((a, b) => a.used.compareTo(b.used));

    final int target = (maxBytes * _sweepTarget).floor();
    int freed = 0;

    for (final entry in held) {
      if (total <= target) break;

      await _remove(entry.file);
      total -= entry.size;
      freed += entry.size;
    }

    return freed;
  }

  Future<void> _remove(File file) async {
    try {
      await file.delete();
    } on PathNotFoundException {
      // Already gone: that is what was asked for.
    }
  }
}
