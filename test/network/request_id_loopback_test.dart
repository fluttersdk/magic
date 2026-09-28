import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// Records the id every request, response and error carried as it crossed
/// the interceptor bridge.
class _IdRecorder extends MagicNetworkInterceptor {
  final Map<String, int?> requestIdByPath = <String, int?>{};

  final List<int?> responseIds = <int?>[];

  final List<int?> errorIds = <int?>[];

  @override
  dynamic onRequest(MagicRequest request) {
    requestIdByPath[request.url] = request.id;
    return request;
  }

  @override
  dynamic onResponse(MagicResponse response) {
    responseIds.add(response.id);
    return response;
  }

  @override
  dynamic onError(MagicError error) {
    errorIds.add(error.id);
    return error;
  }
}

/// What this pins: every request a [DioNetworkDriver] sends carries its own
/// id, and the [MagicResponse] or [MagicError] it produces carries the SAME
/// id, so a consumer can pair concurrent requests with their answers even
/// when they complete out of order. Answers are staggered on a real socket
/// so the second request finishes first.
void main() {
  late HttpServer server;
  late DioNetworkDriver driver;
  late _IdRecorder recorder;

  setUp(() async {
    MagicApp.reset();
    Magic.flush();

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((HttpRequest request) async {
      final int delayMs = switch (request.uri.path) {
        '/slow' => 300,
        _ => 0,
      };
      await Future<void>.delayed(Duration(milliseconds: delayMs));
      request.response
        ..statusCode = request.uri.path == '/missing' ? 404 : 200
        ..headers.contentType = ContentType.json
        ..write('{"path":"${request.uri.path}"}');
      await request.response.close();
    });

    recorder = _IdRecorder();
    driver = DioNetworkDriver(baseUrl: 'http://127.0.0.1:${server.port}')
      ..addInterceptor(recorder);
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('two concurrent responses completing in reverse order each carry '
      'their own request id', () async {
    final Future<MagicResponse> slow = driver.get('/slow');
    final Future<MagicResponse> fast = driver.get('/fast');

    final MagicResponse slowResponse = await slow;
    final MagicResponse fastResponse = await fast;

    final int? slowId = recorder.requestIdByPath['/slow'];
    final int? fastId = recorder.requestIdByPath['/fast'];
    expect(slowId, isNotNull);
    expect(fastId, isNotNull);
    expect(slowId, isNot(fastId));

    // Reverse completion: the interceptor saw the fast answer first.
    expect(recorder.responseIds, <int?>[fastId, slowId]);

    expect(slowResponse.id, slowId);
    expect(fastResponse.id, fastId);
    expect(slowResponse.data, <String, dynamic>{'path': '/slow'});
  });

  test('an error carries its request id, and so does the response built '
      'from it', () async {
    final MagicResponse response = await driver.get('/missing');

    final int? id = recorder.requestIdByPath['/missing'];
    expect(id, isNotNull);
    expect(recorder.errorIds, <int?>[id]);
    expect(response.statusCode, 404);
    expect(response.id, id);
  });
}
