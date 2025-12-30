import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_magic/src/storage/magic_file.dart';
import 'package:fluttersdk_magic/src/facades/config.dart';

void main() {
  group('MagicFile', () {
    test('extension returns file extension without dot', () {
      final file = MagicFile(name: 'photo.jpg');
      expect(file.extension, 'jpg');
    });

    test('extension handles multiple dots', () {
      final file = MagicFile(name: 'archive.tar.gz');
      expect(file.extension, 'gz');
    });

    test('extension returns empty for no extension', () {
      final file = MagicFile(name: 'README');
      expect(file.extension, '');
    });

    test('isImage returns true for image extensions', () {
      expect(MagicFile(name: 'a.jpg').isImage, isTrue);
      expect(MagicFile(name: 'b.png').isImage, isTrue);
      expect(MagicFile(name: 'c.gif').isImage, isTrue);
      expect(MagicFile(name: 'd.webp').isImage, isTrue);
      expect(MagicFile(name: 'e.heic').isImage, isTrue);
    });

    test('isImage returns false for non-image extensions', () {
      expect(MagicFile(name: 'a.pdf').isImage, isFalse);
      expect(MagicFile(name: 'b.mp4').isImage, isFalse);
      expect(MagicFile(name: 'c.txt').isImage, isFalse);
    });

    test('isVideo returns true for video extensions', () {
      expect(MagicFile(name: 'a.mp4').isVideo, isTrue);
      expect(MagicFile(name: 'b.mov').isVideo, isTrue);
      expect(MagicFile(name: 'c.avi').isVideo, isTrue);
      expect(MagicFile(name: 'd.mkv').isVideo, isTrue);
    });

    test('isVideo returns false for non-video extensions', () {
      expect(MagicFile(name: 'a.jpg').isVideo, isFalse);
      expect(MagicFile(name: 'b.pdf').isVideo, isFalse);
    });

    test('readAsBytes returns cached bytes', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final file = MagicFile(name: 'test.bin', bytes: bytes);

      final result = await file.readAsBytes();

      expect(result, equals(bytes));
    });

    test('readAsBytes calls bytesReader if no cached bytes', () async {
      final bytes = Uint8List.fromList([4, 5, 6]);
      var readerCalled = false;

      final file = MagicFile(
        name: 'test.bin',
        bytesReader: () async {
          readerCalled = true;
          return bytes;
        },
      );

      final result = await file.readAsBytes();

      expect(readerCalled, isTrue);
      expect(result, equals(bytes));
    });

    test('readAsBytes caches result from bytesReader', () async {
      var callCount = 0;
      final bytes = Uint8List.fromList([7, 8, 9]);

      final file = MagicFile(
        name: 'test.bin',
        bytesReader: () async {
          callCount++;
          return bytes;
        },
      );

      await file.readAsBytes();
      await file.readAsBytes();

      expect(callCount, 1);
    });

    test('readAsBytes returns null if no bytes and no reader', () async {
      final file = MagicFile(name: 'empty.bin');

      final result = await file.readAsBytes();

      expect(result, isNull);
    });

    test('toString includes name, size, and mimeType', () {
      final file = MagicFile(
        name: 'doc.pdf',
        size: 1024,
        mimeType: 'application/pdf',
      );

      expect(file.toString(), contains('doc.pdf'));
      expect(file.toString(), contains('1024'));
      expect(file.toString(), contains('application/pdf'));
    });

    group('store()', () {
      setUp(() {
        Config.set('filesystems.default', 'local');
        Config.set('filesystems.disks.local', {
          'driver': 'local',
          'root': 'test_storage',
        });
      });

      tearDown(() {
        Config.flush();
      });

      test('throws if bytes cannot be read', () async {
        final file = MagicFile(name: 'empty.bin');

        expect(
          () => file.store('path/to/file.bin'),
          throwsException,
        );
      });
    });
  });
}
