import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/storage/images/image_exception.dart';
import 'package:magic/src/storage/images/image_wire_io.dart';

// No test binding in this file: the binding's HttpOverrides answers every
// request with a 400, and these tests talk to a real loopback server.

const List<int> _jpeg = <int>[0xFF, 0xD8, 0xFF, 0xE0, 0, 16, 0x4A, 0x46];
const List<int> _png = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
const List<int> _gif = <int>[0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 1, 0];
const List<int> _webp = <int>[
  0x52, 0x49, 0x46, 0x46, 1, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, //
];

/// A client that refuses a request the way a platform with a transport policy
/// does, naming the address in its message.
class _Refusing implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) =>
      throw UnsupportedError('Non-https connection "$url" is not allowed');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late HttpServer server;
  late Uri base;
  late MagicImageWire wire;
  final List<String> paths = <String>[];

  setUp(() async {
    wire = MagicImageWire();
    paths.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = Uri.parse('http://127.0.0.1:${server.port}');
    unawaited(
      server.forEach((HttpRequest request) async {
        paths.add(request.uri.toString());

        switch (request.uri.path) {
          case '/poster.jpg':
            request.response.add(_jpeg);
          case '/missing.jpg':
            request.response.statusCode = HttpStatus.notFound;
          case '/page.html':
            request.response
              ..headers.contentType = ContentType.html
              ..write('<html>blocked</html>');
          case '/huge.jpg':
            request.response.add(<int>[..._jpeg, ...List<int>.filled(100, 1)]);
          case '/moved.jpg':
            request.response
              ..statusCode = HttpStatus.found
              ..headers.set(HttpHeaders.locationHeader, '/poster.jpg');
          case '/silent.jpg':
            // Never answers: the client has to give up on its own.
            return;
        }

        await request.response.close();
      }),
    );
  });

  tearDown(() async {
    wire.close();
    await server.close(force: true);
  });

  group('get', () {
    test('answers the bytes of an image', () async {
      final Uint8List bytes = await wire.get(base.resolve('/poster.jpg'));

      expect(bytes, _jpeg);
    });

    test('follows a redirect to the image', () async {
      final Uint8List bytes = await wire.get(base.resolve('/moved.jpg'));

      expect(bytes, _jpeg);
      expect(paths, <String>['/moved.jpg', '/poster.jpg']);
    });

    test('refuses a status other than 200', () async {
      await expectLater(
        wire.get(base.resolve('/missing.jpg')),
        throwsA(isA<MagicImageException>()),
      );
    });

    test('refuses a 200 that is not an image, a host error page', () async {
      await expectLater(
        wire.get(base.resolve('/page.html')),
        throwsA(isA<MagicImageException>()),
      );
    });

    test('refuses a body over the cap', () async {
      await expectLater(
        wire.get(base.resolve('/huge.jpg'), maxBytes: 50),
        throwsA(isA<MagicImageException>()),
      );
    });

    test('gives up on a server that never answers', () async {
      await expectLater(
        wire.get(
          base.resolve('/silent.jpg'),
          idle: const Duration(milliseconds: 200),
        ),
        throwsA(isA<MagicImageException>()),
      );
    });

    test('refuses a scheme other than http and https', () async {
      for (final String url in <String>[
        'file:///etc/passwd',
        'ftp://host.example/p.jpg',
        'p.jpg',
        'http:///p.jpg',
      ]) {
        await expectLater(
          wire.get(Uri.parse(url)),
          throwsA(isA<MagicImageException>()),
          reason: url,
        );
      }

      expect(paths, isEmpty);
    });

    test(
      'a request the platform refuses fails without naming the url',
      () async {
        final MagicImageWire refused = MagicImageWire(client: _Refusing());

        Object? failure;
        try {
          await refused.get(
            Uri.parse('http://host.example/p.jpg?token=hunter2'),
          );
        } on MagicImageException catch (error) {
          failure = error;
        }

        expect(failure, isA<MagicImageException>());
        expect(failure.toString(), isNot(contains('hunter2')));
        expect(failure.toString(), isNot(contains('host.example')));
      },
    );

    test('a refused connection fails without naming the url', () async {
      final int port = server.port;
      await server.close(force: true);

      Object? failure;
      try {
        await wire.get(Uri.parse('http://127.0.0.1:$port/p.jpg?token=hunter2'));
      } on MagicImageException catch (error) {
        failure = error;
      }

      expect(failure, isA<MagicImageException>());
      expect(failure.toString(), isNot(contains('hunter2')));
      expect(failure.toString(), isNot(contains('127.0.0.1')));
    });
  });

  group('isImage', () {
    test('knows jpeg, png, gif and webp by their first bytes', () {
      for (final List<int> bytes in <List<int>>[_jpeg, _png, _gif, _webp]) {
        expect(MagicImageWire.isImage(Uint8List.fromList(bytes)), isTrue);
      }
    });

    test('does not take a page, an empty body or a short one for an image', () {
      expect(MagicImageWire.isImage(Uint8List(0)), isFalse);
      expect(
        MagicImageWire.isImage(Uint8List.fromList(<int>[0xFF, 0xD8])),
        isFalse,
      );
      expect(
        MagicImageWire.isImage(Uint8List.fromList('<html>'.codeUnits)),
        isFalse,
      );
      // RIFF without the WEBP tag is a wav, not a picture.
      expect(
        MagicImageWire.isImage(
          Uint8List.fromList(<int>[
            0x52, 0x49, 0x46, 0x46, 1, 0, 0, 0, 0x57, 0x41, 0x56, 0x45, //
          ]),
        ),
        isFalse,
      );
    });
  });
}
