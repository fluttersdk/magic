import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:fluttersdk_magic/src/storage/magic_file.dart';
import 'package:fluttersdk_magic/src/storage/magic_file_io.dart';

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

    test('toXFile() returns XFile when path is set', () {
      final magicFile = MagicFile(
        path: '/test/path/image.jpg',
        name: 'image.jpg',
        mimeType: 'image/jpeg',
      );

      final xFile = magicFile.toXFile();

      expect(xFile, isA<XFile>());
      expect(xFile.path, '/test/path/image.jpg');
      expect(xFile.name, 'image.jpg');
      expect(xFile.mimeType, 'image/jpeg');
    });

    test('toXFile() throws when path is null', () {
      final magicFile = MagicFile(
        name: 'image.jpg',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(() => magicFile.toXFile(), throwsUnsupportedError);
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

    test('fromXFile() creates MagicFile from XFile', () async {
      final xFile = XFile(testFile.path, name: 'xfile_test.jpg');

      final magicFile = await MagicFileFactory.fromXFile(xFile);

      expect(magicFile.path, testFile.path);
      // Note: XFile.name returns the file basename, not the custom name
      expect(magicFile.name, 'test_image.jpg');
      expect(magicFile.size, 4);
    });

    test('fromXFile() bytes can be read', () async {
      final xFile = XFile(testFile.path);
      final magicFile = await MagicFileFactory.fromXFile(xFile);

      final bytes = await magicFile.readAsBytes();

      expect(bytes, isNotNull);
      expect(bytes!.length, 4);
    });
  });

  group('MagicFile Integration', () {
    late Directory tempDir;

    setUp(() async {
      tempDir =
          await Directory.systemTemp.createTemp('magic_file_integration_');
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

    test('round-trip: XFile -> MagicFile -> XFile', () async {
      final originalFile = File(p.join(tempDir.path, 'original.jpg'));
      await originalFile.writeAsBytes([1, 2, 3, 4, 5]);

      final xFile = XFile(originalFile.path, mimeType: 'image/jpeg');
      final magicFile = await MagicFileFactory.fromXFile(xFile);
      final recoveredXFile = magicFile.toXFile();

      expect(recoveredXFile.path, originalFile.path);
      expect(recoveredXFile.name, 'original.jpg');
      expect(await recoveredXFile.readAsBytes(), [1, 2, 3, 4, 5]);
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
