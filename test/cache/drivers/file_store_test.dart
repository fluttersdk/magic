import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/cache/drivers/file_store.dart';
import 'package:magic/src/facades/config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Set up temporary directory for file tests
  late Directory tempDir;

  setUpAll(() async {
    // Mock path_provider
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      tempDir = Directory.systemTemp.createTempSync('magic_test_');
      return tempDir.path;
    });
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('FileStore Driver', () {
    late FileStore store;

    setUp(() async {
      Config.set('cache.ttl', 3600); // 1 hour default
      store = FileStore(fileName: 'test_cache');
      await store.init();
      await store.flush();
    });

    test('it initializes correctly', () async {
      expect(store, isNotNull);
    });

    test('it stores and retrieves values', () async {
      await store.put('foo', 'bar');
      expect(store.get('foo'), 'bar');
    });

    test('it returns default value if key missing', () async {
      expect(store.get('missing', defaultValue: 'default'), 'default');
    });

    test('it handles expiration', () async {
      // 100ms TTL
      await store.put('short', 'value', ttl: const Duration(milliseconds: 100));
      expect(store.get('short'), 'value');

      await Future.delayed(const Duration(milliseconds: 200));
      expect(store.get('short'), null);
    });

    test('it verifies existence with has()', () async {
      await store.put('exists', 'yep');
      expect(store.has('exists'), isTrue);
      expect(store.has('missing'), isFalse);
    });

    test('it removes items with forget()', () async {
      await store.put('remove_me', 'data');
      await store.forget('remove_me');
      expect(store.has('remove_me'), isFalse);
    });

    test('it clears all items with flush()', () async {
      await store.put('a', 1);
      await store.put('b', 2);
      await store.flush();
      expect(store.has('a'), isFalse);
      expect(store.has('b'), isFalse);
    });
  });
}
