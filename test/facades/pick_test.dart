import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:magic/src/facades/pick.dart';
import 'package:magic/src/foundation/application.dart';
import 'package:magic/src/foundation/magic.dart';

/// A [PlatformFile] whose members are supplied by the test.
///
/// `file_picker` 12 turned [PlatformFile] into an abstract base class whose
/// content is read lazily, so a fake has to answer the read methods rather
/// than expose byte and length fields.
final class FakePlatformFile extends PlatformFile {
  @override
  final String name;

  @override
  final Uri uri;

  /// The length the platform reported at pick time, or null when it reported
  /// none. Mirrors [PlatformFile.lengthSync]'s nullable contract.
  final int? reportedLength;

  /// The bytes [readAsBytes] resolves with.
  final Uint8List content;

  FakePlatformFile({
    required this.name,
    required this.uri,
    required this.content,
    this.reportedLength,
  });

  @override
  XFile get xFile => XFile(uri.toString());

  @override
  int? lengthSync() => reportedLength;

  /// Mirrors every shipped platform file: hand back the size the picker
  /// reported, and fall back to measuring the file when it reported none.
  @override
  Future<int> length() async => reportedLength ?? content.length;

  @override
  Future<Uint8List> readAsBytes() async => content;

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(content);
}

/// A [FilePickerPlatform] that answers with whatever the test staged, and
/// records the arguments the [Pick] facade forwarded.
class FakeFilePickerPlatform extends FilePickerPlatform {
  PlatformFile? singleFile;
  List<PlatformFile> multipleFiles = const [];
  String? directoryPath;
  Uri? savedUri;

  bool pickFileCalled = false;
  bool pickFilesCalled = false;

  FileType? lastType;
  List<String>? lastAllowedExtensions;
  String? lastSaveFileName;
  Uint8List? lastSaveBytes;
  String? lastSaveMimeType;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    pickFileCalled = true;
    lastType = type;
    lastAllowedExtensions = allowedExtensions;

    return singleFile;
  }

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    pickFilesCalled = true;
    lastType = type;
    lastAllowedExtensions = allowedExtensions;

    return multipleFiles;
  }

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    return directoryPath;
  }

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    lastSaveFileName = fileName;
    lastSaveBytes = bytes;
    lastSaveMimeType = mimeType;

    return savedUri;
  }
}

