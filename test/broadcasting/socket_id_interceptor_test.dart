import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Echo.fake();
  });

  MagicRequest request() => MagicRequest(
    url: '/events',
    method: 'POST',
    headers: <String, dynamic>{'Authorization': 'Bearer token123'},
  );

  group('SocketIdInterceptor', () {
    test('sets X-Socket-ID to the connected socket id', () async {
      await Echo.connect();

      final result = SocketIdInterceptor().onRequest(request()) as MagicRequest;

      expect(result.headers['X-Socket-ID'], 'fake-socket-id');
      expect(result.headers['Authorization'], 'Bearer token123');
    });

    test('leaves the request untouched when there is no socket id', () {
      expect(Echo.socketId, isNull);

      final result = SocketIdInterceptor().onRequest(request()) as MagicRequest;

      expect(result.headers.containsKey('X-Socket-ID'), isFalse);
      expect(result.headers['Authorization'], 'Bearer token123');
    });

    test('stops sending the header once the socket disconnects', () async {
      await Echo.connect();
      await Echo.disconnect();

      final result = SocketIdInterceptor().onRequest(request()) as MagicRequest;

      expect(result.headers.containsKey('X-Socket-ID'), isFalse);
    });

    test('passes responses and errors through unchanged', () {
      final interceptor = SocketIdInterceptor();
      final response = MagicResponse(data: {}, statusCode: 200, headers: {});
      final error = MagicError(message: 'Not Found');

      expect(identical(interceptor.onResponse(response), response), isTrue);
      expect(identical(interceptor.onError(error), error), isTrue);
    });
  });
}
