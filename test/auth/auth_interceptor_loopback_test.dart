import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

/// A loopback server that answers each request by the credential it carried.
///
/// `Http.fake()` never runs an interceptor (its `addInterceptor` is a no-op),
/// so the reasoning `AuthInterceptor` rests on about Dio's header map, its
/// casing and the error it hands back is never exercised by a fake. This puts
/// a real `DioNetworkDriver` on a real socket instead.
class _Panel {
  _Panel._(this._server) {
    _server.listen(_answer);
  }

  final HttpServer _server;

  /// The status each presented `Authorization` value is answered with; 401
  /// for anything not listed.
  final Map<String, int> statusFor = {};

  /// Requests this matches wait for [release] before they are answered.
  bool Function(String? authorization)? holdWhen;

  /// Completes once a held request has reached the server.
  final Completer<void> heldArrived = Completer<void>();

  /// Opens the gate held requests are waiting on.
  final Completer<void> release = Completer<void>();

  /// Every `Authorization` value the server was shown, in arrival order.
  final List<String?> presented = [];

  /// Every request body the server received, in arrival order.
  final List<String> bodies = [];

  static Future<_Panel> start() async =>
      _Panel._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  Future<void> _answer(HttpRequest request) async {
    final authorization = request.headers.value('authorization');
    presented.add(authorization);
    bodies.add(await utf8.decoder.bind(request).join());

    if (holdWhen?.call(authorization) ?? false) {
      if (!heldArrived.isCompleted) heldArrived.complete();
      await release.future;
    }

    request.response
      ..statusCode = statusFor[authorization] ?? 401
      ..headers.contentType = ContentType.json
      ..write('{}');
    await request.response.close();
  }

  Future<void> close() => _server.close(force: true);
}

void main() {
  late _Panel panel;
  late BaseGuard guard;

  setUp(() async {
    MagicApp.reset();
    Magic.flush();
    Log.fake();
    Vault.fake();
    Magic.singleton('auth', AuthManager.new);
    // `AuthManager` is a process-wide singleton that caches its guards, so a
    // test that ends signed in would hand its token to the next one.
    Auth.manager.forgetGuards();

    panel = await _Panel.start();
    final driver = DioNetworkDriver(baseUrl: panel.baseUrl)
      ..addInterceptor(AuthInterceptor());
    Magic.singleton('network', () => driver);

    guard = Auth.guard() as BaseGuard;
  });

  tearDown(() async {
    await panel.close();
    Config.set('auth', <String, dynamic>{});
    Vault.unfake();
    Log.unfake();
    MagicApp.reset();
    Magic.flush();
  });

  Future<void> signIn(String token, int id) async {
    await guard.storeToken(token);
    guard.setUser(_User()..setRawAttributes({'id': id}, sync: true));
  }

  test('a 401 on the token the guard holds ends the session', () async {
    await signIn('current-token', 1);

    final response = await Http.get('/notifications');

    expect(panel.presented, ['Bearer current-token']);
    expect(response.statusCode, 401);
    expect(guard.check(), isFalse);
    expect(guard.cachedToken, isNull);
  });

  test(
    'a 401 on a request sent before a sign-in stored a new token keeps it',
    () async {
      // The race the interceptor exists to survive, on a real socket: the
      // request goes out with the old token, a sign-in stores a new one while
      // the server is still thinking, and the refusal lands afterwards.
      await signIn('old-token', 1);
      panel.holdWhen = (value) => value == 'Bearer old-token';
      panel.statusFor['Bearer new-token'] = 200;

      final inFlight = Http.get('/notifications');
      await panel.heldArrived.future;
      await signIn('new-token', 2);
      panel.release.complete();
      final response = await inFlight;

      expect(guard.check(), isTrue);
      expect(guard.id(), 2);
      expect(guard.cachedToken, 'new-token');
      expect(await Vault.get('auth_token'), 'new-token');

      // Handed back refused, not replayed with the new token: from here a
      // rotation and a different account signing in look the same, and a
      // replay would answer one account's screen with another's data.
      expect(response.statusCode, 401);
      expect(panel.presented, ['Bearer old-token']);
    },
  );

  test('a 401 on a request that carried no token keeps the session', () async {
    // A request with no credential may have been anonymous on purpose (a
    // failed sign-in answers 401 too), so a session that opened while it was
    // in flight neither ends nor lends it a token.
    panel.holdWhen = (value) => value == null;

    final inFlight = Http.get('/login');
    await panel.heldArrived.future;
    await signIn('new-token', 2);
    panel.release.complete();
    final response = await inFlight;

    expect(panel.presented, [null]);
    expect(response.statusCode, 401);
    expect(guard.check(), isTrue);
    expect(guard.cachedToken, 'new-token');
  });

  test('an upload retried after a refresh sends its body again', () async {
    // `Http.upload` posts a Dio `FormData`, which is single use: a second
    // `finalize()` throws, the retry's catch swallowed it, and the caller got
    // the 401 back for an upload the rotated token would have carried.
    Config.set('auth', <String, dynamic>{
      'defaults': <String, dynamic>{'guard': 'api'},
      'guards': <String, dynamic>{
        'api': <String, dynamic>{'driver': 'rotating'},
      },
    });
    Auth.manager
      ..extend('rotating', (_) => _RotatingGuard())
      ..forgetGuards();
    guard = Auth.guard() as BaseGuard;
    await signIn('old-token', 1);
    panel.statusFor['Bearer rotated-token'] = 200;

    final response = await Http.upload(
      '/avatar',
      data: {'caption': 'hello'},
      files: {
        'avatar': MultipartFile.fromBytes(
          utf8.encode('avatar-bytes'),
          filename: 'a.png',
        ),
      },
    );

    expect(panel.presented, ['Bearer old-token', 'Bearer rotated-token']);
    expect(response.statusCode, 200);
    expect(panel.bodies.last, contains('avatar-bytes'));
    expect(panel.bodies.last, contains('hello'));
  });
}
