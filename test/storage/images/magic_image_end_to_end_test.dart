import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

// The whole path with nothing injected but the folder: a real server, the real
// wire, real files and the real engine decode. A launch is simulated by a new
// cache over the same folder and an emptied memory cache.

Future<Uint8List> _png(int width, int height) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();

  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF336699),
  );

  final ui.Image image = await recorder.endRecording().toImage(width, height);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);

  return data!.buffer.asUint8List();
}

Future<List<(int, int)>> _draw(ImageProvider provider, {int count = 1}) async {
  final List<(int, int)> frames = <(int, int)>[];
  final List<Object> errors = <Object>[];
  final ImageStream stream = provider.resolve(ImageConfiguration.empty);

  stream.addListener(
    ImageStreamListener((ImageInfo info, bool _) {
      frames.add((info.image.width, info.image.height));
    }, onError: (Object error, StackTrace? _) => errors.add(error)),
  );

  for (int i = 0; i < 80 && frames.length < count && errors.isEmpty; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }

  expect(errors, isEmpty);

  return frames;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory folder;
  late HttpServer server;
  late int requests;
  late MagicImageCache previous;

  setUp(() {
    // The test binding answers every request with a 400; this test talks to a
    // real loopback server.
    HttpOverrides.global = null;
    previous = MagicImageCache.instance;
    folder = Directory.systemTemp.createTempSync('magic_image_e2e');
    requests = 0;
  });

  tearDown(() async {
    MagicImageCache.instance = previous;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await server.close(force: true);
    folder.deleteSync(recursive: true);
  });

  Future<void> serve(Uint8List body) async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(
      server.forEach((HttpRequest request) async {
        requests++;
        request.response.add(body);
        await request.response.close();
      }),
    );
  }

  /// A new launch: a new cache over the same folder, an empty memory cache.
  void relaunch() {
    MagicImageCache.instance = MagicImageCache(store: MagicImageStore(folder));
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  testWidgets('an image is fetched once and drawn from the device after', (
    WidgetTester tester,
  ) async {
    final Uint8List body = (await tester.runAsync(() => _png(3, 2)))!;
    await tester.runAsync(() => serve(body));

    final String url = 'http://127.0.0.1:${server.port}/poster.png';

    await tester.runAsync(() async {
      relaunch();
      expect(await _draw(MagicImage.of(url)!), <(int, int)>[(3, 2)]);
      expect(requests, 1);
      expect(folder.listSync(), hasLength(1));

      // The next launch finds it on the device.
      relaunch();
      expect(await _draw(MagicImage.of(url)!), <(int, int)>[(3, 2)]);
      expect(requests, 1);

      // And with the host gone altogether.
      await server.close(force: true);
      relaunch();
      expect(await _draw(MagicImage.of(url)!), <(int, int)>[(3, 2)]);
    });
  });

  testWidgets('the stand-in is kept and the better picture replaces it', (
    WidgetTester tester,
  ) async {
    final Uint8List body = (await tester.runAsync(() => _png(3, 2)))!;
    await tester.runAsync(() => serve(body));

    final String panel = 'http://127.0.0.1:${server.port}/panel.png';
    final String ours = 'http://127.0.0.1:${server.port}/ours.png';

    await tester.runAsync(() async {
      relaunch();

      // Only the stand-in is on the device: it draws, then ours arrives.
      await MagicImageCache.instance.file(panel);
      expect(requests, 1);

      final List<(int, int)> frames = await _draw(
        MagicImage.of(ours, fallback: panel)!,
        count: 2,
      );

      expect(frames, hasLength(2), reason: 'the stand-in, then ours');
      expect(requests, 2);
      expect(folder.listSync(), hasLength(2));
    });
  });
}
