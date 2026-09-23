import 'package:flutter/foundation.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;
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

/// A driver whose GET answers [response], but only once the test opens [gate],
/// so the test can change the session while the request is still in the air.
class _HeldDriver extends FakeNetworkDriver {
  _HeldDriver(this.gate, this.response);

  final Completer<void> gate;
  final MagicResponse response;

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    await gate.future;

    return response;
  }
}

/// A vault whose write of the refresh token waits for [gate], so a test can
/// act in the middle of a sign-in's token writes.
class _HeldRefreshVault extends FakeVaultService {
  _HeldRefreshVault(this.gate, super.initialValues);

  final Completer<void> gate;

  /// Completes when the refresh-token write has started and is waiting.
  final Completer<void> refreshWriteStarted = Completer<void>();

  @override
  Future<void> put(String key, String value) async {
    if (key == 'refresh_token') {
      refreshWriteStarted.complete();
      await gate.future;
    }

    return super.put(key, value);
  }
}

/// A vault whose delete of the access token waits for [gate], so a test can
/// act in the middle of a sign-out.
class _HeldTokenDeleteVault extends FakeVaultService {
  _HeldTokenDeleteVault(this.gate, super.initialValues);

  final Completer<void> gate;

  /// Completes when the access-token delete has started and is waiting.
  final Completer<void> tokenDeleteStarted = Completer<void>();

  @override
  Future<void> remove(String key) async {
    if (key == 'auth_token') {
      tokenDeleteStarted.complete();
      await gate.future;
    }

    return super.remove(key);
  }
}

/// A vault whose first write of the cached user waits for [gate], so a test
/// can act while a sync is caching the user it just fetched.
class _HeldUserWriteVault extends FakeVaultService {
  _HeldUserWriteVault(this.gate, super.initialValues);

  final Completer<void> gate;

  /// Completes when the first cached-user write has started and is waiting.
  final Completer<void> userWriteStarted = Completer<void>();

  @override
  Future<void> put(String key, String value) async {
    if (key == 'auth_user' && !userWriteStarted.isCompleted) {
      userWriteStarted.complete();
      await gate.future;
    }

    return super.put(key, value);
  }
}

/// Records every event of type [T] it is handed.
class _RecordingListener<T extends MagicEvent> extends MagicListener<T> {
  final List<T> received = <T>[];

  @override
  Future<void> handle(T event) async => received.add(event);
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

    test('a 200 on the token it was sent with refreshes the user', () async {
      Log.fake();
      Vault.fake({
        'auth_token': 'stored-token',
        'auth_user': jsonEncode({'id': 7, 'name': 'Cached User'}),
      });
      final gate = Completer<void>();
      Magic.singleton(
        'network',
        () => _HeldDriver(
          gate,
          MagicResponse(data: {'id': 7, 'name': 'Fresh User'}, statusCode: 200),
        ),
      );

      final guard = _CacheFirstGuard();
      await guard.restore();
      gate.complete();
      await Future<void>.delayed(Duration.zero);

      expect(guard.user<MockUser>()?.name, 'Fresh User');
    });

    group('when a sign-in lands while the boot sync is in the air', () {
      // `restore()` sets the cached user and fires the sync unawaited with the
      // token restored at boot. A sign-in can store a new token and set a new
      // user before that sync answers, and whatever the server then says is
      // about the OLD token: it is no verdict on the session that exists now.
      late Completer<void> gate;
      late _CacheFirstGuard guard;

      Future<void> signInWhileHeld(MagicResponse response) async {
        Log.fake();
        Vault.fake({
          'auth_token': 'old-token',
          'auth_user': jsonEncode({'id': 7, 'name': 'Old Account'}),
        });
        gate = Completer<void>();
        Magic.singleton('network', () => _HeldDriver(gate, response));

        guard = _CacheFirstGuard();
        await guard.restore();

        final signedIn = MockUser()
          ..setRawAttributes({'id': 8, 'name': 'New Account'}, sync: true);
        await guard.storeToken('new-token');
        await guard.cacheUser(signedIn);
        guard.setUser(signedIn);

        gate.complete();
        await Future<void>.delayed(Duration.zero);
      }

      test('a late 401 about the old token keeps the new session', () async {
        // Before this, `_syncUserFromApi` called `logout()`, and
        // `clearTokens()` deleted the token the sign-in had just stored: the
        // new session was silently undone by a verdict on the one it replaced.
        await signInWhileHeld(MagicResponse(data: null, statusCode: 401));

        expect(guard.check(), isTrue);
        expect(guard.user<MockUser>()?.name, 'New Account');
        expect(guard.cachedToken, 'new-token');
        expect(await Vault.get('auth_token'), 'new-token');
      });

      test('a late 403 about the old token keeps the new session', () async {
        await signInWhileHeld(MagicResponse(data: null, statusCode: 403));

        expect(guard.check(), isTrue);
        expect(await Vault.get('auth_token'), 'new-token');
      });

      test('a late 200 about the old token keeps the new account', () async {
        // The mirror case: the old account's profile arrives after the new
        // account signed in, and `setUser` plus `cacheUser` would put the OLD
        // account in memory and on disk while the guard holds the NEW token.
        await signInWhileHeld(
          MagicResponse(
            data: {'id': 7, 'name': 'Old Account'},
            statusCode: 200,
          ),
        );

        expect(guard.user<MockUser>()?.name, 'New Account');
        expect(
          jsonDecode((await Vault.get('auth_user'))!),
          containsPair('name', 'New Account'),
        );
      });
    });

