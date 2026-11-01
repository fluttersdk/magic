import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

const MethodChannel _pathProviderChannel = MethodChannel(
  'plugins.flutter.io/path_provider',
);

const String _catalogue = 'https://ours.example/media/w342/a.jpg?s=abc';
const String _panel = 'https://panel.example/poster/a.jpg';

/// A real PNG of [width] by [height], so a frame's size says which image it is.
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

/// What a provider handed to the framework produced: the size of each frame,
/// in order, and each error.
class _Drawn {
  final List<(int, int)> frames = <(int, int)>[];
  final List<Object> errors = <Object>[];
}

/// Resolves [provider] and waits for [frames] frames or [errors] errors, in
/// real time: the engine decodes off the test clock.
Future<_Drawn> _draw(
  ImageProvider provider, {
  int frames = 1,
  int errors = 0,
}) async {
  final _Drawn drawn = _Drawn();
  final ImageStream stream = provider.resolve(ImageConfiguration.empty);

  stream.addListener(
    ImageStreamListener((ImageInfo info, bool _) {
      drawn.frames.add((info.image.width, info.image.height));
    }, onError: (Object error, StackTrace? _) => drawn.errors.add(error)),
  );

  for (int i = 0; i < 80; i++) {
    if (drawn.frames.length >= frames && drawn.errors.length >= errors) break;

    await Future<void>.delayed(const Duration(milliseconds: 25));
  }

  // Anything late still counts: give a stray extra frame time to show.
  await Future<void>.delayed(const Duration(milliseconds: 100));

  return drawn;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory folder;
  late MagicImageStore store;
  late List<String> asked;
  late Map<String, Future<Uint8List> Function()> hosts;
  late Uint8List big;
  late Uint8List small;
  late MagicImageCache previous;
  late DateTime now;

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    // A trim that fails only logs, and no log is bound in a unit test.
    Log.fake();
    folder = Directory.systemTemp.createTempSync('magic_image_provider');
    store = MagicImageStore(folder);
    asked = <String>[];
    hosts = <String, Future<Uint8List> Function()>{};
    now = DateTime(2026, 11, 1, 12);
    previous = MagicImageCache.instance;
    MagicImageCache.instance = MagicImageCache(
      store: store,
      now: () => now,
      fetch: (Uri url) {
        asked.add(url.toString());

        final Future<Uint8List> Function()? host = hosts[url.toString()];

        if (host == null) throw const MagicImageException('No such host.');

        return host();
      },
    );
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  tearDown(() {
    MagicImageCache.instance = previous;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    folder.deleteSync(recursive: true);
  });

  Future<void> sizes(WidgetTester tester) async {
    await tester.runAsync(() async {
      big = await _png(3, 2);
      small = await _png(1, 1);
    });
  }

  group('of', () {
    test('has nothing to draw for no address', () {
      expect(MagicImage.of(null), isNull);
      expect(MagicImage.of(''), isNull);
      expect(MagicImage.of(null, fallback: ''), isNull);
    });

    test('draws the fallback when the first address is empty', () {
      expect(MagicImage.of('', fallback: _panel), MagicImage.of(_panel));
    });

    test('a fallback equal to the address is no fallback', () {
      expect(MagicImage.of(_panel, fallback: _panel), MagicImage.of(_panel));
    });

    test('two providers of the same addresses are one key', () {
      final ImageProvider? one = MagicImage.of(_catalogue, fallback: _panel);
      final ImageProvider? two = MagicImage.of(_catalogue, fallback: _panel);

      expect(one, two);
      expect(one.hashCode, two.hashCode);
      expect(one, isNot(MagicImage.of(_catalogue)));
      expect(one, isNot(MagicImage.of(_panel, fallback: _catalogue)));
    });

    test('a width makes another key', () {
      expect(
        MagicImage.of(_panel, cacheWidth: 100),
        MagicImage.of(_panel, cacheWidth: 100),
      );
      expect(
        MagicImage.of(_panel, cacheWidth: 100),
        isNot(MagicImage.of(_panel, cacheWidth: 200)),
      );
      expect(
        MagicImage.of(_panel, cacheWidth: 100),
        isNot(MagicImage.of(_panel)),
      );
    });

    test('its description names no query and no path', () {
      final String text = MagicImage.of(
        _catalogue,
        fallback: _panel,
      ).toString();

      expect(text, isNot(contains('abc')));
      expect(text, isNot(contains('/poster/')));
    });
  });

  group('drawing', () {
    testWidgets('an address on the disk draws from it with no request', (
      WidgetTester tester,
    ) async {
      await sizes(tester);

      final _Drawn drawn = (await tester.runAsync(() async {
        await store.write(_catalogue, big);

        return _draw(MagicImage.of(_catalogue, fallback: _panel)!);
      }))!;

      expect(drawn.frames, <(int, int)>[(3, 2)]);
      expect(asked, isEmpty);
    });

    testWidgets('an address not held is fetched, stored and drawn', (
      WidgetTester tester,
    ) async {
      await sizes(tester);
      hosts[_catalogue] = () async => big;

      final _Drawn drawn = (await tester.runAsync(
        () => _draw(MagicImage.of(_catalogue)!),
      ))!;

      expect(drawn.frames, <(int, int)>[(3, 2)], reason: '${drawn.errors}');
      expect(asked, <String>[_catalogue]);
      expect(await tester.runAsync(() => store.find(_catalogue)), isNotNull);
    });

    testWidgets('the stand-in shows first while the real picture arrives', (
      WidgetTester tester,
    ) async {
      await sizes(tester);

      final _Drawn drawn = (await tester.runAsync(() async {
        // Made here, not in the test body: a completer schedules its
        // completion in the zone it was created in, and the body's zone is
        // the fake clock, which would only run it when the test is over.
        final Completer<Uint8List> gate = Completer<Uint8List>();
        hosts[_catalogue] = () => gate.future;

        await store.write(_panel, small);
        final Future<_Drawn> pending = _draw(
          MagicImage.of(_catalogue, fallback: _panel)!,
          frames: 2,
        );

        // The real picture is slow: the stand-in must already be up.
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(asked, <String>[_catalogue]);
        gate.complete(big);

        return pending;
      }))!;

      expect(drawn.frames, <(int, int)>[(1, 1), (3, 2)]);
      expect(drawn.errors, isEmpty);
    });

    testWidgets('a held picture is drawn alone, the stand-in ignored', (
      WidgetTester tester,
    ) async {
      await sizes(tester);

      final _Drawn drawn = (await tester.runAsync(() async {
        await store.write(_catalogue, big);
        await store.write(_panel, small);

        return _draw(MagicImage.of(_catalogue, fallback: _panel)!);
      }))!;

      expect(drawn.frames, <(int, int)>[(3, 2)]);
    });

    testWidgets('a stand-in not held is not fetched while the host answers', (
      WidgetTester tester,
    ) async {
      await sizes(tester);
      hosts[_catalogue] = () async => big;
      hosts[_panel] = () async => small;

      final _Drawn drawn = (await tester.runAsync(
        () => _draw(MagicImage.of(_catalogue, fallback: _panel)!),
      ))!;

      expect(drawn.frames, <(int, int)>[(3, 2)]);
      expect(asked, <String>[_catalogue]);
    });

    testWidgets('a host that fails falls back to the stand-in', (
      WidgetTester tester,
    ) async {
      await sizes(tester);
      hosts[_catalogue] = () async => throw const MagicImageException('502');
      hosts[_panel] = () async => small;

      final _Drawn drawn = (await tester.runAsync(
        () => _draw(MagicImage.of(_catalogue, fallback: _panel)!),
      ))!;

      expect(drawn.frames, <(int, int)>[(1, 1)]);
      expect(drawn.errors, isEmpty);
      expect(asked, <String>[_catalogue, _panel]);
    });

    testWidgets('a failing host leaves the held stand-in up', (
      WidgetTester tester,
    ) async {
      await sizes(tester);
      hosts[_catalogue] = () async => throw const MagicImageException('502');

      final _Drawn drawn = (await tester.runAsync(() async {
        await store.write(_panel, small);

        return _draw(MagicImage.of(_catalogue, fallback: _panel)!);
      }))!;

      expect(drawn.frames, <(int, int)>[(1, 1)]);
      expect(drawn.errors, isEmpty);
    });

    testWidgets('both hosts failing is an error, not a blank frame', (
      WidgetTester tester,
    ) async {
      hosts[_catalogue] = () async => throw const MagicImageException('502');
      hosts[_panel] = () async => throw const MagicImageException('404');

      final _Drawn drawn = (await tester.runAsync(
        () => _draw(
          MagicImage.of(_catalogue, fallback: _panel)!,
          frames: 0,
          errors: 1,
        ),
      ))!;

      expect(drawn.frames, isEmpty);
      expect(drawn.errors.single, isA<MagicImageException>());
    });

    testWidgets('a stored file the engine cannot decode is dropped and '
        'fetched again', (WidgetTester tester) async {
      await sizes(tester);
      hosts[_catalogue] = () async => big;

      final _Drawn drawn = (await tester.runAsync(() async {
        await store.write(_catalogue, Uint8List.fromList(<int>[1, 2, 3, 4]));

        return _draw(MagicImage.of(_catalogue)!);
      }))!;

      expect(drawn.frames, <(int, int)>[(3, 2)]);
      expect(asked, <String>[_catalogue]);
    });

    testWidgets('a stored file cut short is dropped and fetched again', (
      WidgetTester tester,
    ) async {
      await sizes(tester);
      hosts[_catalogue] = () async => big;

      final _Drawn drawn = (await tester.runAsync(() async {
        // The header decodes; the frame behind it does not.
        await store.write(_catalogue, big.sublist(0, big.length - 24));

        return _draw(MagicImage.of(_catalogue)!);
      }))!;

      expect(drawn.frames, <(int, int)>[(3, 2)], reason: '${drawn.errors}');
      expect(asked, <String>[_catalogue]);
    });

    testWidgets('a held stand-in cut short is dropped, the host is asked', (
      WidgetTester tester,
    ) async {
      await sizes(tester);
      hosts[_catalogue] = () async => big;

      final _Drawn drawn = (await tester.runAsync(() async {
        await store.write(_panel, small.sublist(0, small.length - 24));

        return _draw(MagicImage.of(_catalogue, fallback: _panel)!);
      }))!;

      expect(drawn.frames, <(int, int)>[(3, 2)]);
      expect(await tester.runAsync(() => store.find(_panel)), isNull);
    });

    testWidgets('fetched bytes that do not decode are an error and are not '
        'kept', (WidgetTester tester) async {
      // Starts like a PNG, then nothing: it passes the signature check.
      hosts[_catalogue] = () async =>
          Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47, 0, 0, 0, 0]);

      final _Drawn drawn = (await tester.runAsync(() async {
        final _Drawn result = await _draw(
          MagicImage.of(_catalogue)!,
          frames: 0,
          errors: 1,
        );

        expect(await store.find(_catalogue), isNull);

        return result;
      }))!;

      expect(drawn.frames, isEmpty);
      expect(drawn.errors, hasLength(1));
    });

    testWidgets('a width decodes the picture smaller, never larger', (
      WidgetTester tester,
    ) async {
      final Uint8List wide = (await tester.runAsync(() => _png(40, 20)))!;

      final List<_Drawn> drawn = (await tester.runAsync(() async {
        await store.write(_catalogue, wide);

        return <_Drawn>[
          await _draw(MagicImage.of(_catalogue, cacheWidth: 10)!),
          await _draw(MagicImage.of(_catalogue, cacheWidth: 100)!),
        ];
      }))!;

      expect(drawn[0].frames, <(int, int)>[(10, 5)]);
      expect(drawn[1].frames, <(int, int)>[(40, 20)]);
    });
  });

  group('after a failure', () {
    testWidgets('a key that failed loads again once the host is back', (
      WidgetTester tester,
    ) async {
      await sizes(tester);
      hosts[_catalogue] = () async => throw const MagicImageException('502');

      final ImageProvider provider = MagicImage.of(_catalogue)!;
      final List<_Drawn> drawn = (await tester.runAsync(() async {
        final _Drawn first = await _draw(provider, frames: 0, errors: 1);

        // The memory cache lets go of a failed key a microtask after the
        // error; the host answers from now on and the retry window is over.
        hosts[_catalogue] = () async => big;
        now = now.add(MagicImageCache.instance.retryAfter);

        return <_Drawn>[first, await _draw(provider)];
      }))!;

      expect(drawn[0].errors, hasLength(1));
      expect(drawn[1].frames, <(int, int)>[
        (3, 2),
      ], reason: '${drawn[1].errors}');
    });

    testWidgets('bytes that do not decode are not downloaded again inside the '
        'window', (WidgetTester tester) async {
      await sizes(tester);
      // Starts like a PNG, then nothing.
      hosts[_catalogue] = () async =>
          Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47, 0, 0, 0, 0]);

      final ImageProvider provider = MagicImage.of(_catalogue)!;
      int requests = 0;
      final List<_Drawn> drawn = (await tester.runAsync(() async {
        final _Drawn first = await _draw(provider, frames: 0, errors: 1);
        final _Drawn second = await _draw(provider, frames: 0, errors: 1);

        requests = asked.length;
        hosts[_catalogue] = () async => big;
        now = now.add(MagicImageCache.instance.retryAfter);

        return <_Drawn>[first, second, await _draw(provider)];
      }))!;

      expect(drawn[0].errors, hasLength(1));
      expect(drawn[1].errors, hasLength(1));
      expect(requests, 1, reason: 'one request for two draws');
      expect(drawn[2].frames, <(int, int)>[
        (3, 2),
      ], reason: '${drawn[2].errors}');
    });

    testWidgets('a key that failed before the cache could note it loads again '
        'at once', (WidgetTester tester) async {
      await sizes(tester);

      // The disk cannot be opened the first time: no host was asked, so
      // nothing is remembered against the url and only the memory cache can
      // hold the failure.
      final Directory documents = Directory.systemTemp.createTempSync(
        'magic_image_documents',
      );
      bool unavailable = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pathProviderChannel, (
            MethodCall call,
          ) async {
            if (unavailable) throw PlatformException(code: 'unavailable');

            return documents.path;
          });
      Storage.flush();
      Config.set('filesystems', <String, dynamic>{
        'default': 'local',
        'disks': <String, dynamic>{
          'local': <String, dynamic>{'driver': 'local', 'root': 'storage'},
          'images': <String, dynamic>{'driver': 'local', 'root': 'images'},
        },
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_pathProviderChannel, null);
        Storage.setManager(StorageManager());
        Config.flush();
        documents.deleteSync(recursive: true);
      });
      hosts[_catalogue] = () async => big;
      MagicImageCache.instance = MagicImageCache(
        now: () => now,
        fetch: (Uri url) {
          asked.add(url.toString());

          return hosts[url.toString()]!();
        },
      );

      final ImageProvider provider = MagicImage.of(_catalogue)!;
      final List<_Drawn> drawn = (await tester.runAsync(() async {
        final _Drawn first = await _draw(provider, frames: 0, errors: 1);

        unavailable = false;

        return <_Drawn>[first, await _draw(provider)];
      }))!;

      expect(drawn[0].errors, hasLength(1));
      expect(drawn[1].frames, <(int, int)>[
        (3, 2),
      ], reason: '${drawn[1].errors}');
    });

    testWidgets('a disk that is full still draws the picture, from memory', (
      WidgetTester tester,
    ) async {
      await sizes(tester);
      hosts[_catalogue] = () async => big;
      // A file where the folder should be: nothing can be written.
      folder.deleteSync(recursive: true);
      File(folder.path).writeAsBytesSync(<int>[0]);
      addTearDown(() {
        if (FileSystemEntity.isFileSync(folder.path)) {
          File(folder.path).deleteSync();
        }
        folder.createSync();
      });

      final _Drawn drawn = (await tester.runAsync(
        () => _draw(MagicImage.of(_catalogue)!),
      ))!;

      expect(drawn.frames, <(int, int)>[(3, 2)], reason: '${drawn.errors}');
      expect(drawn.errors, isEmpty);
    });

    testWidgets('every key of one address retries its stand-in', (
      WidgetTester tester,
    ) async {
      await sizes(tester);
      hosts[_catalogue] = () async => throw const MagicImageException('502');

      // The same addresses at two widths: two keys, one failed address.
      final ImageProvider wide = MagicImage.of(
        _catalogue,
        fallback: _panel,
        cacheWidth: 100,
      )!;
      final ImageProvider narrow = MagicImage.of(
        _catalogue,
        fallback: _panel,
        cacheWidth: 2,
      )!;
      final List<_Drawn> drawn = (await tester.runAsync(() async {
        await store.write(_panel, small);
        final _Drawn first = await _draw(wide);
        final _Drawn second = await _draw(narrow);

        hosts[_catalogue] = () async => big;
        now = now.add(MagicImageCache.instance.retryAfter);

        // The first retry fetches the address; the second finds it on disk.
        return <_Drawn>[
          first,
          second,
          await _draw(wide, frames: 2),
          await _draw(narrow),
        ];
      }))!;

      expect(drawn[0].frames, <(int, int)>[(1, 1)]);
      expect(drawn[1].frames, <(int, int)>[(1, 1)]);
      expect(drawn[2].frames, <(int, int)>[(1, 1), (3, 2)]);
      expect(drawn[3].frames, <(int, int)>[(2, 1)]);
    });

    testWidgets('a stand-in is replaced once the host is back and the window '
        'is over', (WidgetTester tester) async {
      await sizes(tester);
      hosts[_catalogue] = () async => throw const MagicImageException('502');

      final ImageProvider provider = MagicImage.of(
        _catalogue,
        fallback: _panel,
      )!;
      final List<_Drawn> drawn = (await tester.runAsync(() async {
        await store.write(_panel, small);
        final _Drawn first = await _draw(provider);

        hosts[_catalogue] = () async => big;
        now = now.add(MagicImageCache.instance.retryAfter);

        return <_Drawn>[first, await _draw(provider, frames: 2)];
      }))!;

      expect(drawn[0].frames, <(int, int)>[(1, 1)]);
      expect(drawn[1].frames, <(int, int)>[(1, 1), (3, 2)]);
    });

    testWidgets('a stand-in is kept inside the window', (
      WidgetTester tester,
    ) async {
      await sizes(tester);
      hosts[_catalogue] = () async => throw const MagicImageException('502');

      final ImageProvider provider = MagicImage.of(
        _catalogue,
        fallback: _panel,
      )!;
      final int requests = (await tester.runAsync(() async {
        await store.write(_panel, small);
        await _draw(provider);
        await _draw(provider);

        return asked.length;
      }))!;

      expect(requests, 1);
    });
  });

  group('a completer nobody listens to', () {
    testWidgets('lets a late picture go without an error', (
      WidgetTester tester,
    ) async {
      await sizes(tester);
      final List<FlutterErrorDetails> reported = <FlutterErrorDetails>[];
      final FlutterExceptionHandler? previousHandler = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previousHandler);

      await tester.runAsync(() async {
        final Completer<Uint8List> gate = Completer<Uint8List>();
        hosts[_catalogue] = () => gate.future;

        final MagicImage provider = MagicImage.of(_catalogue)! as MagicImage;
        final ImageStreamCompleter completer = provider.loadImage(
          provider,
          PaintingBinding.instance.instantiateImageCodecWithSize,
        );
        final ImageStreamListener listener = ImageStreamListener(
          (ImageInfo _, bool _) {},
        );

        // Nothing holds the completer: it is disposed as the last listener
        // leaves, before the picture is there.
        completer.addListener(listener);
        completer.removeListener(listener);

        await Future<void>.delayed(const Duration(milliseconds: 50));
        gate.complete(big);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });

      expect(reported, isEmpty);
    });
  });
}
