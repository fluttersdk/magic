import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'image_exception.dart';

/// Reads one image over http or https.
///
/// `dart:io` directly rather than the `Http` facade: the facade buffers a
/// JSON-shaped answer through Dio, and an image host takes no bearer token and
/// answers bytes. Flutter's own `NetworkImage` reads the same way.
final class MagicImageWire {
  /// A wire over [client], or over one built on the first request.
  MagicImageWire({HttpClient? client}) : _client = client;

  /// How long a connection may take to open.
  static const Duration connectTimeout = Duration(seconds: 10);

  /// How long the answer, headers or body, may stay silent.
  static const Duration defaultIdle = Duration(seconds: 15);

  /// The largest image accepted. A poster is under a megabyte; a body past
  /// this is not artwork, and holding it in memory would cost a scrolling grid.
  static const int defaultMaxBytes = 8 * 1024 * 1024;

  HttpClient? _client;

  /// Created on the first request, not at construction: an [HttpClient] takes
  /// the process-wide overrides in force when it is built.
  HttpClient get _http =>
      _client ??= HttpClient()..connectionTimeout = connectTimeout;

  /// The bytes of the image at [url].
  ///
  /// Throws a [MagicImageException] for anything but a 200 whose body starts
  /// like a JPEG, PNG, GIF or WebP and fits [maxBytes]. A host answers a
  /// blocked or expired address with a 200 page, which is why the body is
  /// checked and not only the status. [idle] bounds each wait for the answer.
  Future<Uint8List> get(
    Uri url, {
    int maxBytes = defaultMaxBytes,
    Duration idle = defaultIdle,
  }) async {
    if ((url.scheme != 'http' && url.scheme != 'https') || url.host.isEmpty) {
      throw const MagicImageException(
        'Only http and https addresses are fetched.',
      );
    }

    HttpClientRequest? request;

    try {
      request = await _http.getUrl(url);

      final HttpClientResponse response = await request.close().timeout(idle);

      if (response.statusCode != HttpStatus.ok) {
        // Not drained: an error page has no bound, and the connection is
        // closed rather than read to its end.
        response.listen(null).cancel().ignore();

        throw MagicImageException('The host answered ${response.statusCode}.');
      }

      final BytesBuilder body = BytesBuilder(copy: false);

      await for (final List<int> chunk in response.timeout(idle)) {
        body.add(chunk);

        if (body.length > maxBytes) {
          throw const MagicImageException('The image is larger than the cap.');
        }
      }

      final Uint8List bytes = body.takeBytes();

      if (!isImage(bytes)) {
        throw const MagicImageException('The answer is not an image.');
      }

      return bytes;
    } on TimeoutException {
      request?.abort();

      throw const MagicImageException('The host stopped answering.');
    } on IOException catch (error) {
      throw MagicImageException('The request failed (${error.runtimeType}).');
    } on UnsupportedError {
      // The platform refused the request before it left, for instance a plain
      // http address under a policy that allows only https. Its message names
      // the address, so it is not passed on.
      throw const MagicImageException('The request is not allowed.');
    }
  }

  /// Whether [bytes] open like a JPEG, PNG, GIF or WebP, the formats the
  /// engine decodes and an image host serves.
  static bool isImage(Uint8List bytes) {
    bool starts(List<int> signature, {int at = 0}) {
      if (bytes.length < at + signature.length) return false;

      for (int i = 0; i < signature.length; i++) {
        if (bytes[at + i] != signature[i]) return false;
      }

      return true;
    }

    return starts(const <int>[0xFF, 0xD8, 0xFF]) ||
        starts(const <int>[0x89, 0x50, 0x4E, 0x47]) ||
        starts(const <int>[0x47, 0x49, 0x46, 0x38]) ||
        (starts(const <int>[0x52, 0x49, 0x46, 0x46]) &&
            starts(const <int>[0x57, 0x45, 0x42, 0x50], at: 8));
  }

  /// Closes the client and any connection it still holds.
  void close() => _client?.close(force: true);
}
