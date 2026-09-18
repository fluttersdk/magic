import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

// ---------------------------------------------------------------------------
// Mock User Model for Testing
// ---------------------------------------------------------------------------

class MockUser extends Model with HasTimestamps, Authenticatable {
  @override
  String get table => 'users';

  @override
  String get resource => 'users';

  String? get name => getAttribute('name') as String?;
  set name(String? value) => setAttribute('name', value);

  String? get email => getAttribute('email') as String?;
  set email(String? value) => setAttribute('email', value);
}

// ---------------------------------------------------------------------------
// Mock Guard for Testing
// ---------------------------------------------------------------------------

class MockGuard implements Guard {
  Authenticatable? _user;
  bool validateResult = true;
  String? mockToken = 'mock-token';

  @override
  final ValueNotifier<int> stateNotifier = ValueNotifier<int>(0);

  @override
  Future<void> login(Map<String, dynamic> data, Authenticatable user) async {
    mockToken = data['token'] as String?;
    _user = user;
  }

  @override
  Future<void> logout() async {
    _user = null;
    mockToken = null;
    stateNotifier.value++;
  }

  @override
  bool check() => _user != null;

  @override
  bool get guest => !check();

  @override
  T? user<T extends Model>() => _user as T?;

  @override
  dynamic id() => _user?.authIdentifier;

  @override
  void setUser(Authenticatable user) {
    _user = user;
    stateNotifier.value++;
  }

  @override
  Future<bool> hasToken() async => mockToken != null;

  @override
  Future<String?> getToken() async => mockToken;

  @override
  Future<bool> refreshToken() async => true;

  @override
  Future<void> restore() async {
    // Mock restore - sets a default user if token exists
    if (mockToken != null) {
      setUser(
        MockUser()
          ..setRawAttributes({'id': 1, 'name': 'Restored User'}, sync: true),
      );
    }
  }
}

/// A guard that keeps [BaseGuard.restore] rather than replacing it, so the real
/// cache-first path is what the test drives.
class _CacheFirstGuard extends BaseGuard {
  _CacheFirstGuard()
    : super(
        userEndpoint: '/user',
        userFactory: (data) => MockUser()..setRawAttributes(data, sync: true),
      );

  @override
  Future<void> login(Map<String, dynamic> data, Authenticatable user) async {}
}

/// A driver whose GET never answers until the test opens the gate, standing in
/// for a backend that accepts the connection and then says nothing.
class _GatedDriver extends FakeNetworkDriver {
  _GatedDriver(this.gate);

  final Completer<void> gate;

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    await gate.future;

    return super.get(url, query: query, headers: headers);
  }
}

/// A driver whose GET answers the way [DioNetworkDriver] answers a transport
/// failure: no response, so `statusCode` is 0 rather than anything the server
/// said.
class _StatusDriver extends FakeNetworkDriver {
  _StatusDriver(this.statusCode);

  final int statusCode;

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    return MagicResponse(data: null, statusCode: statusCode, headers: {});
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AuthServiceProvider restore-warning gating', () {
    setUp(() {
      MagicApp.reset();
      Magic.flush();
    });

    tearDown(() {
      Log.unfake();
      Vault.unfake();
      MagicApp.reset();
      Magic.flush();
    });

    test(
      'stays quiet when there is no userFactory and no stored session',
      () async {
        final log = Log.fake();
        Vault.fake(); // empty vault → guard.hasToken() is false

        await (AuthServiceProvider(MagicApp.instance)..register()).boot();

        final warnedAboutFactory = log.entries.any(
          (e) => e.level == 'warning' && e.message.contains('userFactory'),
        );
        expect(warnedAboutFactory, isFalse);
      },
    );

    test(
      'warns when a stored session exists but no userFactory is registered',
      () async {
        final log = Log.fake();
        Vault.fake({'auth_token': 'stored-token'}); // a session to restore

        await (AuthServiceProvider(MagicApp.instance)..register()).boot();

        final warnedAboutFactory = log.entries.any(
          (e) => e.level == 'warning' && e.message.contains('userFactory'),
        );
        expect(warnedAboutFactory, isTrue);
      },
    );

