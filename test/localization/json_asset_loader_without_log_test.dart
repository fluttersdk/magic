import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart' show Magic, MagicApp;
import 'package:magic/src/localization/loaders/json_asset_loader.dart';

/// Reading a file must not need a service.
///
/// `_loadJson` used to open with `Log.info('Loading translation file [...]')`,
/// and `Log` resolves `log` through the container, which THROWS for an unbound
/// key. [JsonAssetLoader.load]'s own catch then turned that throw into an empty
/// catalogue, so a host that loads translations before its logging provider
/// boots, or a widget test that never calls `Magic.init`, got every key
/// rendering as itself with nothing anywhere to read.
///
/// `Translator._loadFallbackFor` had already conceded the point one caller up,
/// where the same `Log` call is wrapped in `if (Magic.bound('log'))` with a
/// comment naming this exact case. The loader had no such guard.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  test('loads a catalogue with no log service bound', () async {
    // The container is empty, which is the state a widget test is in and the
    // state an app is in before `LogServiceProvider` boots.
    expect(
      Magic.bound('log'),
      isFalse,
      reason: 'the container has to be empty, or this proves nothing',
    );

    final Map<String, dynamic> loaded = await const JsonAssetLoader(
      basePath: 'test/fixtures/lang',
    ).load(const Locale('en'));

    expect(
      loaded,
      isNotEmpty,
      reason: 'the loader answered nothing and said nothing about why',
    );
    expect(loaded['greeting'], 'Hello');
  });

  test(
    'a catalogue that is not there answers empty rather than throwing',
    () async {
      // The failure path, with no `log` bound, which is the same trap one line
      // lower: the warning this loader now emits when it gives up would itself
      // throw if it were not guarded, and the caller would get a container error
      // in place of the missing-file one.
      expect(Magic.bound('log'), isFalse);

      final Map<String, dynamic> loaded = await const JsonAssetLoader(
        basePath: 'test/fixtures/nothing-here',
      ).load(const Locale('en'));

      expect(loaded, isEmpty);
    },
  );

  test(
    'a locale with no file falls back to the fallback locale, still with no log',
    () async {
      // The other arm of the same catch. `de` has no fixture; `en` does.
      final Map<String, dynamic> loaded = await const JsonAssetLoader(
        basePath: 'test/fixtures/lang',
      ).load(const Locale('de'));

      expect(loaded['greeting'], 'Hello');
    },
  );

  test('a nested key is flattened the same way with no log bound', () {
    // The branch after the read, which the throw used to skip entirely: a
    // loader that fails before `_flatten` leaves no evidence of which half
    // broke.
    expect(
      const JsonAssetLoader(
        basePath: 'test/fixtures/lang',
      ).load(const Locale('en')),
      completion(containsPair('nested.key', 'Nested value')),
    );
  });
}
