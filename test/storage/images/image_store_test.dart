import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

const MethodChannel _pathProviderChannel = MethodChannel(
  'plugins.flutter.io/path_provider',
);

Uint8List _bytes(int length) => Uint8List.fromList(List<int>.filled(length, 7));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory folder;
  late MagicImageStore store;

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    folder = Directory.systemTemp.createTempSync('magic_image_store');
    store = MagicImageStore(folder, maxBytes: 1000);
  });

  tearDown(() {
    if (folder.existsSync()) folder.deleteSync(recursive: true);
  });

  group('names', () {
    test('a file is named by a hash, so no part of a url reaches a path', () {
      const String url = 'https://host.example/../../etc/passwd?u=me&p=secret';

      final String name = MagicImageStore.nameFor(url);

      expect(name, matches(RegExp(r'^[0-9a-f]{40}$')));
      expect(MagicImageStore.nameFor(url), name);
      expect(MagicImageStore.nameFor('$url#'), isNot(name));
      expect(store.fileOf(url).path, startsWith(folder.path));
    });
  });

  group('find and write', () {
    test('a url that was never written is not found', () async {
      expect(await store.find('https://a.example/p.jpg'), isNull);
    });

    test('what was written is found with the same bytes', () async {
      await store.write('https://a.example/p.jpg', _bytes(10));

      final File? found = await store.find('https://a.example/p.jpg');

      expect(found, isNotNull);
      expect(await found!.readAsBytes(), _bytes(10));
    });

    test('a write leaves no half written file behind', () async {
      await store.write('https://a.example/p.jpg', _bytes(10));

      final List<String> names = folder
          .listSync()
          .map((FileSystemEntity e) => e.uri.pathSegments.last)
          .toList();

      expect(names, <String>[
        MagicImageStore.nameFor('https://a.example/p.jpg'),
      ]);
    });

    test('a write creates the folder when it is not there yet', () async {
      folder.deleteSync(recursive: true);

      await store.write('https://a.example/p.jpg', _bytes(3));

      expect(await store.find('https://a.example/p.jpg'), isNotNull);
    });

    test('writing a url again replaces its bytes', () async {
      await store.write('https://a.example/p.jpg', _bytes(10));
      await store.write('https://a.example/p.jpg', _bytes(4));

      final File? found = await store.find('https://a.example/p.jpg');

      expect(await found!.length(), 4);
    });
  });

  group('evict and clear', () {
    test('evict removes one url and not another', () async {
      await store.write('https://a.example/1.jpg', _bytes(5));
      await store.write('https://a.example/2.jpg', _bytes(5));

      await store.evict('https://a.example/1.jpg');

      expect(await store.find('https://a.example/1.jpg'), isNull);
      expect(await store.find('https://a.example/2.jpg'), isNotNull);
    });

    test('evicting a url that is not stored is not an error', () async {
      await store.evict('https://a.example/never.jpg');
    });

    test('clear empties the folder and a later write still works', () async {
      await store.write('https://a.example/1.jpg', _bytes(5));

      await store.clear();

      // The folder itself stays: a disk marks its root out of backup once per
      // launch, and a root deleted here would come back unmarked.
      expect(folder.existsSync(), isTrue);
      expect(folder.listSync(), isEmpty);
      expect(await store.find('https://a.example/1.jpg'), isNull);
      await store.write('https://a.example/2.jpg', _bytes(5));
      expect(await store.find('https://a.example/2.jpg'), isNotNull);
    });
  });

  group('sweep', () {
    Future<void> age(String url, int minutesAgo) {
      return store
          .fileOf(url)
          .setLastModified(
            DateTime.now().subtract(Duration(minutes: minutesAgo)),
          );
    }

    Future<void> fill() async {
      for (int i = 1; i <= 5; i++) {
        await store.write('https://a.example/$i.jpg', _bytes(300));
        await age('https://a.example/$i.jpg', 100 - i);
      }
    }

    test('does nothing while the folder fits the cap', () async {
      await store.write('https://a.example/1.jpg', _bytes(400));
      await store.write('https://a.example/2.jpg', _bytes(400));

      expect(await store.sweep(), 0);
      expect(await store.find('https://a.example/1.jpg'), isNotNull);
    });

    test('drops the least recently used files until it is under 90%', () async {
      await fill();

      final int freed = await store.sweep();

      // 1500 bytes held, cap 1000, target 900: the two oldest go and the
      // folder lands exactly on the target.
      expect(freed, 600);
      expect(await store.find('https://a.example/1.jpg'), isNull);
      expect(await store.find('https://a.example/2.jpg'), isNull);
      expect(await store.find('https://a.example/3.jpg'), isNotNull);
      expect(await store.find('https://a.example/4.jpg'), isNotNull);
      expect(await store.find('https://a.example/5.jpg'), isNotNull);
    });

    test(
      'a find counts as a use, so a read file outlives older ones',
      () async {
        await fill();

        await store.find('https://a.example/1.jpg');
        await store.sweep();

        expect(await store.find('https://a.example/1.jpg'), isNotNull);
        expect(await store.find('https://a.example/2.jpg'), isNull);
      },
    );

    test('a folder that does not exist yet has nothing to sweep', () async {
      folder.deleteSync(recursive: true);

      expect(await store.sweep(), 0);
    });

    test('a write in flight is left alone, a crashed one is removed', () async {
      final File fresh = File('${folder.path}/fresh.part')
        ..writeAsBytesSync(_bytes(10));
      final File stale = File('${folder.path}/stale.part')
        ..writeAsBytesSync(_bytes(10));
      stale.setLastModifiedSync(
        DateTime.now().subtract(MagicImageStore.partGrace * 2),
      );

      // Well under the cap: the stale side file goes whatever the total.
      expect(await store.sweep(), 0);

      expect(fresh.existsSync(), isTrue);
      expect(stale.existsSync(), isFalse);
    });

    test('a side file never counts toward the total or gets evicted for '
        'size', () async {
      await fill();
      File('${folder.path}/fresh.part').writeAsBytesSync(_bytes(900));

      final int freed = await store.sweep();

      expect(freed, 600);
      expect(File('${folder.path}/fresh.part').existsSync(), isTrue);
    });

    test('files removed under a running sweep do not fail it', () async {
      await fill();

      // A second sweep runs while the first one is listing and removing.
      final List<int> freed = await Future.wait(<Future<int>>[
        store.sweep(),
        store.sweep(),
      ]);

      expect(freed.reduce((int a, int b) => a > b ? a : b), 600);
      expect(await store.find('https://a.example/5.jpg'), isNotNull);
    });
  });

  group('onDisk', () {
    late Directory documents;

    setUp(() {
      // The disk resolves its folder through path_provider, which has no
      // platform side under `flutter test`.
      documents = Directory.systemTemp.createTempSync('magic_image_documents');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            _pathProviderChannel,
            (MethodCall call) async => documents.path,
          );
      Storage.flush();
      Config.set('filesystems', <String, dynamic>{
        'default': 'local',
        'disks': <String, dynamic>{
          'local': <String, dynamic>{'driver': 'local', 'root': 'storage'},
          'images': <String, dynamic>{'driver': 'local', 'root': 'pictures'},
        },
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pathProviderChannel, null);
      Storage.setManager(StorageManager());
      Config.flush();
      documents.deleteSync(recursive: true);
    });

    test(
      'is the folder of the images disk in the documents directory',
      () async {
        final MagicImageStore onDisk = await MagicImageStore.onDisk();

        expect(onDisk.directory.path, endsWith('/pictures'));
        expect(onDisk.directory.path, startsWith(documents.path));
        expect(onDisk.maxBytes, MagicImageStore.defaultMaxBytes);
      },
    );

    test('takes the disk and the cap it is given', () async {
      final MagicImageStore onDisk = await MagicImageStore.onDisk(
        disk: 'local',
        maxBytes: 5,
      );

      expect(onDisk.directory.path, endsWith('/storage'));
      expect(onDisk.maxBytes, 5);
    });

    test('a disk that is not local is refused', () async {
      Storage.setManager(_RemoteManager());

      await expectLater(
        MagicImageStore.onDisk(disk: 'cloud'),
        throwsA(isA<MagicImageException>()),
      );
    });
  });
}

/// A manager whose only disk keeps files somewhere other than the device.
class _RemoteManager extends StorageManager {
  @override
  StorageDisk disk([String? name]) => _RemoteDisk();
}

class _RemoteDisk implements StorageDisk {
  @override
  Future<String> url(String path) async => 'https://cdn.example/$path';

  @override
  Future<String> put(String path, dynamic contents, {String? mimeType}) =>
      throw UnimplementedError();

  @override
  Future<Uint8List?> get(String path) => throw UnimplementedError();

  @override
  Future<MagicFile?> getFile(String path) => throw UnimplementedError();

  @override
  Future<bool> exists(String path) => throw UnimplementedError();

  @override
  Future<bool> delete(String path) => throw UnimplementedError();

  @override
  Future<void> download(String path, {String? name}) =>
      throw UnimplementedError();
}
