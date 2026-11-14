import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:magic/src/storage/magic_file.dart';
import 'package:magic/src/storage/magic_file_io.dart';

void main() {
  group('MagicFileIOExtensions', () {
    test('toFile() returns File when path is set', () {
      final magicFile = MagicFile(
        path: '/test/path/image.jpg',
        name: 'image.jpg',
      );

      final file = magicFile.toFile();

      expect(file, isA<File>());
      expect(file.path, '/test/path/image.jpg');
    });

    test('toFile() throws when path is null', () {
      final magicFile = MagicFile(
        name: 'image.jpg',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(() => magicFile.toFile(), throwsUnsupportedError);
    });
  });

  group('MagicFileFactory', () {
    late Directory tempDir;
    late File testFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('magic_file_test_');
      testFile = File(p.join(tempDir.path, 'test_image.jpg'));
      await testFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]); // JPEG header
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('fromFile() creates MagicFile from File', () async {
      final magicFile = await MagicFileFactory.fromFile(testFile);

      expect(magicFile.path, testFile.path);
      expect(magicFile.name, 'test_image.jpg');
      expect(magicFile.size, 4);
      expect(magicFile.mimeType, 'image/jpeg');
    });

    test('fromFile() with custom mimeType overrides detection', () async {
      final magicFile = await MagicFileFactory.fromFile(
        testFile,
        mimeType: 'application/custom',
      );

      expect(magicFile.mimeType, 'application/custom');
    });

    test('fromFile() bytes can be read lazily', () async {
      final magicFile = await MagicFileFactory.fromFile(testFile);

      final bytes = await magicFile.readAsBytes();

      expect(bytes, isNotNull);
      expect(bytes!.length, 4);
      expect(bytes[0], 0xFF); // JPEG marker
    });
  });

  group('MagicFile Integration', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'magic_file_integration_',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('round-trip: File -> MagicFile -> File', () async {
      final originalFile = File(p.join(tempDir.path, 'original.txt'));
      await originalFile.writeAsString('Hello Magic!');

      final magicFile = await MagicFileFactory.fromFile(originalFile);
      final recoveredFile = magicFile.toFile();

      expect(await recoveredFile.readAsString(), 'Hello Magic!');
    });

    test('MagicFile properties preserved through conversions', () async {
      final originalFile = File(p.join(tempDir.path, 'photo.png'));
      await originalFile.writeAsBytes([0x89, 0x50, 0x4E, 0x47]); // PNG header

      final magicFile = await MagicFileFactory.fromFile(originalFile);

      expect(magicFile.extension, 'png');
      expect(magicFile.isImage, isTrue);
      expect(magicFile.isVideo, isFalse);
      expect(magicFile.mimeType, 'image/png');
    });

    test('MagicFile video detection works', () async {
      final videoFile = File(p.join(tempDir.path, 'video.mp4'));
      await videoFile.writeAsBytes([0, 0, 0, 32]);

      final magicFile = await MagicFileFactory.fromFile(videoFile);

      expect(magicFile.extension, 'mp4');
      expect(magicFile.isVideo, isTrue);
      expect(magicFile.isImage, isFalse);
      expect(magicFile.mimeType, 'video/mp4');
    });
  });
}
