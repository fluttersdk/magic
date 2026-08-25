import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

class _User extends Model with Authenticatable {
  @override
  String get table => 'users';

  @override
  String get resource => 'users';
}

class _Guard extends BaseGuard {
  _Guard()
    : super(
        userEndpoint: '/user',
        refreshTokenKey: 'auth_refresh_token',
        userFactory: (data) => _User()..setRawAttributes(data, sync: true),
      );

  @override
  Future<void> login(Map<String, dynamic> data, Authenticatable user) async {}
}

/// A vault whose `remove` fails for chosen keys, the way a keychain does when
/// the item is locked or the entitlement has gone.
class _FailingVault extends FakeVaultService {
  _FailingVault(this.failingKeys, [super.initialValues = const {}]);

  final Set<String> failingKeys;
  final List<String> removeAttempts = <String>[];

  @override
  Future<void> remove(String key) async {
    removeAttempts.add(key);
    if (failingKeys.contains(key)) {
      throw MagicVaultException('Failed to remove from vault', null);
    }
    return super.remove(key);
  }
}

void main() {
  late _Guard guard;

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    guard = _Guard();
  });

  _FailingVault installVault(Set<String> failing) {
    final vault = _FailingVault(failing, <String, String>{
      guard.tokenKey: 'a-token',
      guard.userCacheKey: '{"id":1}',
    });
    // setInstance AFTER the container is reset, since a later bind on this key
    // would evict it.
    Magic.app.setInstance('vault', vault);
    return vault;
  }

  test(
    'a logout that cannot clear the token still clears everything else',
    () async {
      // The failure this covers: `logout()` ran clearTokens, then clearUserCache,
      // then dropped the in-memory user. A keychain error on the very first
      // delete stopped all three, so the cached user stayed on disk, the app went
      // on believing it was signed in, and nothing told the caller.
      final vault = installVault({guard.tokenKey});
      guard.setUser(_User()..setRawAttributes({'id': 1}, sync: true));
      final int stateBefore = guard.stateNotifier.value;

      await expectLater(
        guard.logout(),
        throwsA(isA<MagicVaultException>()),
        reason: 'the caller has to learn the credential may still be there',
      );

      expect(
        vault.removeAttempts,
        contains(guard.userCacheKey),
        reason: 'the user cache is still attempted after the token failed',
      );
      expect(guard.user(), isNull, reason: 'the session is over in memory');
      expect(
        guard.stateNotifier.value,
        greaterThan(stateBefore),
        reason: 'and the app is told, so no screen keeps rendering a user',
      );
    },
  );

  test(
    'a logout that cannot clear the user cache still clears the token',
    () async {
      final vault = installVault({guard.userCacheKey});
      guard.setUser(_User()..setRawAttributes({'id': 1}, sync: true));

      await expectLater(guard.logout(), throwsA(isA<MagicVaultException>()));

      expect(vault.removeAttempts, contains(guard.tokenKey));
      expect(
        await vault.get(guard.tokenKey),
        isNull,
        reason: 'the token is the one that matters most; it is gone',
      );
      expect(guard.user(), isNull);
    },
  );

  test('an ordinary logout still succeeds quietly', () async {
    // The guard above must not turn a normal logout into a throw.
    final vault = installVault(const <String>{});
    guard.setUser(_User()..setRawAttributes({'id': 1}, sync: true));

    await guard.logout();

    expect(guard.user(), isNull);
    expect(await vault.get(guard.tokenKey), isNull);
    expect(await vault.get(guard.userCacheKey), isNull);
  });

  test(
    'clearTokens attempts the refresh token even when the first fails',
    () async {
      // Same shape one level down: clearTokens deleted the access token, then
      // nulled its cache, then deleted the refresh token, so a failure on the
      // first left a live refresh token behind.
      final vault = _FailingVault(
        {'auth_token'},
        <String, String>{'auth_token': 'a', 'auth_refresh_token': 'r'},
      );
      Magic.app.setInstance('vault', vault);

      await expectLater(
        guard.clearTokens(),
        throwsA(isA<MagicVaultException>()),
      );

      expect(
        vault.removeAttempts,
        contains('auth_refresh_token'),
        reason: 'a refresh token left behind is a live session',
      );
    },
  );
}
