import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

class _User extends Model with Authenticatable {
  @override
  String get table => 'users';

  @override
  String get resource => 'users';
}

/// A guard whose refresh always succeeds, rotating the stored token.
class _RotatingGuard extends BaseGuard {
  @override
  Future<void> login(Map<String, dynamic> data, Authenticatable user) async {}

  @override
  Future<bool> refreshToken() async {
    await storeToken('rotated-token');

    return true;
  }
}

/// A 401 carrying whatever headers the request actually went out with.
MagicError _unauthorized(Map<String, dynamic> headers) => MagicError(
  request: MagicRequest(url: '/notifications', method: 'GET', headers: headers),
  response: MagicResponse(data: null, statusCode: 401),
);

void main() {
  late FakeAuthManager auth;

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Log.fake();
    auth = Auth.fake(user: _User()..setRawAttributes({'id': 1}, sync: true));
  });

  test(
    'a 401 on a request that carried no credential leaves the session alone',
    () async {
      // The failure this covers, measured in a browser against a consumer app:
      // the app opens a guest session on launch, and a DIFFERENT request that was
      // dispatched before that login returned went out with no `Authorization`
      // header at all. Its 401 arrived after the login had succeeded, and this
      // interceptor read it as "the session is invalid" and logged the brand new
      // session out. A 401 on a request that sent no credential says nothing
      // about the credential the guard now holds.
      await AuthInterceptor().onError(_unauthorized(const <String, dynamic>{}));

      auth.assertLoggedIn();
    },
  );

  test(
    'a 401 on a request that carried the token still ends the session',
    () async {
      // The other half, and the reason the check is on the header rather than on
      // a flag: a token the server actually rejected must still end the session,
      // because this app has no refresh endpoint to fall back on.
      await AuthInterceptor().onError(
        _unauthorized(<String, dynamic>{'Authorization': 'Bearer a-token'}),
      );

      auth.assertLoggedOut();
    },
  );

  test('the header is matched whatever casing the request carried', () async {
    // Header names are case-insensitive on the wire, and Dio keeps the casing
    // of the FIRST insertion: a caller that passed `authorization` explicitly
    // still owns that key after `onRequest` writes `Authorization` into it, and
    // the error hands back the lowercase one. An exact-key lookup would read a
    // presented token as absent and keep a session the server just refused.
    await AuthInterceptor().onError(
      _unauthorized(<String, dynamic>{'authorization': 'Bearer a-token'}),
    );

    auth.assertLoggedOut();
  });

  test('the header the request is judged by is the configured one', () async {
    // `onRequest` writes whichever header `auth.token.header` names, so the
    // reader has to look for the same one or a consumer that renames it gets
    // the bug back with no test failing.
    Config.set('auth', <String, dynamic>{
      'token': <String, dynamic>{'header': 'X-Auth', 'prefix': 'Bearer'},
    });

    await AuthInterceptor().onError(
      _unauthorized(<String, dynamic>{'X-Auth': 'Bearer a-token'}),
    );

    auth.assertLoggedOut();
  });

  group('against a guard that holds a token', () {
    // `FakeAuthManager`'s guard is not a `BaseGuard`, so it has no token to
    // compare against. A real guard over a faked vault is the seam that does.
    late BaseGuard guard;

    setUp(() async {
      MagicApp.reset();
      Magic.flush();
      Log.fake();
      Vault.fake();
      Magic.singleton('auth', AuthManager.new);

      guard = Auth.guard() as BaseGuard;
      await guard.storeToken('fresh-token');
      guard.setUser(_User()..setRawAttributes({'id': 1}, sync: true));
    });

    test(
      'a 401 on a token the guard no longer holds keeps the session',
      () async {
        // The same race with a credential in it: a request dispatched with the
        // token restored at boot is refused, a sign-in stores a new token while
        // that refusal is in flight, and the late 401 is about the old token.
        // Ending the session on it ends one the server never judged; the
        // request is replayed once with the token the guard holds now.
        final http = Http.fake();

        final result = await AuthInterceptor().onError(
          _unauthorized(<String, dynamic>{
            'authorization': 'Bearer stale-token',
          }),
        );

        expect(result, isA<MagicResponse>());
        expect(guard.check(), isTrue);
        expect(guard.cachedToken, 'fresh-token');
        final sent = http.recorded.single.$1.headers.entries
            .where((entry) => entry.key.toLowerCase() == 'authorization')
            .map((entry) => entry.value)
            .toList();
        expect(sent, <String>['Bearer fresh-token']);
      },
    );

    test('a 401 on a token after a sign-out is left alone', () async {
      // Nothing newer to replay with, and nothing left to end.
      final http = Http.fake();
      await guard.logout();

      final result = await AuthInterceptor().onError(
        _unauthorized(<String, dynamic>{'Authorization': 'Bearer fresh-token'}),
      );

      expect(result, isA<MagicError>());
      http.assertNothingSent();
    });

    test('a 401 on the token the guard holds still ends the session', () async {
      await AuthInterceptor().onError(
        _unauthorized(<String, dynamic>{'Authorization': 'Bearer fresh-token'}),
      );

      expect(guard.check(), isFalse);
      expect(guard.cachedToken, isNull);
    });
  });

  test('a retry after a refresh carries the new token exactly once', () async {
    // The retry reuses the refused request's own header map, which is a plain
    // copy of Dio's and so case-sensitive. A caller that sent `authorization`
    // left that key in place beside the `Authorization` the retry wrote, and
    // the retry went out carrying the refused token as well as the fresh one.
    MagicApp.reset();
    Magic.flush();
    Log.fake();
    Vault.fake();
    final http = Http.fake();
    Config.set('auth', <String, dynamic>{
      'defaults': <String, dynamic>{'guard': 'api'},
      'guards': <String, dynamic>{
        'api': <String, dynamic>{'driver': 'rotating'},
      },
    });
    Magic.singleton('auth', AuthManager.new);
    Auth.manager
      ..extend('rotating', (_) => _RotatingGuard())
      ..forgetGuards();
    await (Auth.guard() as BaseGuard).storeToken('old-token');

    await AuthInterceptor().onError(
      _unauthorized(<String, dynamic>{'authorization': 'Bearer old-token'}),
    );

    final sent = http.recorded.single.$1.headers.entries
        .where((entry) => entry.key.toLowerCase() == 'authorization')
        .map((entry) => entry.value)
        .toList();
    expect(sent, <String>['Bearer rotated-token']);
  });
}
