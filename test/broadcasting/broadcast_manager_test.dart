import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// Minimal [BroadcastDriver] stub — records which config it was created with.
class _StubDriver implements BroadcastDriver {
  final Map<String, dynamic> config;

  _StubDriver(this.config);

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  String? get socketId => null;

  @override
  bool get isConnected => false;

  @override
  Stream<BroadcastConnectionState> get connectionState => const Stream.empty();

  @override
  Stream<void> get onReconnect => const Stream.empty();

  @override
  BroadcastChannel channel(String name) => throw UnimplementedError();

  @override
  BroadcastChannel private(String name) => throw UnimplementedError();

  @override
  BroadcastPresenceChannel join(String name) => throw UnimplementedError();

  @override
  void leave(String name) {}

  @override
  void addInterceptor(BroadcastInterceptor interceptor) {}
}

/// A second distinct stub — lets tests distinguish between two custom drivers.
class _AnotherStubDriver extends _StubDriver {
  _AnotherStubDriver(super.config);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Registers a minimal broadcasting config so [BroadcastManager] can resolve.
void _setConfig({
  String defaultConnection = 'null',
  Map<String, dynamic>? connections,
}) {
  Config.set('broadcasting.default', defaultConnection);
  Config.set(
    'broadcasting.connections',
    connections ??
        {
          'null': {'driver': 'null'},
        },
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    BroadcastManager.resetDrivers();
  });

  group('BroadcastManager — custom driver registration', () {
    test('extend() registers a custom driver factory', () {
      BroadcastManager.extend(
        'stub',
        (Map<String, dynamic> config) => _StubDriver(config),
      );

      _setConfig(
        defaultConnection: 'my_conn',
        connections: {
          'my_conn': {'driver': 'stub'},
        },
      );

      final manager = BroadcastManager();
      final driver = manager.connection();

      expect(driver, isA<_StubDriver>());
    });

    test('extend() with different names registers independently', () {
      BroadcastManager.extend(
        'stub_a',
        (Map<String, dynamic> config) => _StubDriver(config),
      );
      BroadcastManager.extend(
        'stub_b',
        (Map<String, dynamic> config) => _AnotherStubDriver(config),
      );

      _setConfig(
        connections: {
          'conn_a': {'driver': 'stub_a'},
          'conn_b': {'driver': 'stub_b'},
        },
      );

      final manager = BroadcastManager();

      expect(manager.connection('conn_a'), isA<_StubDriver>());
      expect(manager.connection('conn_b'), isA<_AnotherStubDriver>());
    });
  });

  group('BroadcastManager — resetDrivers()', () {
    test('resetDrivers() clears all registered custom drivers', () {
      BroadcastManager.extend(
        'stub',
        (Map<String, dynamic> config) => _StubDriver(config),
      );

      BroadcastManager.resetDrivers();

      // After reset, 'stub' is no longer registered — resolving falls through
      // to the default (NullBroadcastDriver).
      _setConfig(
        defaultConnection: 'my_conn',
        connections: {
          'my_conn': {'driver': 'stub'},
        },
      );

      final manager = BroadcastManager();
      final driver = manager.connection();

      // Falls back to default — should NOT be _StubDriver.
      expect(driver, isNot(isA<_StubDriver>()));
    });

    test('resetDrivers() is idempotent on empty registry', () {
      expect(() => BroadcastManager.resetDrivers(), returnsNormally);
    });
  });

  group('BroadcastManager — config forwarding', () {
    test('custom driver factory receives full connection config', () {
      Map<String, dynamic>? capturedConfig;

      BroadcastManager.extend('spy', (Map<String, dynamic> config) {
        capturedConfig = config;
        return _StubDriver(config);
      });

      _setConfig(
        defaultConnection: 'spy_conn',
        connections: {
          'spy_conn': {
            'driver': 'spy',
            'host': 'ws.example.com',
            'port': 6001,
            'app_key': 'abc123',
          },
        },
      );

      BroadcastManager().connection();

      expect(capturedConfig, isNotNull);
      expect(capturedConfig!['host'], equals('ws.example.com'));
      expect(capturedConfig!['port'], equals(6001));
      expect(capturedConfig!['app_key'], equals('abc123'));
    });
  });

  group('BroadcastManager — default connection caching', () {
    test(
      'connection() without args returns same instance on repeated calls',
      () {
        _setConfig();

        final manager = BroadcastManager();
        final first = manager.connection();
        final second = manager.connection();

        expect(identical(first, second), isTrue);
      },
    );

    test('named connection() is NOT cached as default', () {
      _setConfig(
        connections: {
          'null': {'driver': 'null'},
          'other': {'driver': 'null'},
        },
      );

      final manager = BroadcastManager();
      final named = manager.connection('other');
      final defaultConn = manager.connection();

      // They are separate instances because named was never set as cached.
      expect(identical(named, defaultConn), isFalse);
    });

    test('second manager instance resolves fresh (no shared cache)', () {
      _setConfig();

      final a = BroadcastManager().connection();
      final b = BroadcastManager().connection();

      // Different manager instances → different cached objects.
      expect(identical(a, b), isFalse);
    });
  });

  group('BroadcastManager — named connection resolution', () {
    test('connection(name) resolves the named connection', () {
      BroadcastManager.extend(
        'stub',
        (Map<String, dynamic> config) => _StubDriver(config),
      );

      _setConfig(
        connections: {
          'null': {'driver': 'null'},
          'custom': {'driver': 'stub'},
        },
      );

      final manager = BroadcastManager();
      final driver = manager.connection('custom');

      expect(driver, isA<_StubDriver>());
    });

    test('connection() falls back to broadcasting.default when no arg', () {
      BroadcastManager.extend(
        'stub',
        (Map<String, dynamic> config) => _StubDriver(config),
      );

      _setConfig(
        defaultConnection: 'my_default',
        connections: {
          'my_default': {'driver': 'stub'},
        },
      );

      final manager = BroadcastManager();
      final driver = manager.connection();

      expect(driver, isA<_StubDriver>());
    });

    test('reverb driver name resolves to ReverbBroadcastDriver', () {
      _setConfig(
        defaultConnection: 'reverb',
        connections: {
          'reverb': {
            'driver': 'reverb',
            'host': 'localhost',
            'port': 8080,
            'scheme': 'ws',
            'app_key': 'test',
            'auth_endpoint': '/broadcasting/auth',
            'reconnect': false,
            'max_reconnect_delay': 30000,
            'activity_timeout': 30,
            'dedup_buffer_size': 100,
          },
        },
      );

      final manager = BroadcastManager();
      final driver = manager.connection();

      expect(driver, isA<ReverbBroadcastDriver>());
    });

    test('unknown driver name falls back to NullBroadcastDriver', () {
      _setConfig(
        defaultConnection: 'weird',
        connections: {
          'weird': {'driver': 'totally_unknown'},
        },
      );

      // Should not throw — falls back gracefully.
      expect(() => BroadcastManager().connection(), returnsNormally);
    });
  });
}