    test(
      'boot does not crash when the stored-session check itself throws',
      () async {
        Log.fake();
        // No Vault registered and no userFactory: Auth.hasToken() throws.
        // Boot must treat that failure as "no session" and complete quietly,
        // not crash the whole bootstrap over a warning-verbosity decision.
        await expectLater(
          (AuthServiceProvider(MagicApp.instance)..register()).boot(),
          completes,
        );
      },
    );
  });

  group('Authenticatable Mixin', () {
    test('authIdentifier returns primary key value', () {
      final user = MockUser()
        ..setRawAttributes({'id': 42, 'name': 'Test'}, sync: true);

      expect(user.authIdentifier, 42);
    });

    test('authIdentifierName returns primary key column name', () {
      final user = MockUser();
      expect(user.authIdentifierName, 'id');
    });

    test('authPassword returns password attribute', () {
      final user = MockUser()
        ..setRawAttributes({'password': 'hashed_secret'}, sync: true);

      expect(user.authPassword, 'hashed_secret');
    });
  });

  group('Guard Contract', () {
    late MockGuard guard;

    setUp(() {
      guard = MockGuard();
    });

    test('login sets user and token', () async {
      final user = MockUser()
        ..setRawAttributes({'id': 1, 'email': 'test@example.com'}, sync: true);

      await guard.login({'token': 'new-token'}, user);

      expect(guard.check(), isTrue);
      expect(await guard.getToken(), 'new-token');
      expect(guard.user<MockUser>()?.email, 'test@example.com');
    });

    test('check returns true when authenticated', () async {
      final user = MockUser()..setRawAttributes({'id': 1}, sync: true);
      await guard.login({'token': 'token'}, user);

      expect(guard.check(), isTrue);
      expect(guard.guest, isFalse);
    });

    test('guest returns true when not authenticated', () {
      guard.mockToken = null;
      expect(guard.guest, isTrue);
      expect(guard.check(), isFalse);
    });

    test('user returns null when not authenticated', () {
      expect(guard.user<MockUser>(), isNull);
    });

    test('user returns authenticated user', () async {
      final user = MockUser()
        ..setRawAttributes({'id': 1, 'email': 'test@example.com'}, sync: true);
      await guard.login({'token': 'token'}, user);

      final retrieved = guard.user<MockUser>();
      expect(retrieved, isNotNull);
      expect(retrieved?.email, 'test@example.com');
    });

    test('id returns user identifier', () async {
      final user = MockUser()..setRawAttributes({'id': 1}, sync: true);
      await guard.login({'token': 'token'}, user);

      expect(guard.id(), 1);
    });

    test('logout clears user and token', () async {
      final user = MockUser()..setRawAttributes({'id': 1}, sync: true);
      await guard.login({'token': 'token'}, user);
      expect(guard.check(), isTrue);

      await guard.logout();
      expect(guard.check(), isFalse);
      expect(guard.user<MockUser>(), isNull);
      expect(await guard.getToken(), isNull);
    });

    test('setUser sets authenticated user', () {
      final user = MockUser()
        ..setRawAttributes({'id': 5, 'name': 'Manual'}, sync: true);

      guard.setUser(user);

      expect(guard.check(), isTrue);
      expect(guard.id(), 5);
    });

    test('hasToken returns true when token exists', () async {
      expect(await guard.hasToken(), isTrue);
    });

    test('getToken returns the token', () async {
      expect(await guard.getToken(), 'mock-token');
    });

    test('refreshToken returns true', () async {
      expect(await guard.refreshToken(), isTrue);
    });

    test('restore restores user from token', () async {
      guard.mockToken = 'stored-token';
      await guard.restore();

      expect(guard.check(), isTrue);
      expect(guard.user<MockUser>()?.name, 'Restored User');
    });

    test('stateNotifier bumps on setUser', () {
      int notifyCount = 0;
      guard.stateNotifier.addListener(() => notifyCount++);

      final user = MockUser()
        ..setRawAttributes({'id': 1, 'name': 'New'}, sync: true);
      guard.setUser(user);

      expect(notifyCount, 1);
    });

    test('stateNotifier bumps on logout', () async {
      final user = MockUser()..setRawAttributes({'id': 1}, sync: true);
      await guard.login({'token': 'token'}, user);

      int notifyCount = 0;
      guard.stateNotifier.addListener(() => notifyCount++);

      await guard.logout();

      expect(notifyCount, 1);
    });

    test('stateNotifier bumps on restore', () async {
      guard.mockToken = 'stored-token';

      int notifyCount = 0;
      guard.stateNotifier.addListener(() => notifyCount++);

      await guard.restore();

      expect(notifyCount, greaterThanOrEqualTo(1));
    });
  });

  group('AuthManager', () {
    late AuthManager manager;

    setUp(() {
      manager = AuthManager();
      manager.forgetGuards();
    });

    test('setUserFactory stores factory', () {
      expect(
        () => manager.setUserFactory(
          (data) => MockUser()..setRawAttributes(data, sync: true),
        ),
        returnsNormally,
      );
    });

    test('extend registers custom driver', () {
      manager.extend('custom', (config) => MockGuard());

      expect(
        () => manager.extend('another', (c) => MockGuard()),
        returnsNormally,
      );
    });

    test('forgetGuards clears cached guards', () {
      manager.forgetGuards();
      // No assertion needed - just verifies method doesn't throw
    });
  });

  group('AuthResult', () {
    test('success creates successful result', () {
      final user = MockUser()
        ..setRawAttributes({'id': 1, 'name': 'Test'}, sync: true);

      final result = AuthResult.success(user: user, token: 'test-token');

      expect(result.success, isTrue);
      expect(result.failed, isFalse);
      expect(result.token, 'test-token');
      expect(result.user<MockUser>(), isNotNull);
    });

    test('failure creates failed result', () {
      final result = AuthResult.failure(
        message: 'Invalid credentials',
        errors: {
          'email': ['Email not found'],
        },
      );

      expect(result.success, isFalse);
      expect(result.failed, isTrue);
      expect(result.message, 'Invalid credentials');
      expect(result.errors['email'], ['Email not found']);
    });

    test('firstError returns first error for field', () {
      final result = AuthResult.failure(
        errors: {
          'email': ['First error', 'Second error'],
        },
      );

      expect(result.firstError('email'), 'First error');
      expect(result.firstError('password'), isNull);
    });

    test('fromResponse creates result from MagicResponse', () {
      final successResponse = MagicResponse(
        data: {
          'user': {'id': 1},
        },
        statusCode: 200,
      );

      final user = MockUser()..setRawAttributes({'id': 1}, sync: true);

      final result = AuthResult.fromResponse(
        successResponse,
        user: user,
        token: 'token',
      );

      expect(result.success, isTrue);
    });

    test('fromResponse creates failure for error response', () {
      final errorResponse = MagicResponse(
        data: {
          'message': 'Validation failed',
          'errors': {
            'email': ['Invalid email'],
          },
        },
        statusCode: 422,
      );

      final result = AuthResult.fromResponse(errorResponse);

      expect(result.success, isFalse);
      expect(result.message, 'Validation failed');
      expect(result.errors['email'], ['Invalid email']);
    });
  });

  // ---------------------------------------------------------------------------
  // BaseGuard.restore: the cache answers, the API sync does not hold the boot
  // ---------------------------------------------------------------------------

  group('BaseGuard.restore cache-first contract', () {
    setUp(() {
      MagicApp.reset();
      Magic.flush();
    });

    tearDown(() {
      Vault.unfake();
      Log.unfake();
      MagicApp.reset();
      Magic.flush();
    });

    test(
      'returns once the cached user is in place, without waiting for the API',
      () async {
        // `AuthServiceProvider.boot()` awaits `restore()`, so anything `restore()`
        // awaits holds `Magic.init()`, and nothing renders until it lets go. With
        // a backend that accepts the connection and never answers (a captive
        // portal, a dead mobile link), that is the whole client timeout: measured
        // on an iPhone as roughly two minutes of blank white screen on a cold
        // start, with the console stopping dead on "Auth: Cached user restored".
        //
        // The class docblock has always said "2. Sync from API in background".
        Log.fake();
        Vault.fake({
          'auth_token': 'stored-token',
          'auth_user': jsonEncode({'id': 7, 'name': 'Cached User'}),
        });

        final gate = Completer<void>();
        Magic.singleton('network', () => _GatedDriver(gate));

        final guard = _CacheFirstGuard();

        // No timeout wrapper on purpose: if `restore()` waits for the gate this
        // never completes and the case fails as a hang, which is exactly the
        // shape of the defect.
        await guard.restore();

        expect(
          guard.check(),
          isTrue,
          reason: 'the cached user is what makes the app renderable',
        );
        expect(guard.user<MockUser>()?.name, 'Cached User');
        expect(
          gate.isCompleted,
          isFalse,
          reason:
              'the API has not answered yet, and must not have been waited on',
        );

        gate.complete();
      },
    );

    test(
      'a transport failure keeps the session, only the server may end it',
      () async {
        // `DioNetworkDriver._handleError` has no response to report on a
        // timeout, a DNS failure or a dead link, so it returns statusCode 0.
        // Reading that as "not successful" and logging out throws away a valid
        // session because the phone went through a tunnel, and the log line
        // said "Token invalid" about a server that never answered.
        Log.fake();
        Vault.fake({
          'auth_token': 'stored-token',
          'auth_user': jsonEncode({'id': 7, 'name': 'Cached User'}),
        });
        Magic.singleton('network', () => _StatusDriver(0));

        final guard = _CacheFirstGuard();
        await guard.restore();
        // The sync no longer blocks restore, so let its microtask run.
        await Future<void>.delayed(Duration.zero);

        expect(guard.check(), isTrue);
        expect(await Vault.get('auth_token'), 'stored-token');
      },
    );

    test('a 401 does end the session, because the server said so', () async {
      Log.fake();
      Vault.fake({
        'auth_token': 'stored-token',
        'auth_user': jsonEncode({'id': 7, 'name': 'Cached User'}),
      });
      Magic.singleton('network', () => _StatusDriver(401));

      final guard = _CacheFirstGuard();
      await guard.restore();
      await Future<void>.delayed(Duration.zero);

      expect(guard.check(), isFalse);
      expect(await Vault.get('auth_token'), isNull);
    });
  });
}
