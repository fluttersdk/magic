import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// Test bootstrap helper for Magic framework.
///
/// Provides standardized setup/teardown for unit and widget tests.
///
/// ```dart
/// void main() {
///   MagicTest.init();
///   test('my test', () { /* Magic container is clean */ });
/// }
/// ```
class MagicTest {
  MagicTest._();

  /// Initialize test environment with standard setup/teardown.
  ///
  /// Registers:
  /// - `setUpAll`: `TestWidgetsFlutterBinding.ensureInitialized()`
  /// - `setUp`: `MagicApp.reset()` + `Magic.flush()` + `Gate.flush()`
  /// - `tearDown`: `Magic.flush()` + `Gate.flush()`
  ///
  /// `Gate` is a process static (`facades/gate.dart`) that `Magic.flush()`
  /// does not clear, so without the extra call an ability defined in one
  /// test would leak into every later test in the same file.
  static void init() {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });
    setUp(() {
      MagicApp.reset();
      Magic.flush();
      Gate.flush();
    });
    tearDown(() {
      Magic.flush();
      Gate.flush();
      // loadTranslations() installs a loader and a locale on the Translator
      // singleton, which Magic.flush() does not reach; without this the next
      // test formats numbers and dates in that locale without saying so.
      // DateManager goes with it: it subscribes to the translator once on
      // boot, so a booted DateManager outliving the disposed translator would
      // stop following Lang.setLocale in every later test.
      DateManager.reset();
      Translator.reset();
    });
  }

  /// Load a real translation catalogue from disk for a widget test.
  ///
  /// Reads `<directory>/<locale>.json`, flattens it with
  /// [JsonAssetLoader.flatten] (the same rule the app's own loader uses),
  /// and installs a [TranslationLoader] serving that map through
  /// [Translator.setLoader] before awaiting [Translator.load]. `trans()`
  /// resolves real catalogue strings afterward instead of rendering raw
  /// dotted keys, which is what happens when no loader has ever run in a
  /// widget test.
  ///
  /// [directory] defaults to `assets/lang`, the app's own catalogue
  /// location, so a test can point at a temp directory with a small
  /// fixture json instead. Loading [locale] never requires a fallback-locale
  /// file on disk: `Translator.load` only warns and falls back to an empty
  /// map when the fallback catalogue fails to load
  /// (`translator.dart:_loadFallbackFor`).
  static Future<void> loadTranslations(
    String locale, {
    String directory = 'assets/lang',
  }) async {
    Translator.instance.setLoader(_DirectoryTranslationLoader(directory));
    await Translator.instance.load(Locale(locale));
  }

  /// Register [providers] and boot them in the order `Magic.init` does.
  ///
  /// Every `register()` runs first, in list order, then every `boot()`, in the
  /// same order, so a provider booting late can resolve what an earlier one
  /// bound. Unlike [boot] it loads no env file and no config, which is what a
  /// widget test wants when it needs a handful of real providers and nothing
  /// else. Pair it with [disposeBooted] in `tearDown`.
  static Future<void> bootProviders(List<ServiceProvider> providers) async {
    for (final provider in providers) {
      await Magic.register(provider);
    }

    await Magic.boot();
  }

  /// Undo what [bootProviders] and the providers' own `boot()` left behind
  /// that `Magic.flush()` does not reach.
  ///
  /// 1. Controllers are disposed, newest first so dependents go before what
  ///    they depend on. `Magic.flush()` only drops them from the registry, and
  ///    a controller holding a timer or a stream subscription outlives the
  ///    test and fires into the next file.
  /// 2. [SessionScope] stops listening to auth state; its subscription is a
  ///    process static.
  /// 3. [MagicRouter] drops its routes and observers, also a process static.
  /// 4. The container is flushed last, so a controller's `dispose()` can still
  ///    resolve what it needs.
  ///
  /// A controller a test already disposed itself is safe when it is a
  /// `MagicController`; a plain `ChangeNotifier` throws on a second dispose.
  static void disposeBooted() {
    for (final controller in Magic.controllers.toList().reversed) {
      if (controller is ChangeNotifier) {
        controller.dispose();
      }
    }

    SessionScope.detach();
    MagicRouter.reset();
    Magic.flush();
  }

  /// Bootstrap Magic with test configuration.
  ///
  /// Use when you need full Magic.init() with test configs.
  /// Typically called in setUpAll or at the top of main().
  static Future<void> boot({
    List<Map<String, dynamic>> configs = const [],
    String envFileName = '.env.testing',
  }) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    MagicApp.reset();
    Magic.flush();
    await Magic.init(envFileName: envFileName, configs: configs);
  }
}

/// Reads `<directory>/<locale>.json` straight off disk with `dart:io`.
///
/// [JsonAssetLoader] reads through `rootBundle`, which only resolves paths
/// declared as Flutter assets. A test fixture written to a temp directory is
/// not one, so this loader bypasses the asset bundle entirely; the flatten
/// rule stays identical via [JsonAssetLoader.flatten].
class _DirectoryTranslationLoader implements TranslationLoader {
  /// The directory a locale's `<locale>.json` file is read from.
  final String directory;

  /// Create a loader rooted at [directory].
  const _DirectoryTranslationLoader(this.directory);

  @override
  Future<Map<String, dynamic>> load(Locale locale) async {
    final file = File('$directory/${locale.languageCode}.json');
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return JsonAssetLoader.flatten(json);
  }
}