    group('when the token rotates while the boot sync is in the air', () {
      // A refresh keeps the account and bumps no session state. The
      // interceptor's own refresh-and-retry of the sync lands as a 200 under
      // the new token, and another request's refresh leaves the sync's 401
      // speaking about a token nobody holds any more.
      late _CacheFirstGuard guard;

      Future<void> rotateWhileHeld(
        MagicResponse response, {
        MagicResponse? recheck,
      }) async {
        Log.fake();
        Vault.fake({
          'auth_token': 'old-token',
          'auth_user': jsonEncode({'id': 7, 'name': 'Cached User'}),
        });
        guard = _CacheFirstGuard();
        var calls = 0;
        Magic.singleton(
          'network',
          () => FakeNetworkDriver(
            stubs: (MagicRequest _) async {
              if (calls++ > 0) return recheck!;
              await guard.storeToken('rotated-token');

              return response;
            },
          ),
        );

        await guard.restore();
        await Future<void>.delayed(Duration.zero);
      }

      test('a 200 is applied, because the account is the same', () async {
        await rotateWhileHeld(
          MagicResponse(data: {'id': 7, 'name': 'Fresh User'}, statusCode: 200),
        );

        expect(guard.user<MockUser>()?.name, 'Fresh User');
        expect(
          jsonDecode((await Vault.get('auth_user'))!),
          containsPair('name', 'Fresh User'),
        );
      });

      test(
        'a 401 about the replaced token is re-checked under the current one',
        () async {
          // The refusal is about the token another request's refresh
          // replaced, so it ends nothing by itself; the current token's
          // answer decides.
          await rotateWhileHeld(
            MagicResponse(data: null, statusCode: 401),
            recheck: MagicResponse(
              data: {'id': 7, 'name': 'Fresh User'},
              statusCode: 200,
            ),
          );

          expect(guard.check(), isTrue);
          expect(guard.user<MockUser>()?.name, 'Fresh User');
          expect(await Vault.get('auth_token'), 'rotated-token');
        },
      );

      test('a re-check the server refuses too ends the session', () async {
        await rotateWhileHeld(
          MagicResponse(data: null, statusCode: 401),
          recheck: MagicResponse(data: null, statusCode: 401),
        );

        expect(guard.check(), isFalse);
        expect(await Vault.get('auth_token'), isNull);
      });
    });

    test(
      'a sign-in never shows its new token under the previous account',
      () async {
        // `login()` used to store the token, write the refresh token, and set
        // the user only afterwards. A boot sync answering inside that window
        // saw a new token under an unchanged session, read it as a refresh,
        // and set the PREVIOUS account against the NEW token, dispatching
        // `AuthRestored` for it. The refresh-token write is held open here so
        // the sync lands exactly there.
        Log.fake();
        final refreshWrite = Completer<void>();
        final vault = _HeldRefreshVault(refreshWrite, {
          'auth_token': 'old-token',
          'auth_user': jsonEncode({'id': 7, 'name': 'Old Account'}),
        });
        Magic.app.setInstance('vault', vault);
        final gate = Completer<void>();
        Magic.singleton(
          'network',
          () => _HeldDriver(
            gate,
            MagicResponse(
              data: {'id': 7, 'name': 'Old Account'},
              statusCode: 200,
            ),
          ),
        );

        final guard = BearerTokenGuard(
          refreshTokenKey: 'refresh_token',
          userEndpoint: '/user',
          userFactory: (data) => MockUser()..setRawAttributes(data, sync: true),
        );
        await guard.restore();

        final seen = <(String?, Object?)>[];
        guard.stateNotifier.addListener(
          () => seen.add((guard.cachedToken, guard.id())),
        );

        final signingIn = guard.login(
          {'token': 'new-token', 'refresh_token': 'new-refresh'},
          MockUser()
            ..setRawAttributes({'id': 8, 'name': 'New Account'}, sync: true),
        );
        await vault.refreshWriteStarted.future;
        gate.complete();
        await Future<void>.delayed(Duration.zero);
        refreshWrite.complete();
        await signingIn;

        expect(seen, isNot(contains(('new-token', 7))));
        expect(guard.user<MockUser>()?.name, 'New Account');
        expect(guard.cachedToken, 'new-token');
      },
    );

