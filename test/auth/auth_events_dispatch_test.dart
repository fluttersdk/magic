import 'dart:async';

import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;
import 'package:magic/magic.dart';

class _User extends Model with Authenticatable {
  @override
  String get table => 'users';

  @override
  String get resource => 'users';
}

_User _user(int id) => _User()..setRawAttributes({'id': id}, sync: true);

/// Records every event of type [T] it is handed, and what [probe] read at the
/// moment it was handed, so a test can pin where in a sequence it fired.
class _RecordingListener<T extends MagicEvent> extends MagicListener<T> {
  _RecordingListener([this.probe]);

  final Object? Function()? probe;
  final List<T> received = <T>[];
  final List<Object?> probed = <Object?>[];

  @override
  Future<void> handle(T event) async {
    received.add(event);
    probed.add(probe?.call());
  }
}

class _ThrowingListener<T extends MagicEvent> extends MagicListener<T> {
  @override
  Future<void> handle(T event) async => throw StateError('listener broke');
}

/// A vault whose first write of the cached user waits for [gate], so a test
/// can act while a sign-in is caching the user it just set.
class _HeldUserWriteVault extends FakeVaultService {
  _HeldUserWriteVault(this.gate);

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

/// A vault that refuses to delete the access token, the way a locked keychain
/// refuses a `Vault.delete`.
class _RefusingTokenDeleteVault extends FakeVaultService {
  _RefusingTokenDeleteVault(super.initialValues);

  @override
  Future<void> remove(String key) async {
    if (key == 'auth_token') {
      throw MagicVaultException('Failed to remove from vault', null);
    }

    return super.remove(key);
  }
}

/// A vault whose first delete of the access token waits for [logoutGate], and
/// whose first write of the cached user waits for [loginGate], so a test can
/// pin a sign-in's `setUser` to land, then release, exactly between an
/// in-flight logout's Vault delete and that logout's own `_user = null`.
class _HeldLogoutLoginVault extends FakeVaultService {
  _HeldLogoutLoginVault(super.initialValues, this.logoutGate, this.loginGate);

  final Completer<void> logoutGate;
  final Completer<void> loginGate;

  /// Completes once the logout's token delete has started and is waiting.
  final Completer<void> tokenDeleteStarted = Completer<void>();

  /// Completes once the login's cached-user write has started and is waiting.
  final Completer<void> userWriteStarted = Completer<void>();

  @override
  Future<void> remove(String key) async {
    if (key == 'auth_token' && !tokenDeleteStarted.isCompleted) {
      tokenDeleteStarted.complete();
      await logoutGate.future;
    }

    return super.remove(key);
  }