void main() {
  late FakeFilePickerPlatform platform;

  setUp(() {
    MagicApp.reset();
    Magic.flush();

    platform = FakeFilePickerPlatform();
    FilePickerPlatform.instance = platform;
  });

  group('Pick.file', () {
    test('returns null when the user cancels', () async {
      platform.singleFile = null;

      expect(await Pick.file(), isNull);
    });

    test('picks through the single-file API, not the multi-file one', () async {
      platform.singleFile = FakePlatformFile(
        name: 'report.pdf',
        uri: Uri.file('/tmp/report.pdf'),
        content: Uint8List.fromList([1, 2, 3]),
      );

      await Pick.file();

      expect(platform.pickFileCalled, isTrue);
      expect(platform.pickFilesCalled, isFalse);
    });

    test('maps the picked file onto MagicFile', () async {
      platform.singleFile = FakePlatformFile(
        name: 'report.pdf',
        uri: Uri.file('/tmp/report.pdf'),
        content: Uint8List.fromList([1, 2, 3]),
        reportedLength: 3,
      );

      final file = await Pick.file();

      expect(file!.name, 'report.pdf');
      expect(file.path, '/tmp/report.pdf');
      expect(file.size, 3);
      expect(file.mimeType, 'application/pdf');
      expect(file.extension, 'pdf');
    });

    test('reads bytes lazily through the platform file', () async {
      platform.singleFile = FakePlatformFile(
        name: 'note.txt',
        uri: Uri.file('/tmp/note.txt'),
        content: Uint8List.fromList([7, 8, 9]),
      );

      final file = await Pick.file();

      expect(await file!.readAsBytes(), [7, 8, 9]);
    });

    test('measures the file when the picker reports no size', () async {
      // The Windows and Linux pickers return a path and no size, so
      // lengthSync() is null there and only length() answers.
      platform.singleFile = FakePlatformFile(
        name: 'export.bin',
        uri: Uri.file('/tmp/export.bin'),
        content: Uint8List.fromList([1, 2, 3, 4]),
      );

      final file = await Pick.file();

      expect(file!.size, 4);
    });

    test('leaves path null for a non-file uri', () async {
      platform.singleFile = FakePlatformFile(
        name: 'blob.png',
        uri: Uri.parse('blob:https://example.com/abc'),
        content: Uint8List.fromList([1]),
      );

      final file = await Pick.file();

      expect(file!.path, isNull);
    });

    test('filters by custom extensions when given', () async {
      await Pick.file(extensions: ['pdf', 'doc']);

      expect(platform.lastType, FileType.custom);
      expect(platform.lastAllowedExtensions, ['pdf', 'doc']);
    });

    test('picks any type when no extension is given', () async {
      await Pick.file();

      expect(platform.lastType, FileType.any);
      expect(platform.lastAllowedExtensions, isNull);
    });
  });

  group('Pick.files', () {
    test('returns an empty list when the user cancels', () async {
      platform.multipleFiles = const [];

      expect(await Pick.files(), isEmpty);
    });

    test('maps every picked file', () async {
      platform.multipleFiles = [
        FakePlatformFile(
          name: 'a.png',
          uri: Uri.file('/tmp/a.png'),
          content: Uint8List.fromList([1]),
        ),
        FakePlatformFile(
          name: 'b.jpg',
          uri: Uri.file('/tmp/b.jpg'),
          content: Uint8List.fromList([2]),
        ),
      ];

      final files = await Pick.files();

      expect(files.map((file) => file.name), ['a.png', 'b.jpg']);
      expect(files.map((file) => file.mimeType), ['image/png', 'image/jpeg']);
    });

    test('picks through the multi-file API', () async {
      await Pick.files();

      expect(platform.pickFilesCalled, isTrue);
      expect(platform.pickFileCalled, isFalse);
    });
  });

  group('Pick.directory', () {
    test('returns the selected directory path', () async {
      platform.directoryPath = '/tmp/documents';

      expect(await Pick.directory(), '/tmp/documents');
    });

    test('returns null when the user cancels', () async {
      platform.directoryPath = null;

      expect(await Pick.directory(), isNull);
    });
  });

  group('Pick.saveFile', () {
    test('returns the uri the platform saved to', () async {
      platform.savedUri = Uri.file('/tmp/report.pdf');

      final uri = await Pick.saveFile(
        fileName: 'report.pdf',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(uri, Uri.file('/tmp/report.pdf'));
    });

    test('returns null when the user cancels', () async {
      platform.savedUri = null;

      final uri = await Pick.saveFile(
        fileName: 'report.pdf',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(uri, isNull);
    });

    test('derives the mime type from the file name', () async {
      await Pick.saveFile(
        fileName: 'report.pdf',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(platform.lastSaveMimeType, 'application/pdf');
    });

    test('falls back to a binary mime type for an unknown extension', () async {
      await Pick.saveFile(
        fileName: 'archive.xyz',
        bytes: Uint8List.fromList([1]),
      );

      expect(platform.lastSaveMimeType, 'application/octet-stream');
    });

    test(
      'falls back to a binary mime type when the name has no extension',
      () async {
        await Pick.saveFile(fileName: 'report', bytes: Uint8List.fromList([1]));

        expect(platform.lastSaveMimeType, 'application/octet-stream');
      },
    );

    test('forwards an explicit mime type unchanged', () async {
      await Pick.saveFile(
        fileName: 'report.bin',
        bytes: Uint8List.fromList([1]),
        mimeType: 'application/pdf',
      );

      expect(platform.lastSaveMimeType, 'application/pdf');
    });
  });
}
