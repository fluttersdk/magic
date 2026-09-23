import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

class _User extends Model with Authenticatable {
  @override
  String get table => 'users';

  @override
  String get resource => 'users';
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
}