  @override
  Future<void> put(String key, String value) async {
    if (key == 'auth_user' && !userWriteStarted.isCompleted) {
      userWriteStarted.complete();
      await loginGate.future;
    }

    return super.put(key, value);
  }
}

void main() {
  late _RecordingListener<AuthLogin> logins;
  late _RecordingListener<AuthLogout> logouts;

  void listen({Object? Function()? probe}) {
    logins = _RecordingListener<AuthLogin>(probe);
    logouts = _RecordingListener<AuthLogout>(probe);
    EventDispatcher.instance.register(AuthLogin, [() => logins]);
    EventDispatcher.instance.register(AuthLogout, [() => logouts]);
  }

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Log.fake();
  });

  tearDown(() {
    Auth.unfake();
    Vault.unfake();
    Log.unfake();
    MagicApp.reset();
    Magic.flush();
  });

  group('BaseGuard', () {
    test('Auth.login on a bearer guard delivers one AuthLogin', () async {
      Vault.fake();
      Magic.singleton('auth', AuthManager.new);
      Auth.manager.forgetGuards();
      listen(probe: Auth.check);
      final user = _user(1);

      await Auth.login({'token': 'a-token'}, user);

      expect(logins.received, hasLength(1));
      expect(logins.received.single.user, same(user));
      expect(logins.probed, [true], reason: 'fired once the user is set');
      expect(logouts.received, isEmpty);
      Auth.manager.forgetGuards();
    });

    test(
      'a sign-out inside the sign-in\'s cache write gets no AuthLogin',
      () async {
        // `startSession` awaits the cached-user write after setting the user,
        // and a sign-out can begin inside it. Hearing `AuthLogin` after
        // `AuthLogout` would attribute a session that no longer exists.
        final cacheWrite = Completer<void>();
        final vault = _HeldUserWriteVault(cacheWrite);
        Magic.app.setInstance('vault', vault);
        listen();
        final guard = BearerTokenGuard();
        final user = _user(1);

        final signingIn = guard.login({'token': 'a-token'}, user);
        await vault.userWriteStarted.future;
        await guard.logout();
        cacheWrite.complete();
        await signingIn;

        expect(logouts.received, hasLength(1));
        expect(logouts.received.single.user, same(user));
        expect(logins.received, isEmpty);
        expect(guard.check(), isFalse);
        expect(await Vault.get('auth_user'), isNull);
      },
    );

    test('a logout already inside its vault deletes when a sign-in begins gets '
        'no AuthLogin once that logout clears the user', () async {
      // The logout starts first and gets stuck deleting the access token,
      // exactly as a slow keychain would. The sign-in runs `setUser` while
      // that delete is still pending, then this vault holds the sign-in's
      // own cached-user write open too, so the test can release the
      // logout (letting it clear `_user`) before letting the sign-in
      // resume and reach its pre-dispatch check. The epoch alone cannot
      // catch this: the sign-in's epoch is the newest either way.
      final logoutGate = Completer<void>();
      final loginGate = Completer<void>();
      final vault = _HeldLogoutLoginVault(
        {'auth_token': 'a-token'},
        logoutGate,
        loginGate,
      );
      Magic.app.setInstance('vault', vault);
      final guard = BearerTokenGuard();
      final userA = _user(1);
      guard.setUser(userA);
      listen();

      final loggingOut = guard.logout();
      await vault.tokenDeleteStarted.future;

      final userB = _user(2);
      final signingIn = guard.login({'token': 'b-token'}, userB);
      await vault.userWriteStarted.future;

      // Let the logout finish clearing `_user` while the sign-in is still
      // paused on its own cached-user write.
      logoutGate.complete();
      await loggingOut;

      // Now let the sign-in resume and reach its pre-dispatch check.
      loginGate.complete();
      await signingIn;

      expect(logins.received, isEmpty, reason: 'the logout already won');
      expect(logouts.received, hasLength(1));
      expect(logouts.received.single.user, same(userA));
      expect(guard.check(), isFalse);
    });

    test(
      'a logout whose token delete throws still delivers AuthLogout',
      () async {
        // The in-memory clear and the notifier bump are unconditional, so the
        // event is too: skipping it would leave listeners holding a user the
        // screen no longer shows.
        Magic.app.setInstance(
          'vault',
          _RefusingTokenDeleteVault({'auth_token': 'a-token'}),
        );
        final guard = BearerTokenGuard();
        listen(probe: guard.check);
        final user = _user(1);
        guard.setUser(user);

        await expectLater(guard.logout(), throwsA(isA<MagicVaultException>()));

        expect(logouts.received, hasLength(1));
        expect(logouts.received.single.user, same(user));
        expect(logouts.probed, [false], reason: 'fired after the clear');
      },
    );

    test('a guest logout delivers AuthLogout with no user', () async {
      Vault.fake();
      listen();

      await BearerTokenGuard().logout();

      expect(logouts.received, hasLength(1));
      expect(logouts.received.single.user, isNull);
    });

    test('a throwing listener fails neither login nor logout', () async {
      Vault.fake();
      EventDispatcher.instance.register(AuthLogin, [
        () => _ThrowingListener<AuthLogin>(),
      ]);
      EventDispatcher.instance.register(AuthLogout, [
        () => _ThrowingListener<AuthLogout>(),
      ]);
      final guard = BearerTokenGuard();

      await guard.login({'token': 'a-token'}, _user(1));
      expect(guard.check(), isTrue);

      await guard.logout();
      expect(guard.check(), isFalse);
    });
  });

  group('Auth.fake', () {
    test('login and logout deliver AuthLogin then AuthLogout', () async {
      Auth.fake();
      listen(probe: () => Auth.stateNotifier.value);
      final user = _user(1);

      await Auth.login({'token': 'a-token'}, user);
      await Auth.logout();

      expect(logins.received.single.user, same(user));
      expect(logouts.received.single.user, same(user));
      expect(
        [...logins.probed, ...logouts.probed],
        [1, 2],
        reason: 'each fires after its own bump, as on the real guard',
      );
    });
  });
}
