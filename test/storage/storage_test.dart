import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_magic/src/storage/contracts/storage_disk.dart';
import 'package:fluttersdk_magic/src/storage/drivers/local_disk.dart';
import 'package:fluttersdk_magic/src/storage/drivers/local/local_adapter_contract.dart';
import 'package:fluttersdk_magic/src/storage/storage_manager.dart';
import 'package:fluttersdk_magic/src/facades/storage.dart';
import 'package:fluttersdk_magic/src/facades/config.dart';

/// Mock adapter for testing Storage without file system access.
class MockLocalAdapter implements LocalAdapterContract {
  final Map<String, Uint8List> _files = {};
  final Map<String, String> _mimeTypes = {};

  @override
  Future<String> write(String path, Uint8List bytes, {String? mimeType}) async {
    _files[path] = bytes;
    if (mimeType != null) {
      _mimeTypes[path] = mimeType;
    }
    return path;
  }

  @override
  Future<Uint8List?> read(String path) async {
    return _files[path];
  }

  @override
  Future<bool> exists(String path) async {
    return _files.containsKey(path);
  }

  @override
  Future<bool> delete(String path) async {
    if (!_files.containsKey(path)) return false;
    _files.remove(path);
    _mimeTypes.remove(path);
    return true;
  }

  @override
  Future<String> getUrl(String path) async {
    if (!_files.containsKey(path)) {
      throw Exception('File not found: $path');
    }
    return 'mock://$path';
  }

  @override
  Future<void> download(String path, String? name) async {
    if (!_files.containsKey(path)) {
      throw Exception('File not found: $path');
    }
    // Mock download - do nothing
  }
}

void main() {
  group('LocalDisk', () {
    late LocalDisk disk;
    late MockLocalAdapter adapter;

    setUp(() {
      adapter = MockLocalAdapter();
      disk = LocalDisk.withAdapter(adapter);
    });

    test('put() stores Uint8List content', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      final result = await disk.put('test.bin', bytes);

      expect(result, 'test.bin');
      expect(await disk.exists('test.bin'), isTrue);
    });

    test('put() stores String content as UTF-8', () async {
      final result = await disk.put('hello.txt', 'Hello World');

      expect(result, 'hello.txt');

      final bytes = await disk.get('hello.txt');
      expect(bytes, isNotNull);
      expect(String.fromCharCodes(bytes!), 'Hello World');
    });

    test('put() stores List<int> content', () async {
      final data = [72, 101, 108, 108, 111]; // "Hello"

      await disk.put('list.txt', data);

      final bytes = await disk.get('list.txt');
      expect(bytes, isNotNull);
      expect(String.fromCharCodes(bytes!), 'Hello');
    });

    test('put() passes mimeType to adapter', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);

      await disk.put('image.jpg', bytes, mimeType: 'image/jpeg');

      expect(adapter._mimeTypes['image.jpg'], 'image/jpeg');
    });

    test('get() returns null for non-existent file', () async {
      final result = await disk.get('missing.txt');

      expect(result, isNull);
    });

    test('get() returns bytes for existing file', () async {
      final bytes = Uint8List.fromList([10, 20, 30]);
      await disk.put('data.bin', bytes);

      final result = await disk.get('data.bin');

      expect(result, equals(bytes));
    });

    test('exists() returns false for missing file', () async {
      expect(await disk.exists('nope.txt'), isFalse);
    });

    test('exists() returns true for stored file', () async {
      await disk.put('exists.txt', 'content');

      expect(await disk.exists('exists.txt'), isTrue);
    });

    test('delete() returns false for missing file', () async {
      expect(await disk.delete('missing.txt'), isFalse);
    });

    test('delete() removes file and returns true', () async {
      await disk.put('deleteme.txt', 'bye');

      expect(await disk.delete('deleteme.txt'), isTrue);
      expect(await disk.exists('deleteme.txt'), isFalse);
    });

    test('url() returns adapter URL', () async {
      await disk.put('file.txt', 'content');

      final url = await disk.url('file.txt');

      expect(url, 'mock://file.txt');
    });

    test('url() throws for missing file', () async {
      expect(
        () => disk.url('missing.txt'),
        throwsException,
      );
    });

    test('download() calls adapter download', () async {
      await disk.put('download.txt', 'content');

      // Should not throw
      await disk.download('download.txt', name: 'renamed.txt');
    });

    test('put() throws for unsupported content type', () {
      expect(
        () => disk.put('bad.txt', 12345),
        throwsArgumentError,
      );
    });
  });

  group('StorageManager', () {
    setUp(() {
      Config.set('filesystems.default', 'local');
      Config.set('filesystems.disks.local', {
        'driver': 'local',
        'root': 'test_storage',
      });
      Config.set('filesystems.disks.public', {
        'driver': 'local',
        'root': 'public',
      });
    });

    tearDown(() {
      Config.flush();
    });

    test('disk() returns LocalDisk for local driver', () {
      final manager = StorageManager();

      final disk = manager.disk();

      expect(disk, isA<LocalDisk>());
    });

    test('disk() returns same instance for same name', () {
      final manager = StorageManager();

      final disk1 = manager.disk('local');
      final disk2 = manager.disk('local');

      expect(identical(disk1, disk2), isTrue);
    });

    test('disk() returns different instance for different name', () {
      final manager = StorageManager();

      final local = manager.disk('local');
      final public = manager.disk('public');

      expect(identical(local, public), isFalse);
    });

    test('disk() throws for unknown disk', () {
      final manager = StorageManager();

      expect(
        () => manager.disk('unknown'),
        throwsException,
      );
    });

    test('flush() clears cached disks', () {
      final manager = StorageManager();

      final disk1 = manager.disk('local');
      manager.flush();
      final disk2 = manager.disk('local');

      expect(identical(disk1, disk2), isFalse);
    });
  });

  group('Storage Facade', () {
    setUp(() {
      Config.set('filesystems.default', 'local');
      Config.set('filesystems.disks.local', {
        'driver': 'local',
        'root': 'facade_test',
      });
      Storage.flush();
    });

    tearDown(() {
      Storage.flush();
      Config.flush();
    });

    test('disk() returns StorageDisk', () {
      final disk = Storage.disk();

      expect(disk, isA<StorageDisk>());
    });

    test('disk() with name returns specific disk', () {
      Config.set('filesystems.disks.custom', {
        'driver': 'local',
        'root': 'custom',
      });

      final disk = Storage.disk('custom');

      expect(disk, isA<StorageDisk>());
    });
  });
}