    test(
      'a late 401 inside a sign-in keeps the token the sign-in wrote',
      () async {
        // The mirror of the case above. In 0.0.18 a sign-in wrote both tokens
        // to the Vault before the in-memory token moved, so a 401 about the old
        // token landing during the refresh-token write saw an unchanged token
        // and an unchanged session and logged out: `clearTokens()` deleted the
        // token the sign-in had just written, the sign-in then set its user,
        // and the app looked signed in with nothing in the Vault. The next
        // cold start was a guest.
        Log.fake();
        final refreshWrite = Completer<void>();
        final vault = _HeldRefreshVault(refreshWrite, {
          'auth_token': 'old-token',
          'auth_user': jsonEncode({'id': 7, 'name': 'Old Account'}),
        });
        Magic.app.setInstance('vault', vault);
        final gate = Completer<void>();
        Magic.singleton(
          'network',
          () => _HeldDriver(gate, MagicResponse(data: null, statusCode: 401)),
        );

        final guard = BearerTokenGuard(
          refreshTokenKey: 'refresh_token',
          userEndpoint: '/user',
          userFactory: (data) => MockUser()..setRawAttributes(data, sync: true),
        );
        await guard.restore();

        final signingIn = guard.login(
          {'token': 'new-token', 'refresh_token': 'new-refresh'},
          MockUser()
            ..setRawAttributes({'id': 8, 'name': 'New Account'}, sync: true),
        );
        await vault.refreshWriteStarted.future;
        gate.complete();
        await Future<void>.delayed(Duration.zero);
        refreshWrite.complete();
        await signingIn;

        expect(guard.check(), isTrue);
        expect(guard.cachedToken, 'new-token');
        expect(await Vault.get('auth_token'), 'new-token');
        expect(await Vault.get('refresh_token'), 'new-refresh');
      },
    );

    test(
      'a late 401 inside a refresh keeps the token the refresh wrote',
      () async {
        // The same window on the refresh path: `storeToken` wrote both tokens
        // before the in-memory token moved, so a 401 about the old token
        // landing between the writes read as a verdict on the current token
        // and its logout deleted the refreshed one. With the in-memory token
        // moved first, the refusal is about a replaced token and is re-checked
        // under the current one, which the server accepts.
        Log.fake();
        final refreshWrite = Completer<void>();
        final vault = _HeldRefreshVault(refreshWrite, {
          'auth_token': 'old-token',
          'auth_user': jsonEncode({'id': 7, 'name': 'Cached User'}),
        });
        Magic.app.setInstance('vault', vault);
        final gate = Completer<void>();
        var calls = 0;
        Magic.singleton(
          'network',
          () => FakeNetworkDriver(
            stubs: (MagicRequest _) async {
              if (calls++ > 0) {
                return MagicResponse(
                  data: {'id': 7, 'name': 'Cached User'},
                  statusCode: 200,
                );
              }
              await gate.future;

              return MagicResponse(data: null, statusCode: 401);
            },
          ),
        );

        final guard = BearerTokenGuard(
          refreshTokenKey: 'refresh_token',
          userEndpoint: '/user',
          userFactory: (data) => MockUser()..setRawAttributes(data, sync: true),
        );
        await guard.restore();

        final refreshing = guard.storeToken('rotated-token', 'new-refresh');
        await vault.refreshWriteStarted.future;
        gate.complete();
        await Future<void>.delayed(Duration.zero);
        refreshWrite.complete();
        await refreshing;
        await Future<void>.delayed(Duration.zero);

        expect(guard.check(), isTrue);
        expect(await Vault.get('auth_token'), 'rotated-token');
        expect(await Vault.get('refresh_token'), 'new-refresh');
      },
    );

