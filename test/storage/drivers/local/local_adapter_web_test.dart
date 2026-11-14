@TestOn('browser')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/storage/drivers/local/local_adapter_web.dart';
import 'package:web/web.dart' as web;

// Run with `flutter test --platform chrome test/storage/drivers/local`.
// Files written by 0.0.41 sit in localStorage under `flutter.` + key with a
// json-encoded value (the shared_preferences_web shape); the adapter must keep
// reading and writing that exact shape.
void main() {
  const root = 'adapter-test';
  const fileKey = 'flutter.storage:$root:a.txt';
  const mimeKey = 'flutter.storage:$root:a.txt:mime';

  final bytes = Uint8List.fromList(utf8.encode('hello web'));

  late LocalAdapter adapter;

  setUp(() {
    web.window.localStorage.clear();
    adapter = LocalAdapter(root: root);
  });

  tearDown(() {
    web.window.localStorage.clear();
  });

  group('LocalAdapter (web)', () {
    test(
      'reads a file written in the legacy shared_preferences shape',
      () async {
        web.window.localStorage.setItem(
          fileKey,
          json.encode(base64Encode(bytes)),
        );

        expect(await adapter.read('a.txt'), bytes);
        expect(await adapter.exists('a.txt'), isTrue);
      },
    );

    test('reads what localStorage holds now, not a snapshot', () async {
      await adapter.write('warm.txt', bytes);

      web.window.localStorage.setItem(
        fileKey,
        json.encode(base64Encode(bytes)),
      );

      expect(await adapter.read('a.txt'), bytes);
    });

    test('writes the file and mime type as json-encoded entries', () async {
      await adapter.write('a.txt', bytes, mimeType: 'text/plain');

      expect(
        web.window.localStorage.getItem(fileKey),
        json.encode(base64Encode(bytes)),
      );
      expect(
        web.window.localStorage.getItem(mimeKey),
        json.encode('text/plain'),
      );
    });

    test('answers null for a missing file', () async {
      expect(await adapter.read('missing.txt'), isNull);
      expect(await adapter.exists('missing.txt'), isFalse);
    });

    test('delete removes the file and its mime entry', () async {
      await adapter.write('a.txt', bytes, mimeType: 'text/plain');

      expect(await adapter.delete('a.txt'), isTrue);
      expect(web.window.localStorage.getItem(fileKey), isNull);
      expect(web.window.localStorage.getItem(mimeKey), isNull);
      expect(await adapter.delete('a.txt'), isFalse);
    });

    test('getUrl serves a blob for a legacy entry', () async {
      web.window.localStorage.setItem(
        fileKey,
        json.encode(base64Encode(bytes)),
      );
      web.window.localStorage.setItem(mimeKey, json.encode('text/plain'));

      final url = await adapter.getUrl('a.txt');

      expect(url, startsWith('blob:'));
    });
  });
}
