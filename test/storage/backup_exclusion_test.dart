import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/src/storage/drivers/local/backup_exclusion_io.dart';
import 'package:magic/src/storage/drivers/local/local_adapter_io.dart';
import 'package:path/path.dart' as p;

const MethodChannel _pathProviderChannel = MethodChannel(
  'plugins.flutter.io/path_provider',
);

/// Whether [path] carries the sticky backup exclusion that
/// `kCFURLIsExcludedFromBackupKey` writes, read through `xattr` so the
/// oracle is independent of the CoreFoundation binding under test.
///
/// `tmutil isexcluded` cannot serve here: it reports everything under the
/// system temp directory as excluded already.
Future<bool> _carriesBackupExclusion(String path) async {
  final ProcessResult result = await Process.run('xattr', <String>[
    '-p',
    'com.apple.metadata:com_apple_backup_excludeItem',
    path,
  ]);

  return result.exitCode == 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory documentsDir;
  late List<String> markedPaths;

  void countingMarker(String directoryPath) => markedPaths.add(directoryPath);

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    documentsDir = Directory.systemTemp.createTempSync('magic_backup_');
    markedPaths = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _pathProviderChannel,
          (MethodCall call) async => documentsDir.path,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null);
    Config.flush();
    if (documentsDir.existsSync()) {
      documentsDir.deleteSync(recursive: true);
    }
  });

  group('exclude_from_backup disk option', () {
    test(
      'marks the disk root excluded from backup on the macOS host',
      () async {
        Config.set('filesystems.disks.downloads', <String, dynamic>{
          'driver': 'local',
          'root': 'downloads',
          'exclude_from_backup': true,
        });

        await StorageManager().disk('downloads').url('film.mp4');

        expect(
          await _carriesBackupExclusion(p.join(documentsDir.path, 'downloads')),
          isTrue,
        );
      },
      skip: !Platform.isMacOS,
    );

    test('leaves the disk root in backup when the key is absent', () async {
      Config.set('filesystems.disks.local', <String, dynamic>{
        'driver': 'local',
        'root': 'storage',
      });

      await StorageManager().disk('local').url('avatar.jpg');

      expect(
        await _carriesBackupExclusion(p.join(documentsDir.path, 'storage')),
        isFalse,
      );
    }, skip: !Platform.isMacOS);
  });

  group('LocalAdapter backup marker', () {
    test('never calls the marker without excludeFromBackup', () async {
      final LocalAdapter adapter = LocalAdapter(
        root: 'storage',
        marker: countingMarker,
      );

      await adapter.getUrl('avatar.jpg');

      expect(markedPaths, isEmpty);
    });

    test('marks an existing root once, on the first resolve only', () async {
      final String root = p.join(documentsDir.path, 'downloads');
      Directory(root).createSync();
      final LocalAdapter adapter = LocalAdapter(
        root: 'downloads',
        excludeFromBackup: true,
        marker: countingMarker,
      );

      await adapter.getUrl('film.mp4');
      await adapter.exists('film.mp4');

      expect(markedPaths, <String>[root]);
    });

    test('propagates a failed mark instead of resolving the path', () async {
      final LocalAdapter adapter = LocalAdapter(
        root: 'downloads',
        excludeFromBackup: true,
        marker: (String directoryPath) {
          throw FileSystemException('mark failed', directoryPath);
        },
      );

      await expectLater(
        adapter.getUrl('film.mp4'),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('markExcludedFromBackup', () {
    test('surfaces a false from CoreFoundation for a missing directory', () {
      final String missing = p.join(documentsDir.path, 'missing');

      expect(
        () => markExcludedFromBackup(missing),
        throwsA(isA<FileSystemException>()),
      );
    }, skip: !Platform.isMacOS);
  });
}