    test(
      'a sign-out during the sync\'s own cache write gets no AuthRestored',
      () async {
        // The epoch is read once, when the answer arrives, and the 200 path
        // then awaits its cache write before dispatching. A sign-out starting
        // inside that write used to hear `AuthRestored` for the session it
        // had just ended, and the cache write could land after the sign-out
        // cleared it.
        Log.fake();
        EventDispatcher.instance.clear();
        final restored = _RecordingListener<AuthRestored>();
        EventDispatcher.instance.register(AuthRestored, [() => restored]);
        final cacheWrite = Completer<void>();
        final vault = _HeldUserWriteVault(cacheWrite, {
          'auth_token': 'stored-token',
          'auth_user': jsonEncode({'id': 7, 'name': 'Cached User'}),
        });
        Magic.app.setInstance('vault', vault);
        final gate = Completer<void>();
        Magic.singleton(
          'network',
          () => _HeldDriver(
            gate,
            MagicResponse(
              data: {'id': 7, 'name': 'Fresh User'},
              statusCode: 200,
            ),
          ),
        );

        final guard = _CacheFirstGuard();
        await guard.restore();
        gate.complete();
        await vault.userWriteStarted.future;

        await guard.logout();
        cacheWrite.complete();
        await Future<void>.delayed(Duration.zero);

        expect(restored.received, isEmpty);
        expect(guard.check(), isFalse);
        expect(await Vault.get('auth_user'), isNull);
        EventDispatcher.instance.clear();
      },
    );

    test('a late 200 inside a sign-out is not applied', () async {
      // `logout()` bumped the session only at its end, after awaiting the
      // Vault deletes, so a sync answering inside them read an unchanged
      // session and set the user again mid-sign-out, dispatching
      // `AuthRestored` for a session that was ending.
      Log.fake();
      final tokenDelete = Completer<void>();
      final vault = _HeldTokenDeleteVault(tokenDelete, {
        'auth_token': 'stored-token',
        'auth_user': jsonEncode({'id': 7, 'name': 'Cached User'}),
      });
      Magic.app.setInstance('vault', vault);
      final gate = Completer<void>();
      Magic.singleton(
        'network',
        () => _HeldDriver(
          gate,
          MagicResponse(
            data: {'id': 7, 'name': 'Cached User'},
            statusCode: 200,
          ),
        ),
      );

      final guard = _CacheFirstGuard();
      await guard.restore();

      final seen = <bool>[];
      guard.stateNotifier.addListener(() => seen.add(guard.check()));

      final signingOut = guard.logout();
      await vault.tokenDeleteStarted.future;
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      tokenDelete.complete();
      await signingOut;

      expect(seen, [false]);
      expect(guard.check(), isFalse);
      expect(await Vault.get('auth_user'), isNull);
    });

    test('a late 200 after a sign-out does not sign the user back in', () async {
      // The same shape with the session ended rather than replaced: the sync's
      // user must not reappear once the guard holds no token at all.
      Log.fake();
      Vault.fake({
        'auth_token': 'stored-token',
        'auth_user': jsonEncode({'id': 7, 'name': 'Cached User'}),
      });
      final gate = Completer<void>();
      Magic.singleton(
        'network',
        () => _HeldDriver(
          gate,
          MagicResponse(
            data: {'id': 7, 'name': 'Cached User'},
            statusCode: 200,
          ),
        ),
      );

      final guard = _CacheFirstGuard();
      await guard.restore();
      await guard.logout();
      gate.complete();
      await Future<void>.delayed(Duration.zero);

      expect(guard.check(), isFalse);
      expect(await Vault.get('auth_user'), isNull);
    });
  });

  group('built-in guard login', () {
    setUp(() {
      MagicApp.reset();
      Magic.flush();
      Log.fake();
      Vault.fake();
    });

    tearDown(() {
      Vault.unfake();
      Log.unfake();
      MagicApp.reset();
      Magic.flush();
    });

    MockUser signedIn() =>
        MockUser()
          ..setRawAttributes({'id': 3, 'name': 'Signed In'}, sync: true);

    test('BearerTokenGuard stores both tokens and the user', () async {
      final guard = BearerTokenGuard(refreshTokenKey: 'refresh_token');

      await guard.login({
        'token': 'bearer-token',
        'refresh_token': 'refresh-token',
      }, signedIn());

      expect(guard.cachedToken, 'bearer-token');
      expect(await Vault.get('auth_token'), 'bearer-token');
      expect(await Vault.get('refresh_token'), 'refresh-token');
      expect(guard.id(), 3);
      expect(
        jsonDecode((await Vault.get('auth_user'))!),
        containsPair('name', 'Signed In'),
      );
    });

    test('BasicAuthGuard stores the encoded credentials', () async {
      final guard = BasicAuthGuard();
      final expected = base64Encode(utf8.encode('ada:secret'));

      await guard.login({'username': 'ada', 'password': 'secret'}, signedIn());

      expect(guard.cachedToken, expected);
      expect(await Vault.get('basic_auth_credentials'), expected);
      expect(guard.id(), 3);
    });

    test('ApiKeyGuard stores the key', () async {
      final guard = ApiKeyGuard();

      await guard.login({'api_key': 'sk_test_123'}, signedIn());

      expect(guard.cachedToken, 'sk_test_123');
      expect(await Vault.get('api_key'), 'sk_test_123');
      expect(guard.id(), 3);
    });
  });
}
