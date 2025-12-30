import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_magic/src/cache/cache_manager.dart';
import 'package:fluttersdk_magic/src/facades/config.dart';
import 'package:fluttersdk_magic/src/cache/drivers/file_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall methodCall) async {
      return '.';
    });
  });

  group('CacheManager', () {
    late CacheManager cache;

    setUp(() async {
      Config.set('cache.driver', FileStore());
      cache = CacheManager();
      // Initialize the file store since we are manually setting it
      // Actually FileStore.init is called by CacheManager.init(), but CacheManager methods call driver().method()
      // FileStore usually requires init.
      // But CacheManager methods proxy to driver.
      // Wait, CacheManager test calls `cache.flush()`.
    });

    test('it can store and retrieve values', () async {
      await cache.put('foo', 'bar');
      expect(cache.get('foo'), 'bar');
    });

    test('it returns default value for missing keys', () {
      expect(cache.get('missing', defaultValue: 'default'), 'default');
    });

    test('it handles expiration', () async {
      // Store with 1 second TTL
      await cache.put('short', 'value', ttl: const Duration(seconds: 1));

      // Should exist immediately
      expect(cache.get('short'), 'value');

      // Wait 2 seconds
      await Future.delayed(const Duration(seconds: 2));

      // Should be gone
      expect(cache.get('short'), null);
    });

    test('it can forget keys', () async {
      await cache.put('forget_me', 'value');
      await cache.forget('forget_me');
      expect(cache.get('forget_me'), null);
    });

    test('has() checks existence and expiry', () async {
      await cache.put('exists', 'val');
      expect(cache.has('exists'), true);

      await cache.put('expired', 'val', ttl: const Duration(milliseconds: 100));
      await Future.delayed(const Duration(milliseconds: 200));
      expect(cache.has('expired'), false);
    });
  });
}
