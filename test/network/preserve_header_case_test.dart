import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

void main() {
  group('DioNetworkDriver preserveHeaderCase', () {
    test(
      'a mixed-case header key reaches the wire with its original casing',
      () async {
        // 1. Capture the raw request bytes off a loopback socket: HttpHeaders
        //    lowercases on receipt regardless of what the client sent, so only
        //    the bytes on the wire can prove the outgoing casing.
        final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final rawRequest = Completer<String>();
        final buffer = StringBuffer();
        server.listen((socket) {
          socket.listen((data) {
            buffer.write(utf8.decode(data));
            if (!rawRequest.isCompleted &&
                buffer.toString().contains('\r\n\r\n')) {
              rawRequest.complete(buffer.toString());
            }
            socket.write(
              'HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n',
            );
            socket.close();
          });
        });
        final driver = DioNetworkDriver(
          baseUrl:
              'http://${InternetAddress.loopbackIPv4.address}:${server.port}',
        );
        final requestHeaders = <String, String>{}
          ..['User-Agent'] = 'Watchools/1.0';
        // 2. Fire the request; a malformed/short response is fine, only the
        //    outgoing bytes captured above matter for this assertion.
        unawaited(
          driver
              .get('/', headers: requestHeaders)
              .catchError((_) => MagicResponse(data: null, statusCode: 0)),
        );
        final requestText = await rawRequest.future.timeout(
          const Duration(seconds: 5),
        );
        await server.close();
        expect(requestText, contains('User-Agent: Watchools/1.0'));
        expect(requestText, isNot(contains('user-agent:')));
      },
    );
  });
}
