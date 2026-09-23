import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

class _User extends Model with Authenticatable {
  @override
  String get table => 'users';

  @override
  String get resource => 'users';
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

  static Future<_Panel> start() async =>
      _Panel._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  Future<void> _answer(HttpRequest request) async {
    final authorization = request.headers.value('authorization');
    presented.add(authorization);

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
      await inFlight;

      expect(panel.presented.first, 'Bearer old-token');
      expect(guard.check(), isTrue);
      expect(guard.id(), 2);
      expect(guard.cachedToken, 'new-token');
      expect(await Vault.get('auth_token'), 'new-token');
    },
  );

  test(
    'a request refused on a token rotated while it was in flight is replayed '
    'once with the current one',
    () async {
      // The refusal is about the old token and the guard already holds a
      // newer one, so the honest answer is the one the server gives the newer
      // token, not the old token's 401: no refresh, no logout, one replay.
      await signIn('old-token', 1);
      panel.holdWhen = (value) => value == 'Bearer old-token';
      panel.statusFor['Bearer new-token'] = 200;

      final inFlight = Http.get('/notifications');
      await panel.heldArrived.future;
      await signIn('new-token', 2);
      panel.release.complete();
      final response = await inFlight;

      expect(panel.presented, ['Bearer old-token', 'Bearer new-token']);
      expect(response.statusCode, 200);
      expect(guard.check(), isTrue);
      expect(guard.cachedToken, 'new-token');
    },
  );

  test(
    'a replay the server also refuses is judged on the current token',
    () async {
      // The replay carries the current token, so its 401 IS a verdict on the
      // session: the ladder runs, and with no refresh endpoint that is a
      // logout. Two requests reach the server, never a third.
      await signIn('old-token', 1);
      panel.holdWhen = (value) => value == 'Bearer old-token';

      final inFlight = Http.get('/notifications');
      await panel.heldArrived.future;
      await signIn('new-token', 2);
      panel.release.complete();
      final response = await inFlight;

      expect(panel.presented, ['Bearer old-token', 'Bearer new-token']);
      expect(response.statusCode, 401);
      expect(guard.check(), isFalse);
    },
  );

  test('a 401 on a request that carried no token is not replayed', () async {
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
}
