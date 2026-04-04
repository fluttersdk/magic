import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  tearDown(() {
    Cache.unfake();
  });

  // ---------------------------------------------------------------------------
  // 1. Basic operations
  // ---------------------------------------------------------------------------

  group('basic operations', () {
    test('put stores a value and get retrieves it', () async {
      final fake = FakeCacheManager();

      await fake.put('user', 'alice');

      expect(fake.get('user'), equals('alice'));
    });

    test('has returns true for existing key', () async {
      final fake = FakeCacheManager();

      await fake.put('token', 'abc123');

      expect(fake.has('token'), isTrue);
    });

    test('has returns false for missing key', () {
      final fake = FakeCacheManager();

      expect(fake.has('missing'), isFalse);
    });

    test('forget removes a key', () async {
      final fake = FakeCacheManager();

      await fake.put('key', 'value');
      await fake.forget('key');

      expect(fake.has('key'), isFalse);
    });

    test('flush clears all keys', () async {
      final fake = FakeCacheManager();

      await fake.put('a', 1);
      await fake.put('b', 2);
      await fake.flush();

      expect(fake.has('a'), isFalse);
      expect(fake.has('b'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Default values
  // ---------------------------------------------------------------------------

  group('default values', () {
    test('get returns defaultValue when key is missing', () {
      final fake = FakeCacheManager();

      final result = fake.get('missing', defaultValue: 'fallback');

      expect(result, equals('fallback'));
    });

    test('get returns null when key is missing and no default', () {
      final fake = FakeCacheManager();

      expect(fake.get('missing'), isNull);
    });

    test('get returns stored value even when defaultValue provided', () async {
      final fake = FakeCacheManager();

      await fake.put('key', 'real');

      expect(fake.get('key', defaultValue: 'fallback'), equals('real'));
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Assertions
  // ---------------------------------------------------------------------------

  group('assertions', () {
    test('assertHas passes when key exists', () async {
      final fake = FakeCacheManager();

      await fake.put('token', 'secret');

      expect(() => fake.assertHas('token'), returnsNormally);
    });

    test('assertHas throws AssertionError when key missing', () {
      final fake = FakeCacheManager();

      expect(() => fake.assertHas('missing'), throwsA(isA<AssertionError>()));
    });

    test('assertMissing passes when key does not exist', () {
      final fake = FakeCacheManager();

      expect(() => fake.assertMissing('ghost'), returnsNormally);
    });

    test('assertMissing throws AssertionError when key exists', () async {
      final fake = FakeCacheManager();

      await fake.put('present', 'value');

      expect(
        () => fake.assertMissing('present'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('assertPut passes when key was stored', () async {
      final fake = FakeCacheManager();

      await fake.put('user', 'bob');

      expect(() => fake.assertPut('user'), returnsNormally);
    });

    test('assertPut throws AssertionError when key was never put', () {
      final fake = FakeCacheManager();

      expect(() => fake.assertPut('never'), throwsA(isA<AssertionError>()));
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Recording
  // ---------------------------------------------------------------------------

  group('recording', () {
    test('records put operations', () async {
      final fake = FakeCacheManager();

      await fake.put('name', 'alice');

      expect(fake.recorded, hasLength(1));
      expect(fake.recorded.first.operation, equals('put'));
      expect(fake.recorded.first.key, equals('name'));
      expect(fake.recorded.first.value, equals('alice'));
    });

    test('records get operations', () async {
      final fake = FakeCacheManager();

      await fake.put('x', 10);
      fake.get('x');

      expect(fake.recorded.where((r) => r.operation == 'get'), hasLength(1));
    });

    test('records forget operations', () async {
      final fake = FakeCacheManager();

      await fake.put('key', 'val');
      await fake.forget('key');

      final forgets = fake.recorded.where((r) => r.operation == 'forget');
      expect(forgets, hasLength(1));
      expect(forgets.first.key, equals('key'));
    });

    test('records flush operations', () async {
      final fake = FakeCacheManager();

      await fake.flush();

      expect(fake.recorded.any((r) => r.operation == 'flush'), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Cache.fake() — facade integration
  // ---------------------------------------------------------------------------

  group('Cache.fake()', () {
    test('returns a FakeCacheManager instance', () {
      final fake = Cache.fake();

      expect(fake, isA<FakeCacheManager>());
    });

    test('facade put/get routes through fake', () async {
      Cache.fake();

      await Cache.put('greeting', 'hello');

      expect(Cache.get('greeting'), equals('hello'));
    });

    test('facade has() routes through fake', () async {
      Cache.fake();

      await Cache.put('exists', true);

      expect(Cache.has('exists'), isTrue);
    });

    test('facade forget() routes through fake', () async {
      Cache.fake();

      await Cache.put('bye', 'value');
      await Cache.forget('bye');

      expect(Cache.has('bye'), isFalse);
    });

    test('facade flush() routes through fake', () async {
      Cache.fake();

      await Cache.put('a', 1);
      await Cache.put('b', 2);
      await Cache.flush();

      expect(Cache.has('a'), isFalse);
      expect(Cache.has('b'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Cache.unfake()
  // ---------------------------------------------------------------------------

  group('Cache.unfake()', () {
    test('can be called without throwing', () {
      Cache.fake();

      expect(() => Cache.unfake(), returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  // 7. driver() and init()
  // ---------------------------------------------------------------------------

  group('driver and init', () {
    test('driver returns a CacheStore', () {
      final fake = FakeCacheManager();

      expect(fake.driver(), isA<CacheStore>());
    });

    test('init completes without error', () async {
      final fake = FakeCacheManager();

      await expectLater(fake.init(), completes);
    });
  });

  // ---------------------------------------------------------------------------
  // 8. reset()
  // ---------------------------------------------------------------------------

  group('reset()', () {
    test('clears the store', () async {
      final fake = FakeCacheManager();

      await fake.put('key', 'value');
      fake.reset();

      expect(fake.has('key'), isFalse);
    });

    test('clears recorded list', () async {
      final fake = FakeCacheManager();

      await fake.put('key', 'value');
      fake.get('key');
      fake.reset();

      expect(fake.recorded, isEmpty);
    });
  });
}
