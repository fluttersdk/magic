import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Loads stub content from magic's bundled `assets/stubs/` directory.
///
/// Background: fluttersdk_artisan's `ArtisanGeneratorCommand.buildClass` resolves
/// stubs via `StubLoader.load(name)` which searches:
///   1. `$ARTISAN_STUBS_DIR` env var
///   2. `$MAGIC_CLI_STUBS_DIR` env var (legacy)
///   3. fluttersdk_artisan's own bundled `assets/stubs/` (pub-cache path)
///
/// Magic's make:* commands need its OWN stubs (controller, model, migration,
/// ...) which live at `<magic_root>/assets/stubs/`. Neither env var is set in
/// typical consumer environments, and the pub-cache fallback contains only
/// artisan substrate stubs (make:command, make:plugin, make:fast-cli). The
/// generator's `getStub()` override therefore returns RAW STUB CONTENT (loaded
/// here) rather than a stub name; `buildClass` recognises content via the
/// space/brace check and skips the broken StubLoader path.
///
/// Production: walks the consumer's `.dart_tool/package_config.json` to find
/// magic's `rootUri`, then reads `<root>/assets/stubs/<name>.stub`. Caches the
/// resolved stubs directory per process so repeated make:* invocations in the
/// same `dart run` skip the JSON parse.
class MagicStubLoader {
  const MagicStubLoader._();

  static String? _cachedStubsDir;

  /// Loads the named stub (without `.stub` extension) and returns its raw
  /// content as a `String`.
  ///
  /// Throws [StateError] when magic's `assets/stubs/` cannot be resolved
  /// (e.g. caller is not running inside a Flutter consumer with magic on
  /// pubspec.yaml) or when the named stub file does not exist on disk.
  static String load(String name) {
    final dir = _resolveStubsDir();
    if (dir == null) {
      throw StateError(
        'Could not resolve magic stubs directory from '
        '.dart_tool/package_config.json. Run `dart pub get` from a consumer '
        'project that lists `magic` under dependencies.',
      );
    }
    final file = File(p.join(dir, '$name.stub'));
    if (!file.existsSync()) {
      throw StateError(
        'Stub file not found: $name.stub at ${file.path}. Magic ships its '
        'stubs in assets/stubs/; verify the package_config.json points to a '
        'magic checkout that includes the assets/ directory.',
      );
    }
    return file.readAsStringSync();
  }

  /// Loads the named stub from an explicit [stubsDir] (bypassing
  /// package_config resolution). Used when the caller already knows the stubs
  /// directory, e.g. a generator under test pointing at a checkout-local
  /// `assets/stubs/`.
  ///
  /// Throws [StateError] when the stub file does not exist under [stubsDir].
  static String loadFrom(String name, String stubsDir) {
    final file = File(p.join(stubsDir, '$name.stub'));
    if (!file.existsSync()) {
      throw StateError('Stub file not found: $name.stub at ${file.path}.');
    }
    return file.readAsStringSync();
  }

  /// Resolves the absolute path to magic's `assets/stubs/` directory.
  ///
  /// Strategy:
  ///   1. Honour the `ARTISAN_STUBS_DIR` env var when set (test override).
  ///   2. Read `.dart_tool/package_config.json` from the current working
  ///      directory (the consumer project running `dart run magic:artisan`).
  ///   3. Look up the `magic` package entry, resolve its `rootUri`, and
  ///      return `<root>/assets/stubs/`.
  static String? _resolveStubsDir() {
    if (_cachedStubsDir != null) return _cachedStubsDir;

    final override = Platform.environment['ARTISAN_STUBS_DIR'];
    if (override != null && override.isNotEmpty) {
      return _cachedStubsDir = override;
    }

    final pkgConfigPath = p.join(
      Directory.current.path,
      '.dart_tool',
      'package_config.json',
    );
    if (!File(pkgConfigPath).existsSync()) return null;

    final json =
        jsonDecode(File(pkgConfigPath).readAsStringSync())
            as Map<String, dynamic>;
    final packages = json['packages'] as List<dynamic>?;
    if (packages == null) return null;

    for (final pkg in packages) {
      final entry = pkg as Map<String, dynamic>;
      if (entry['name'] != 'magic') continue;
      final rootUri = entry['rootUri'] as String;
      final pkgRoot = rootUri.startsWith('file://')
          ? Uri.parse(rootUri).toFilePath()
          : p.normalize(p.join(Directory.current.path, '.dart_tool', rootUri));
      return _cachedStubsDir = p.join(pkgRoot, 'assets', 'stubs');
    }
    return null;
  }

  /// Test seam — resets the cached stubs directory so consecutive tests can
  /// inject different stub roots via the `ARTISAN_STUBS_DIR` env var.
  static void resetForTesting() {
    _cachedStubsDir = null;
  }
}
