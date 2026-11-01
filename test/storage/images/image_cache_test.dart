import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

const String _url = 'https://img.example/p/1.jpg';

const MethodChannel _pathProviderChannel = MethodChannel(
  'plugins.flutter.io/path_provider',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory folder;
  late MagicImageStore store;
  late DateTime now;
  late List<Uri> asked;
  late Future<Uint8List> Function(Uri url) answer;
  late MagicImageCache cache;
  late FakeLogManager log;

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    // A trim that fails only logs, and no log is bound in a unit test.
    log = Log.fake();
    folder = Directory.systemTemp.createTempSync('magic_image_cache');
    store = MagicImageStore(folder, maxBytes: 100000);
    now = DateTime(2026, 11, 1, 12);
    asked = <Uri>[];
    answer = (Uri url) async => Uint8List.fromList(<int>[1, 2, 3]);
    cache = MagicImageCache(
      store: store,
      fetch: (Uri url) {
        asked.add(url);

        return answer(url);
      },
      now: () => now,
    );
  });

  tearDown(() {
    if (folder.existsSync()) folder.deleteSync(recursive: true);
  });

  group('file', () {
    test('fetches an image once and reads it from the disk after', () async {
      final File first = await cache.file(_url);
      final File second = await cache.file(_url);

      expect(asked, <Uri>[Uri.parse(_url)]);
      expect(second.path, first.path);
      expect(await second.readAsBytes(), <int>[1, 2, 3]);
    });

    test(
      'a second ask while the first is in flight shares its fetch',
      () async {
        final Completer<Uint8List> gate = Completer<Uint8List>();
        answer = (Uri url) => gate.future;

        final Future<File> one = cache.file(_url);
        final Future<File> two = cache.file(_url);
        gate.complete(Uint8List.fromList(<int>[9]));

        expect((await one).path, (await two).path);
        expect(asked, hasLength(1));
      },
    );

    test('an image on the disk is never fetched', () async {
      await store.write(_url, Uint8List.fromList(<int>[5]));

      await cache.file(_url);

      expect(asked, isEmpty);
    });

    test('a failed fetch throws and stores nothing', () async {
      answer = (Uri url) async => throw const MagicImageException('no');

      await expectLater(cache.file(_url), throwsA(isA<MagicImageException>()));

      expect(await store.find(_url), isNull);
    });

    test(
      'a failed url is not asked again until the retry window ends',
      () async {
        answer = (Uri url) async => throw const MagicImageException('no');
        await expectLater(
          cache.file(_url),
          throwsA(isA<MagicImageException>()),
        );

        now = now.add(cache.retryAfter - const Duration(seconds: 1));
        await expectLater(
          cache.file(_url),
          throwsA(isA<MagicImageException>()),
        );
        expect(asked, hasLength(1));

        now = now.add(const Duration(seconds: 2));
        answer = (Uri url) async => Uint8List.fromList(<int>[1]);
        final File file = await cache.file(_url);

        expect(asked, hasLength(2));
        expect(await file.readAsBytes(), <int>[1]);
      },
    );

    test('the retry window is the one the cache was given', () async {
      cache = MagicImageCache(
        store: store,
        retryAfter: const Duration(seconds: 10),
        fetch: (Uri url) {
          asked.add(url);

          return answer(url);
        },
        now: () => now,
      );
      answer = (Uri url) async => throw const MagicImageException('no');
      await expectLater(cache.file(_url), throwsA(isA<MagicImageException>()));

      now = now.add(const Duration(seconds: 11));
      await expectLater(cache.file(_url), throwsA(isA<MagicImageException>()));

      expect(asked, hasLength(2));
    });

    test('one failed url does not hold back another', () async {
      answer = (Uri url) async => url.path == '/p/1.jpg'
          ? throw const MagicImageException('no')
          : Uint8List.fromList(<int>[1]);

      await expectLater(cache.file(_url), throwsA(isA<MagicImageException>()));

      expect(await cache.file('https://img.example/p/2.jpg'), isA<File>());
    });

    test('an address that is not a url fails without a request', () async {
      await expectLater(
        cache.file('http://[bad'),
        throwsA(isA<MagicImageException>()),
      );

      expect(asked, isEmpty);
    });

    test('a disk that will not keep the bytes hands them over, and the host is '
        'not blamed', () async {
      // A file where the folder should be: the write cannot succeed.
      folder.deleteSync(recursive: true);
      File(folder.path).writeAsBytesSync(<int>[0]);
      addTearDown(() {
        if (FileSystemEntity.isFileSync(folder.path)) {
          File(folder.path).deleteSync();
        }
      });

      for (int i = 1; i <= 2; i++) {
        await expectLater(
          cache.file(_url),
          throwsA(
            isA<MagicImageNotStored>().having(
              (MagicImageNotStored e) => e.bytes,
              'bytes',
              <int>[1, 2, 3],
            ),
          ),
        );
        expect(asked, hasLength(i), reason: 'asked again, not refused');
      }
    });
  });

  group('stand-ins', () {
    test('a key that was never noted is not due', () {
      expect(cache.standInDue('key'), isFalse);
    });

    test('is due once the window ends, and only once', () {
      cache.noteStandIn('key');

      now = now.add(cache.retryAfter - const Duration(seconds: 1));
      expect(cache.standInDue('key'), isFalse);

      now = now.add(const Duration(seconds: 2));
      expect(cache.standInDue('key'), isTrue);
      expect(cache.standInDue('key'), isFalse, reason: 'the note is spent');
    });

    test('a key noted again starts its window again', () {
      cache.noteStandIn('key');
      now = now.add(cache.retryAfter - const Duration(seconds: 1));
      cache.noteStandIn('key');
      now = now.add(const Duration(seconds: 2));

      expect(cache.standInDue('key'), isFalse);
    });

    test('keys are told apart', () {
      cache.noteStandIn('one');
      now = now.add(cache.retryAfter);

      expect(cache.standInDue('two'), isFalse);
      expect(cache.standInDue('one'), isTrue);
    });

    test('the oldest notes go first when a thousand are held', () {
      for (int i = 0; i < 1001; i++) {
        cache.noteStandIn('key $i');
      }
      now = now.add(cache.retryAfter);

      expect(cache.standInDue('key 0'), isFalse);
      expect(cache.standInDue('key 1000'), isTrue);
    });
  });

  group('reject', () {
    test('removes the bytes and refuses the url for the window', () async {
      await cache.file(_url);

      await cache.reject(_url);

      expect(await cache.stored(_url), isNull);
      await expectLater(cache.file(_url), throwsA(isA<MagicImageException>()));
      expect(asked, hasLength(1));

      now = now.add(cache.retryAfter);
      expect(await cache.file(_url), isA<File>());
      expect(asked, hasLength(2));
    });
  });

  group('stored and forget', () {
    test('stored is null until the image was fetched', () async {
      expect(await cache.stored(_url), isNull);

      await cache.file(_url);

      expect(await cache.stored(_url), isNotNull);
    });

    test('forget removes the bytes so the next ask fetches again', () async {
      await cache.file(_url);

      await cache.forget(_url);

      expect(await cache.stored(_url), isNull);
      await cache.file(_url);
      expect(asked, hasLength(2));
    });
  });

  group('clear', () {
    test(
      'removes every image and forgets the failures and the stand-ins',
      () async {
        cache.noteStandIn('key');
        now = now.add(cache.retryAfter);

        await cache.file(_url);
        answer = (Uri url) async => throw const MagicImageException('no');
        await expectLater(
          cache.file('https://img.example/p/2.jpg'),
          throwsA(isA<MagicImageException>()),
        );

        await cache.clear();

        expect(await cache.stored(_url), isNull);
        expect(cache.standInDue('key'), isFalse);
        answer = (Uri url) async => Uint8List.fromList(<int>[1]);
        expect(await cache.file('https://img.example/p/2.jpg'), isA<File>());
      },
    );
  });

  group('sweep', () {
    test('trims the store it keeps', () async {
      final MagicImageStore small = MagicImageStore(folder, maxBytes: 1000);
      cache = MagicImageCache(
        store: small,
        fetch: (Uri url) async => Uint8List(1),
      );

      await small.write('https://img.example/1.jpg', Uint8List(600));
      await small.write('https://img.example/2.jpg', Uint8List(600));

      expect(await cache.sweep(), greaterThan(0));
    });

    test('runs again once a quarter of the cap has been written', () async {
      final MagicImageStore small = MagicImageStore(folder, maxBytes: 1000);
      answer = (Uri url) async => Uint8List(300);
      cache = MagicImageCache(
        store: small,
        fetch: (Uri url) => answer(url),
        now: () => now,
      );

      for (int i = 0; i < 6; i++) {
        await cache.file('https://img.example/$i.jpg');
        // A sweep orders by use, and writes in one millisecond tie.
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      int total() => folder.listSync().whereType<File>().fold(
        0,
        (int sum, File file) => sum + file.lengthSync(),
      );

      for (int i = 0; i < 100 && total() > 1000; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      expect(total(), lessThanOrEqualTo(1000));
    });
  });

  group('on the images disk', () {
    late Directory documents;
    late int opened;
    late bool failOpening;

    setUp(() {
      documents = Directory.systemTemp.createTempSync('magic_image_documents');
      opened = 0;
      failOpening = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pathProviderChannel, (
            MethodCall call,
          ) async {
            opened++;
            if (failOpening) {
              throw PlatformException(code: 'unavailable');
            }

            return documents.path;
          });
      Storage.flush();
      Config.set('filesystems', <String, dynamic>{
        'default': 'local',
        'disks': <String, dynamic>{
          'local': <String, dynamic>{'driver': 'local', 'root': 'storage'},
          'images': <String, dynamic>{'driver': 'local', 'root': 'images'},
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
      'the first use trims the folder to its cap, behind the call',
      () async {
        final MagicImageStore disk = await MagicImageStore.onDisk(
          maxBytes: 100,
        );

        for (int i = 0; i < 4; i++) {
          await disk.write('https://img.example/$i.jpg', Uint8List(60));
        }

        final MagicImageCache onDisk = MagicImageCache(maxBytes: 100);

        expect(await onDisk.stored('https://img.example/0.jpg'), isNotNull);

        // The sweep is not awaited by the call: it lands a moment after.
        for (int i = 0; i < 100 && disk.directory.listSync().length > 1; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }

        expect(disk.directory.listSync(), hasLength(1));
      },
    );

    test('a store is trimmed once per cache, not on every use', () async {
      final MagicImageStore disk = await MagicImageStore.onDisk(maxBytes: 100);
      final MagicImageCache onDisk = MagicImageCache(maxBytes: 100);

      await onDisk.stored('https://img.example/x.jpg');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Written after the first trim: a second trim would take them away.
      for (int i = 0; i < 4; i++) {
        await disk.write('https://img.example/$i.jpg', Uint8List(60));
      }
      await onDisk.stored('https://img.example/x.jpg');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(disk.directory.listSync(), hasLength(4));
    });

    test('the cache names the disk it lives on', () async {
      Config.set('filesystems.disks.pictures', <String, dynamic>{
        'driver': 'local',
        'root': 'pictures',
      });
      final MagicImageCache onDisk = MagicImageCache(
        disk: 'pictures',
        fetch: (Uri url) async => Uint8List(3),
      );

      await onDisk.file('https://img.example/x.jpg');

      expect(Directory('${documents.path}/pictures').existsSync(), isTrue);
      expect(Directory('${documents.path}/images').existsSync(), isFalse);
    });

    test(
      'a disk that cannot be opened is reported once and tried again',
      () async {
        final MagicImageCache onDisk = MagicImageCache(
          fetch: (Uri url) async => Uint8List.fromList(<int>[1, 2, 3]),
        );

        failOpening = true;

        // No copy to read, and no throw: the picture is not the disk's.
        expect(await onDisk.stored('https://img.example/x.jpg'), isNull);
        expect(await onDisk.stored('https://img.example/x.jpg'), isNull);
        expect(await onDisk.sweep(), 0);
        await onDisk.clear();
        await onDisk.forget('https://img.example/x.jpg');
        expect(log.entries, hasLength(1));
        expect(log.entries.single.level, 'warning');
        expect(log.entries.single.message, contains('"images" disk'));

        // The bytes come back to be drawn, nothing is held against the host.
        for (int i = 0; i < 2; i++) {
          await expectLater(
            onDisk.file('https://img.example/x.jpg'),
            throwsA(isA<MagicImageNotStored>()),
          );
        }

        // The platform answers now: the disk opens and keeps images.
        failOpening = false;
        final File kept = await onDisk.file('https://img.example/x.jpg');

        expect(kept.existsSync(), isTrue);
        expect(await onDisk.stored('https://img.example/x.jpg'), isNotNull);
        expect(opened, greaterThan(1), reason: 'the open was tried again');
      },
    );
  });
}
