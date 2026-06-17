// Tests that CacheManager dispatches CacheHit / CacheMiss / CachePut /
// CacheForget / CacheFlush via EventDispatcher so MagicCacheWatcher
// (telescope-side) can capture the operation lifecycle.
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;
import 'package:magic/magic.dart';

/// Recording listener — captures every event it receives in dispatch order.
class _RecordingListener<T extends MagicEvent> extends MagicListener<T> {
  final List<T> received = <T>[];

  @override
  Future<void> handle(T event) async {
    received.add(event);
  }
}

/// In-memory CacheStore used as the active driver under test. Mirrors the
/// FileStore contract minimally so CacheManager can proxy through it
/// without disk I/O.
class _InMemoryStore implements CacheStore {
  final Map<String, dynamic> _data = <String, dynamic>{};

  @override
  Future<void> init() async {}

  @override
  dynamic get(String key, {dynamic defaultValue}) =>
      _data.containsKey(key) ? _data[key] : defaultValue;

  @override
  Future<void> put(String key, dynamic value, {Duration? ttl}) async {
    _data[key] = value;
  }

  @override
  bool has(String key) => _data.containsKey(key);

  @override
  Future<void> forget(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> flush() async {
    _data.clear();
  }
}

void main() {
  group('CacheManager event dispatch', () {
    late CacheManager manager;
    late _RecordingListener<CacheHit> hitListener;
    late _RecordingListener<CacheMiss> missListener;
    late _RecordingListener<CachePut> putListener;
    late _RecordingListener<CacheForget> forgetListener;
    late _RecordingListener<CacheFlush> flushListener;

    setUp(() {
      MagicApp.reset();
      Magic.flush();
      EventDispatcher.instance.clear();

      Config.set('cache.driver', _InMemoryStore());
      manager = CacheManager();

      hitListener = _RecordingListener<CacheHit>();
      missListener = _RecordingListener<CacheMiss>();
      putListener = _RecordingListener<CachePut>();
      forgetListener = _RecordingListener<CacheForget>();
      flushListener = _RecordingListener<CacheFlush>();

      EventDispatcher.instance.register(CacheHit, <MagicListener Function()>[
        () => hitListener,
      ]);
      EventDispatcher.instance.register(CacheMiss, <MagicListener Function()>[
        () => missListener,
      ]);
      EventDispatcher.instance.register(CachePut, <MagicListener Function()>[
        () => putListener,
      ]);
      EventDispatcher.instance.register(CacheForget, <MagicListener Function()>[
        () => forgetListener,
      ]);
      EventDispatcher.instance.register(CacheFlush, <MagicListener Function()>[
        () => flushListener,
      ]);
    });

    tearDown(() {
      EventDispatcher.instance.clear();
      MagicApp.reset();
      Magic.flush();
    });

    test('put dispatches CachePut with key, value, ttl', () async {
      await manager.put('k', 'v', ttl: const Duration(seconds: 30));

      expect(putListener.received, hasLength(1));
      expect(putListener.received.single.key, equals('k'));
      expect(putListener.received.single.value, equals('v'));
      expect(
        putListener.received.single.ttl,
        equals(const Duration(seconds: 30)),
      );
    });

    test('get dispatches CacheHit when value is found', () async {
      await manager.put('k', 'v');
      hitListener.received.clear(); // ignore the CachePut + any prior

      final value = manager.get('k');
      expect(value, equals('v'));

      expect(hitListener.received, hasLength(1));
      expect(hitListener.received.single.key, equals('k'));
      expect(hitListener.received.single.value, equals('v'));
      expect(missListener.received, isEmpty);
    });

    test(
      'get dispatches CacheMiss when key absent (returns defaultValue)',
      () async {
        manager.get('absent');

        expect(missListener.received, hasLength(1));
        expect(missListener.received.single.key, equals('absent'));
        expect(hitListener.received, isEmpty);
      },
    );

    test(
      'get dispatches CacheHit when the stored value equals defaultValue',
      () async {
        await manager.put('k', 'v');
        hitListener.received.clear();

        final value = manager.get('k', defaultValue: 'v');
        expect(value, equals('v'));

        // Presence, not value-vs-default equality, decides hit/miss.
        expect(hitListener.received, hasLength(1));
        expect(hitListener.received.single.key, equals('k'));
        expect(missListener.received, isEmpty);
      },
    );

    test('get dispatches CacheHit when the stored value is null', () async {
      await manager.put('k', null);
      hitListener.received.clear();

      final value = manager.get('k');
      expect(value, isNull);

      expect(hitListener.received, hasLength(1));
      expect(missListener.received, isEmpty);
    });

    test('forget dispatches CacheForget after key removal', () async {
      await manager.put('k', 'v');
      await manager.forget('k');

      expect(forgetListener.received, hasLength(1));
      expect(forgetListener.received.single.key, equals('k'));
      expect(manager.has('k'), isFalse);
    });

    test('flush dispatches CacheFlush after store wipe', () async {
      await manager.put('a', '1');
      await manager.put('b', '2');
      await manager.flush();

      expect(flushListener.received, hasLength(1));
      expect(manager.has('a'), isFalse);
      expect(manager.has('b'), isFalse);
    });

    test(
      'end-to-end lifecycle dispatches put + hit + miss + forget + flush',
      () async {
        await manager.put('k', 'v', ttl: const Duration(minutes: 5));
        manager.get('k');
        manager.get('absent');
        await manager.forget('k');
        await manager.flush();

        expect(putListener.received, hasLength(1));
        expect(hitListener.received, hasLength(1));
        expect(missListener.received, hasLength(1));
        expect(forgetListener.received, hasLength(1));
        expect(flushListener.received, hasLength(1));
      },
    );
  });
}
