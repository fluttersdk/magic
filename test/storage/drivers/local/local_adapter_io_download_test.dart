import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/src/storage/drivers/local/local_adapter_io.dart';
import 'package:path/path.dart' as p;

const MethodChannel _pathProviderChannel = MethodChannel(
  'plugins.flutter.io/path_provider',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory documentsDir;
  late LocalAdapter adapter;

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    documentsDir = Directory.systemTemp.createTempSync('magic_download_');
    adapter = LocalAdapter(root: 'storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _pathProviderChannel,
          (MethodCall call) async => documentsDir.path,
        );
  });

  tearDown(() {
    LocalAdapterContract.downloadHandler = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null);
    if (documentsDir.existsSync()) {
      documentsDir.deleteSync(recursive: true);
    }
  });

  File seedFile(String name) {
    final File file = File(p.join(documentsDir.path, 'storage', name));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('payload');

    return file;
  }

  group('LocalAdapter.download', () {
    test(
      'throws UnsupportedError naming magic_picker when no handler is set',
      () async {
        seedFile('a.txt');

        await expectLater(
          adapter.download('a.txt', null),
          throwsA(
            isA<UnsupportedError>().having(
              (UnsupportedError e) => e.message,
              'message',
              contains('magic_picker'),
            ),
          ),
        );
      },
    );

    test('hands the absolute path and the file name to the handler', () async {
      final File file = seedFile('a.txt');
      final List<(String, String)> calls = <(String, String)>[];
      LocalAdapterContract.downloadHandler =
          (String fullPath, String name) async {
            calls.add((fullPath, name));
          };

      await adapter.download('a.txt', null);

      expect(calls, <(String, String)>[(file.path, 'a.txt')]);
    });

    test('prefers the explicit name over the file basename', () async {
      final File file = seedFile('a.txt');
      final List<(String, String)> calls = <(String, String)>[];
      LocalAdapterContract.downloadHandler =
          (String fullPath, String name) async {
            calls.add((fullPath, name));
          };

      await adapter.download('a.txt', 'report.txt');

      expect(calls, <(String, String)>[(file.path, 'report.txt')]);
    });

    test(
      'still throws for a missing file and never calls the handler',
      () async {
        int calls = 0;
        LocalAdapterContract.downloadHandler =
            (String fullPath, String name) async {
              calls++;
            };

        await expectLater(
          adapter.download('missing.txt', null),
          throwsA(isA<Exception>()),
        );
        expect(calls, 0);
      },
    );
  });
}
