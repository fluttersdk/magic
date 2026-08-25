import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/cache/drivers/file_store.dart';
import 'package:magic/src/facades/config.dart';

/// `get()` is synchronous, so the `_persist()` it used to fire on an eviction
/// could not be awaited. That left two problems on the READ path of a cache:
/// a whole-file rewrite per expired key read, and a Future whose failure had
/// nowhere to go, which on a full disk or a revoked permission surfaces as an
/// unhandled async error rather than as a cache miss.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    // ONE directory for the whole file. Creating it inside the handler would
    // hand every `init()` a fresh empty directory, and a test that reopens the
    // store to check persistence would then be asserting against a store that
    // never saw the first one's file.
    tempDir = Directory.systemTemp.createTempSync('magic_read_path_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return tempDir.path;
        });
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('reading the cache does not write to disk', () {
    late FileStore store;
    late File file;

    setUp(() async {
      Config.set('cache.ttl', 3600);
      store = FileStore(fileName: 'read_path_cache');
      await store.init();
      await store.flush();
      file = File('${tempDir.path}/read_path_cache.json');
    });

    test('an expired read leaves the file untouched', () async {
      await store.put('k', 'v', ttl: const Duration(milliseconds: 1));
      final int writtenAt = file.lastModifiedSync().millisecondsSinceEpoch;
      final int sizeBefore = file.lengthSync();

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(store.get('k'), isNull, reason: 'the entry has expired');
      // Give any fire-and-forget write time to land before asserting it did
      // not happen; without this the assertion could pass on timing alone.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(file.lastModifiedSync().millisecondsSinceEpoch, writtenAt);
      expect(file.lengthSync(), sizeBefore);
    });

    test('a malformed entry read leaves the file untouched', () async {
      // Seeded through the file rather than through a test-only API on the
      // store: this is exactly how such a row arrives in the wild, written by
      // an older shape that stored the bare value instead of the
      // {payload, expire_at} map.
      file.writeAsStringSync('{"legacy":"a bare string"}');
      final seeded = FileStore(fileName: 'read_path_cache');
      await seeded.init();
      final int writtenAt = file.lastModifiedSync().millisecondsSinceEpoch;

      expect(seeded.get('legacy'), isNull);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        file.lastModifiedSync().millisecondsSinceEpoch,
        writtenAt,
        reason: 'the read must not rewrite the file',
      );
    });

    test('the evicted key stays gone in memory', () async {
      await store.put('k', 'v', ttl: const Duration(milliseconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(store.get('k'), isNull);
      expect(store.get('k'), isNull, reason: 'still evicted on a second read');
      expect(store.has('k'), isFalse);
    });

    test('a later write cleans the expired entry off disk', () async {
      // Dropping the write from the read path means the disk copy converges on
      // the next write rather than immediately. This pins that it converges.
      await store.put('stale', 'v', ttl: const Duration(milliseconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      store.get('stale');

      await store.put('fresh', 'v');

      expect(file.readAsStringSync(), isNot(contains('stale')));
      expect(file.readAsStringSync(), contains('fresh'));
    });

    test('a live entry survives a reload from disk', () async {
      await store.put('alive', 'value', ttl: const Duration(hours: 1));

      final reopened = FileStore(fileName: 'read_path_cache');
      await reopened.init();

      expect(reopened.get('alive'), 'value');
    });

    test('an expired entry is not served after a reload', () async {
      await store.put('dead', 'value', ttl: const Duration(milliseconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final reopened = FileStore(fileName: 'read_path_cache');
      await reopened.init();

      expect(
        reopened.get('dead'),
        isNull,
        reason: 'expiry is re-checked on read, so a lingering row is inert',
      );
    });
  });
}
