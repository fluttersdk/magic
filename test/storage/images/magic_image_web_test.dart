@TestOn('browser')
library;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

// Run with `flutter test --platform chrome test/storage/images`. On the web
// there is no file store, so the barrel exports the plain-`NetworkImage`
// build of `MagicImage` and nothing else from the images folder.
void main() {
  test('answers a NetworkImage of the address', () {
    final ImageProvider? provider = MagicImage.of('https://img.example/a.jpg');

    expect(provider, isA<NetworkImage>());
    expect((provider! as NetworkImage).url, 'https://img.example/a.jpg');
  });

  test('draws the fallback when the address is empty', () {
    final ImageProvider? provider = MagicImage.of(
      '',
      fallback: 'https://img.example/b.jpg',
    );

    expect((provider! as NetworkImage).url, 'https://img.example/b.jpg');
  });

  test('has nothing to draw for no address', () {
    expect(MagicImage.of(null), isNull);
    expect(MagicImage.of('', fallback: ''), isNull);
  });

  test('keeps the names shared sign-out code reaches for', () async {
    await MagicImageCache.instance.clear();

    expect(await MagicImageCache.instance.sweep(), 0);
    expect(const MagicImageException('x').message, 'x');
  });

  test('a width decodes the picture no wider than that', () {
    final ImageProvider? provider = MagicImage.of(
      'https://img.example/a.jpg',
      cacheWidth: 120,
    );

    expect(provider, isA<ResizeImage>());
    expect((provider! as ResizeImage).width, 120);
  });
}
