import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/cli/commands/magic_install_command.dart';
import 'package:path/path.dart' as p;

// ---------------------------------------------------------------------------
// Test-only fakes (NOT exported from lib/).
// ---------------------------------------------------------------------------

/// Recording [PromptDriver] that counts invocations and returns defaults.
///
/// Tests assert on [callCount] to verify that non-interactive mode bypasses
/// the prompt layer entirely.
class _RecordingPromptDriver implements PromptDriver {
  int callCount = 0;

  @override
  String ask(
    String question, {
    String? defaultValue,
    String? Function(String)? validator,
  }) {
    callCount++;
    return defaultValue ?? '';
  }

  @override
  bool confirm(String question, {bool defaultValue = false}) {
    callCount++;
    return defaultValue;
  }

  @override
  String choice(
    String question, {
    required List<String> options,
    String? defaultValue,
  }) {
    callCount++;
    return defaultValue ?? options.first;
  }

  @override
  String secret(String question) {
    callCount++;
    return '';
  }
}

/// Fixture-backed [StubDriver]. Keyed by stub name; ignores [searchPaths] so
/// in-memory fakes work without touching the host filesystem.
class _FixtureStubDriver implements StubDriver {
  _FixtureStubDriver(this._stubs);

  final Map<String, String> _stubs;

  @override
  String load(String name, {List<String>? searchPaths}) {
    final body = _stubs[name];
    if (body == null) {
      throw StateError(
        'Stub "$name" not registered in _FixtureStubDriver. '
        'Available: ${_stubs.keys.join(', ')}',
      );
    }
    return body;
  }

  @override
  String replace(String stub, Map<String, String> replacements) {
    var out = stub;
    replacements.forEach((k, v) {
      out = out.replaceAll('{{ $k }}', v).replaceAll('{{$k}}', v);
    });
    return out;
  }

  @override
  String make(String name, Map<String, String> replacements) =>
      replace(load(name), replacements);
}

/// Recording [ArtisanCommand] stub used to verify that auto-refresh invokes
/// the registered `plugins:refresh` command during install.
///
/// Records call count and the last [ArtisanContext] it received so tests can
/// assert both that it was invoked and that it received the correct context.
class _RecordingRefreshCommand extends ArtisanCommand {
  int callCount = 0;
  ArtisanContext? lastCtx;

  @override
  String get signature => 'plugins:refresh';

  @override
  String get description => 'Stub plugins:refresh for testing.';

  @override
  CommandBoot get boot => CommandBoot.none;

  @override
  Future<int> handle(ArtisanContext ctx) async {
    callCount++;
    lastCtx = ctx;
    ctx.output.success('plugins:refresh invoked (stub)');
    return 0;
  }
}

/// Test subclass of [MagicInstallCommand] that pins the three seam points so
/// no host filesystem access or `Isolate.resolvePackageUri` round-trip occurs.
class _TestableMagicInstallCommand extends MagicInstallCommand {
  _TestableMagicInstallCommand({
    required this.fakeManifestPath,
    required this.fakeContext,
    required String fakeStubsDir,
  }) : _fakeStubsDir = fakeStubsDir;

  final String fakeManifestPath;
  final InstallContext fakeContext;
  final String _fakeStubsDir;

  @override
  Future<String?> resolveManifestPath() async => fakeManifestPath;

  @override
  InstallContext buildContext(ArtisanContext ctx) => fakeContext;

  @override
  String? resolveMagicStubsDir(InstallContext installContext) => _fakeStubsDir;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds an [ArtisanContext] backed by a [MapInput] + [BufferedOutput].
///
/// [options] overrides the default base flags. [signature] is inferred from
/// the command under test when not supplied.
ArtisanContext _ctxWith(
  Map<String, dynamic> options, {
  CommandSignature? signature,
}) {
  return ArtisanContext.bare(
    MapInput(options, signature: signature),
    BufferedOutput(),
  );
}

/// Standard base flag defaults for every invocation.
const Map<String, dynamic> _baseOptions = <String, dynamic>{
  'force': false,
  'dry-run': false,
  'non-interactive': true,
  'no-bootstrap': false,
  'without-auth': false,
  'without-database': false,
  'without-network': false,
  'without-cache': false,
  'without-events': false,
  'without-localization': false,
  'without-logging': false,
  'without-broadcasting': false,
};

/// Resolved magic package root.
///
/// Flutter test always runs with the working directory set to the package
/// root, so [Directory.current] is the reliable resolution mechanism.
/// `Isolate.resolvePackageUri` is not available in flutter test contexts.
String get _magicRoot => Directory.current.path;

/// Loads the real stub file off disk so the [_FixtureStubDriver] returns the
/// same content the production [RealStubDriver] would.
String _loadStub(String name) {
  final stubPath = p.join(_magicRoot, 'assets', 'stubs', '$name.stub');
  if (!File(stubPath).existsSync()) {
    throw StateError('Stub not found at $stubPath');
  }
  return File(stubPath).readAsStringSync();
}

/// Builds the full stub fixtures map by loading all 20 install stubs from disk.
///
/// Each stub is registered under TWO keys so the [_FixtureStubDriver] can
/// handle both call sites:
///
/// - Without extension: `install/foo` — used by [MagicInstallCommand]'s fluent
///   override layer (conditional config publishes via [StubDriver.load]).
/// - With extension: `install/foo.stub` — used by [ManifestInstaller._applyPublish]
///   when it passes the raw manifest stub name (which includes `.stub`) to
///   [StubDriver.load] together with the resolved plugin stubs dir.
Map<String, String> _buildStubFixtures() {
  const stubNames = <String>[
    'install/app_config',
    'install/app_service_provider',
    'install/app_service_provider_with_auth',
    'install/auth_config',
    'install/broadcasting_config',
    'install/cache_config',
    'install/consumer_artisan',
    'install/database_config',
    'install/env',
    'install/env_example',
    'install/kernel',
    'install/kernel_with_auth',
    'install/logging_config',
    'install/main',
    'install/network_config',
    'install/route_service_provider',
    'install/routes_app',
    'install/routing_config',
    'install/view_config',
    'install/welcome_view',
  ];
  final fixtures = <String, String>{};
  for (final name in stubNames) {
    final content = _loadStub(name);
    // Without extension: fluent override layer uses this form.
    fixtures[name] = content;
    // With .stub extension: ManifestInstaller._applyPublish uses this form
    // (reads the raw key from install.yaml which includes the .stub suffix).
    fixtures['$name.stub'] = content;
  }
  return fixtures;
}

/// Fake `package_config.json` content that tells [ManifestInstaller._resolvePluginStubsDir]
/// where the magic package's stubs live.
///
/// The rootUri points to `/fake/magic` so [ManifestInstaller] resolves
/// `/fake/magic/assets/stubs` as the stubs directory. [_FixtureStubDriver]
/// ignores searchPaths entirely, so the directory value is symbolic only.
const String _fakePackageConfigJson = '''
{
  "configVersion": 2,
  "packages": [
    {
      "name": "magic",
      "rootUri": "file:///fake/magic",
      "packageUri": "lib/"
    }
  ]
}
''';

/// Stubs dir that [ManifestInstaller] resolves from the fake package_config.json.
const String _fakeStubsDir = '/fake/magic/assets/stubs';

/// Builds a fully-wired [_TestableMagicInstallCommand] + pre-built
/// [ArtisanContext] for a single test invocation.
///
/// Returns:
/// - [cmd]    — the testable command with seam overrides pinned.
/// - [ctx]    — the [ArtisanContext] to pass to [cmd.handle]. Its output
///              buffer captures every line the command writes (errors, success
///              messages, post_install text). Use `ctx.output as BufferedOutput`
///              for assertions.
/// - [fs]     — the [InMemoryFs] to assert written file paths against.
/// - [prompt] — the recording prompt driver (assert [callCount] == 0 for
///              non-interactive verification).
///
/// The InMemoryFs is pre-seeded with a fake `package_config.json` so that
/// [ManifestInstaller._resolvePluginStubsDir] finds a non-null path and calls
/// `_ctx.stubs.load(stubName, searchPaths: [...])`. [_FixtureStubDriver]
/// ignores [searchPaths] and resolves by key, so the exact directory value is
/// symbolic only.
({
  _TestableMagicInstallCommand cmd,
  ArtisanContext ctx,
  InMemoryFs fs,
  _RecordingPromptDriver prompt,
})
_buildHarness({
  _RecordingPromptDriver? prompt,
  String projectRoot = '/proj',
  Map<String, dynamic> optionOverrides = const <String, dynamic>{},
  // When supplied, the ArtisanContext is constructed with this registry so
  // ctx.registry?.find('plugins:refresh') resolves during handle().
  ArtisanRegistry? registry,
}) {
  final fs = InMemoryFs();
  // Seed package_config.json so ManifestInstaller._resolvePluginStubsDir
  // resolves to a non-null path and goes through the load(stubName, searchPaths)
  // path rather than the publishConfig fallback.
  fs.writeAsString(
    '$projectRoot/.dart_tool/package_config.json',
    _fakePackageConfigJson,
  );

  final recording = prompt ?? _RecordingPromptDriver();
  final stubs = _FixtureStubDriver(_buildStubFixtures());
  // The BufferedOutput is shared between the installContext and the cmd ctx
  // so all output from handle() — errors, success lines, post_install text —
  // is captured in one place.
  final output = BufferedOutput();

  final installContext = InstallContext.test(
    fs: fs,
    prompt: recording,
    stubs: stubs,
    projectRoot: projectRoot,
    output: output,
    clock: () => DateTime.utc(2025, 1, 1),
  );

  final cmd = _TestableMagicInstallCommand(
    fakeManifestPath: _manifestPath,
    fakeContext: installContext,
    fakeStubsDir: _fakeStubsDir,
  );

  // Build the ArtisanContext with the same output buffer so ctx.output.error()
  // calls inside handle() land in the same buffer as installContext output.
  // When a registry is provided, it is wired in so ctx.registry?.find('plugins:refresh')
  // resolves during handle().
  final options = <String, dynamic>{..._baseOptions, ...optionOverrides};
  final ctx = ArtisanContext.bare(
    MapInput(options, signature: cmd.parsedSignature),
    output,
    registry: registry,
  );

  return (cmd: cmd, ctx: ctx, fs: fs, prompt: recording);
}

/// Absolute path to the fixture install.yaml.
///
/// Resolved lazily on first access so tests that run before the working
/// directory is known still resolve correctly. Flutter test always launches
/// with the working directory pointing at the package root.
String get _manifestPath =>
    p.join(_magicRoot, 'test', 'cli', 'commands', 'fixtures', 'install.yaml');

void main() {
  // ---------------------------------------------------------------------------
  // Group 1: signature / metadata
  // ---------------------------------------------------------------------------

  group('MagicInstallCommand, signature / metadata', () {
    test('signature includes the 4 base flags from ArtisanInstallCommand', () {
      final cmd = MagicInstallCommand();
      final optionNames = cmd.parsedSignature!.options
          .map((o) => o.name)
          .toSet();
      expect(
        optionNames,
        containsAll(<String>[
          'force',
          'dry-run',
          'non-interactive',
          'no-bootstrap',
        ]),
      );
    });

    test('signature includes all 8 --without-X flags', () {
      final cmd = MagicInstallCommand();
      final optionNames = cmd.parsedSignature!.options
          .map((o) => o.name)
          .toSet();
      expect(
        optionNames,
        containsAll(<String>[
          'without-auth',
          'without-database',
          'without-network',
          'without-cache',
          'without-events',
          'without-localization',
          'without-logging',
          'without-broadcasting',
        ]),
      );
    });

    test('pluginName(ctx) returns the static string "magic"', () {
      final cmd = MagicInstallCommand();
      final ctx = _ctxWith(_baseOptions, signature: cmd.parsedSignature);
      expect(cmd.pluginName(ctx), 'magic');
    });

    test('description mentions Magic framework', () {
      final cmd = MagicInstallCommand();
      expect(cmd.description.toLowerCase(), contains('magic'));
    });

    test('boot is CommandBoot.none (no VM Service required)', () {
      final cmd = MagicInstallCommand();
      expect(cmd.boot, CommandBoot.none);
    });

    test('extends ArtisanInstallCommand', () {
      final cmd = MagicInstallCommand();
      expect(cmd, isA<ArtisanInstallCommand>());
    });
  });

  // ---------------------------------------------------------------------------
  // Group 2: full default install
  // ---------------------------------------------------------------------------

  group('MagicInstallCommand, full default install', () {
    test('non-interactive default install exits 0 and writes all 6 conditional '
        'config files', () async {
      final (:cmd, :ctx, :fs, prompt: _) = _buildHarness();

      final exit = await cmd.handle(ctx);

      expect(
        exit,
        0,
        reason: 'Output: ${(ctx.output as BufferedOutput).content}',
      );
      // All 6 conditional config files must be present.
      expect(fs.exists('/proj/lib/config/auth.dart'), isTrue);
      expect(fs.exists('/proj/lib/config/database.dart'), isTrue);
      expect(fs.exists('/proj/lib/config/network.dart'), isTrue);
      expect(fs.exists('/proj/lib/config/cache.dart'), isTrue);
      expect(fs.exists('/proj/lib/config/logging.dart'), isTrue);
      expect(fs.exists('/proj/lib/config/broadcasting.dart'), isTrue);
    });

    test('main.dart contains all 6 conditional configFactories', () async {
      final (:cmd, :ctx, :fs, prompt: _) = _buildHarness();

      await cmd.handle(ctx);

      final main = fs.readAsString('/proj/lib/main.dart');
      expect(main, contains('authConfig'));
      expect(main, contains('databaseConfig'));
      expect(main, contains('networkConfig'));
      expect(main, contains('cacheConfig'));
      expect(main, contains('loggingConfig'));
      expect(main, contains('broadcastingConfig'));
    });

    test('app.dart contains all expected infrastructure providers', () async {
      final (:cmd, :ctx, :fs, prompt: _) = _buildHarness();

      await cmd.handle(ctx);

      final app = fs.readAsString('/proj/lib/config/app.dart');
      expect(app, contains('CacheServiceProvider'));
      expect(app, contains('DatabaseServiceProvider'));
      expect(app, contains('NetworkServiceProvider'));
      expect(app, contains('VaultServiceProvider'));
      expect(app, contains('BroadcastServiceProvider'));
      expect(app, contains('LocalizationServiceProvider'));
    });
  });

  // ---------------------------------------------------------------------------
  // Group 3: per-flag conditional behavior (8 tests)
  // ---------------------------------------------------------------------------

  group('MagicInstallCommand, --without-auth', () {
    test(
      'omits lib/config/auth.dart, VaultServiceProvider, authConfig',
      () async {
        final (:cmd, :ctx, :fs, prompt: _) = _buildHarness(
          optionOverrides: <String, dynamic>{'without-auth': true},
        );

        final exit = await cmd.handle(ctx);

        expect(exit, 0, reason: (ctx.output as BufferedOutput).content);
        expect(fs.exists('/proj/lib/config/auth.dart'), isFalse);
        final app = fs.readAsString('/proj/lib/config/app.dart');
        expect(app, isNot(contains('VaultServiceProvider')));
        final main = fs.readAsString('/proj/lib/main.dart');
        expect(main, isNot(contains('authConfig')));
      },
    );
  });

  group('MagicInstallCommand, --without-database', () {
    test('omits lib/config/database.dart, DatabaseServiceProvider, '
        'databaseConfig', () async {
      final (:cmd, :ctx, :fs, prompt: _) = _buildHarness(
        optionOverrides: <String, dynamic>{'without-database': true},
      );

      final exit = await cmd.handle(ctx);

      expect(exit, 0);
      expect(fs.exists('/proj/lib/config/database.dart'), isFalse);
      final app = fs.readAsString('/proj/lib/config/app.dart');
      expect(app, isNot(contains('DatabaseServiceProvider')));
      final main = fs.readAsString('/proj/lib/main.dart');
      expect(main, isNot(contains('databaseConfig')));
    });
  });

  group('MagicInstallCommand, --without-network', () {
    test('omits lib/config/network.dart, NetworkServiceProvider, '
        'networkConfig', () async {
      final (:cmd, :ctx, :fs, prompt: _) = _buildHarness(
        optionOverrides: <String, dynamic>{'without-network': true},
      );

      final exit = await cmd.handle(ctx);

      expect(exit, 0);
      expect(fs.exists('/proj/lib/config/network.dart'), isFalse);
      final app = fs.readAsString('/proj/lib/config/app.dart');
      expect(app, isNot(contains('NetworkServiceProvider')));
      final main = fs.readAsString('/proj/lib/main.dart');
      expect(main, isNot(contains('networkConfig')));
    });
  });

  group('MagicInstallCommand, --without-cache', () {
    test('omits lib/config/cache.dart, CacheServiceProvider, '
        'cacheConfig', () async {
      final (:cmd, :ctx, :fs, prompt: _) = _buildHarness(
        optionOverrides: <String, dynamic>{'without-cache': true},
      );

      final exit = await cmd.handle(ctx);

      expect(exit, 0);
      expect(fs.exists('/proj/lib/config/cache.dart'), isFalse);
      final app = fs.readAsString('/proj/lib/config/app.dart');
      expect(app, isNot(contains('CacheServiceProvider')));
      final main = fs.readAsString('/proj/lib/main.dart');
      expect(main, isNot(contains('cacheConfig')));
    });
  });

  group('MagicInstallCommand, --without-logging', () {
    test(
      'omits lib/config/logging.dart and loggingConfig from main.dart',
      () async {
        final (:cmd, :ctx, :fs, prompt: _) = _buildHarness(
          optionOverrides: <String, dynamic>{'without-logging': true},
        );

        final exit = await cmd.handle(ctx);

        expect(exit, 0);
        expect(fs.exists('/proj/lib/config/logging.dart'), isFalse);
        final main = fs.readAsString('/proj/lib/main.dart');
        expect(main, isNot(contains('loggingConfig')));
      },
    );
  });

  group('MagicInstallCommand, --without-broadcasting', () {
    test('omits lib/config/broadcasting.dart, BroadcastServiceProvider, '
        'broadcastingConfig', () async {
      final (:cmd, :ctx, :fs, prompt: _) = _buildHarness(
        optionOverrides: <String, dynamic>{'without-broadcasting': true},
      );

      final exit = await cmd.handle(ctx);

      expect(exit, 0);
      expect(fs.exists('/proj/lib/config/broadcasting.dart'), isFalse);
      final app = fs.readAsString('/proj/lib/config/app.dart');
      expect(app, isNot(contains('BroadcastServiceProvider')));
      final main = fs.readAsString('/proj/lib/main.dart');
      expect(main, isNot(contains('broadcastingConfig')));
    });
  });

  group('MagicInstallCommand, --without-localization', () {
    test('omits LocalizationServiceProvider from app.dart', () async {
      final (:cmd, :ctx, :fs, prompt: _) = _buildHarness(
        optionOverrides: <String, dynamic>{'without-localization': true},
      );

      final exit = await cmd.handle(ctx);

      expect(exit, 0);
      final app = fs.readAsString('/proj/lib/config/app.dart');
      expect(app, isNot(contains('LocalizationServiceProvider')));
    });
  });

  // ---------------------------------------------------------------------------
  // Group 4: edge cases
  // ---------------------------------------------------------------------------

  group('MagicInstallCommand, edge cases', () {
    test('all 8 --without-X=true produces a minimal install with only '
        'base app/view/routing configs', () async {
      final (:cmd, :ctx, :fs, prompt: _) = _buildHarness(
        optionOverrides: <String, dynamic>{
          'without-auth': true,
          'without-database': true,
          'without-network': true,
          'without-cache': true,
          'without-events': true,
          'without-localization': true,
          'without-logging': true,
          'without-broadcasting': true,
        },
      );

      final exit = await cmd.handle(ctx);

      expect(exit, 0, reason: (ctx.output as BufferedOutput).content);
      // All 6 conditional configs must be absent.
      expect(fs.exists('/proj/lib/config/auth.dart'), isFalse);
      expect(fs.exists('/proj/lib/config/database.dart'), isFalse);
      expect(fs.exists('/proj/lib/config/network.dart'), isFalse);
      expect(fs.exists('/proj/lib/config/cache.dart'), isFalse);
      expect(fs.exists('/proj/lib/config/logging.dart'), isFalse);
      expect(fs.exists('/proj/lib/config/broadcasting.dart'), isFalse);
      // The 3 always-on configs must be present.
      expect(fs.exists('/proj/lib/config/app.dart'), isTrue);
      expect(fs.exists('/proj/lib/config/view.dart'), isTrue);
      expect(fs.exists('/proj/lib/config/routing.dart'), isTrue);
      // main.dart must not include any conditional factory.
      final main = fs.readAsString('/proj/lib/main.dart');
      expect(main, isNot(contains('authConfig')));
      expect(main, isNot(contains('databaseConfig')));
      expect(main, isNot(contains('networkConfig')));
      expect(main, isNot(contains('cacheConfig')));
      expect(main, isNot(contains('loggingConfig')));
      expect(main, isNot(contains('broadcastingConfig')));
    });

    test(
      '--force bypasses ConflictDetector for a pre-existing lib/main.dart',
      () async {
        final (:cmd, :ctx, :fs, prompt: _) = _buildHarness(
          optionOverrides: <String, dynamic>{'force': true},
        );
        // Pre-seed the target so the conflict detector would normally flag it.
        fs.writeAsString(
          '/proj/lib/main.dart',
          '// pre-existing flutter counter app\n',
        );

        final exit = await cmd.handle(ctx);

        expect(
          exit,
          0,
          reason: 'Output: ${(ctx.output as BufferedOutput).content}',
        );
        final main = fs.readAsString('/proj/lib/main.dart');
        expect(main, isNot(contains('pre-existing flutter counter app')));
        expect(main, contains('Magic.init'));
      },
    );

    test(
      '--dry-run returns exit 0 and writes no install-generated files',
      () async {
        final (:cmd, :ctx, :fs, prompt: _) = _buildHarness(
          optionOverrides: <String, dynamic>{'dry-run': true},
        );

        final exit = await cmd.handle(ctx);

        expect(exit, 0);
        // Only the pre-seeded package_config.json must be present.
        // No install-generated file (lib/, .env, .artisan/) must exist.
        final snapshot = fs.snapshot;
        final installGenerated = snapshot.keys
            .where((k) => !k.contains('package_config'))
            .toList();
        expect(
          installGenerated,
          isEmpty,
          reason: 'Dry-run must not write any install-generated files',
        );
      },
    );

    test('--non-interactive does not invoke the PromptDriver', () async {
      final prompt = _RecordingPromptDriver();
      final (:cmd, :ctx, fs: _, prompt: _) = _buildHarness(prompt: prompt);

      await cmd.handle(ctx);

      expect(
        prompt.callCount,
        0,
        reason: '--non-interactive must bypass every prompt',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Group 5: app name extraction via snakeCaseToTitleCase
  // ---------------------------------------------------------------------------

  group('MagicInstallCommand.snakeCaseToTitleCase', () {
    // Direct unit tests on the @visibleForTesting method. No pipeline needed.
    final converter = MagicInstallCommand();

    test("'my_cool_app' converts to 'My Cool App'", () {
      expect(converter.snakeCaseToTitleCase('my_cool_app'), 'My Cool App');
    });

    test("single-word 'myapp' capitalises the first letter only", () {
      expect(converter.snakeCaseToTitleCase('myapp'), 'Myapp');
    });

    test('empty string returns empty string', () {
      expect(converter.snakeCaseToTitleCase(''), '');
    });

    test(
      'missing pubspec.yaml leaves appName empty and install still succeeds',
      () async {
        final (:cmd, :ctx, :fs, prompt: _) = _buildHarness();
        // No pubspec.yaml seeded into the InMemoryFs.

        final exit = await cmd.handle(ctx);

        // A missing pubspec results in an empty appName but the install must
        // still complete successfully.
        expect(exit, 0, reason: (ctx.output as BufferedOutput).content);
        final main = fs.readAsString('/proj/lib/main.dart');
        // The appName placeholder resolves to '' — MagicApplication title is blank.
        expect(main, contains("MagicApplication(title: '')"));
      },
    );

    test(
      'pubspec.yaml with name field threads appName into main.dart title',
      () async {
        final (:cmd, :ctx, :fs, prompt: _) = _buildHarness();
        fs.writeAsString('/proj/pubspec.yaml', 'name: my_cool_app\n');

        await cmd.handle(ctx);

        final main = fs.readAsString('/proj/lib/main.dart');
        expect(main, contains("MagicApplication(title: 'My Cool App')"));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group 6: post_install message
  // ---------------------------------------------------------------------------

  group('MagicInstallCommand, post_install message', () {
    test(
      'output contains the manifest post_install.message on success',
      () async {
        final (:cmd, :ctx, fs: _, prompt: _) = _buildHarness();

        final exit = await cmd.handle(ctx);

        expect(exit, 0);
        // The manifest's post_install.message begins with "Magic installed via".
        final out = (ctx.output as BufferedOutput).content;
        expect(out, contains('Magic installed via plugin:install'));
      },
    );

    test(
      'install record is created at .artisan/installed/magic.json',
      () async {
        final (:cmd, :ctx, :fs, prompt: _) = _buildHarness();

        await cmd.handle(ctx);

        final recordPath = '/proj/.artisan/installed/magic.json';
        expect(fs.exists(recordPath), isTrue);
        final content = fs.readAsString(recordPath);
        expect(content, contains('"plugin": "magic"'));
        expect(content, contains('"installedAt"'));
        expect(content, contains('"ops"'));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group 7: auto-refresh — registry present → plugins:refresh.handle invoked
  // ---------------------------------------------------------------------------

  group('MagicInstallCommand, auto-refresh with registry', () {
    test(
      'invokes the registered plugins:refresh command when registry is present',
      () async {
        final refreshStub = _RecordingRefreshCommand();
        final registry = ArtisanRegistry()
          ..register(refreshStub, providerName: 'test');

        final (:cmd, :ctx, fs: _, prompt: _) = _buildHarness(
          registry: registry,
        );

        final exit = await cmd.handle(ctx);

        expect(exit, 0, reason: (ctx.output as BufferedOutput).content);
        expect(
          refreshStub.callCount,
          1,
          reason: 'plugins:refresh must be invoked exactly once on success',
        );
      },
    );

    test(
      'auto-refresh is skipped when the install result is a dry-run',
      () async {
        final refreshStub = _RecordingRefreshCommand();
        final registry = ArtisanRegistry()
          ..register(refreshStub, providerName: 'test');

        final (:cmd, :ctx, fs: _, prompt: _) = _buildHarness(
          registry: registry,
          optionOverrides: <String, dynamic>{'dry-run': true},
        );

        final exit = await cmd.handle(ctx);

        // Dry-run exits 0 but must not trigger auto-refresh.
        expect(exit, 0);
        expect(
          refreshStub.callCount,
          0,
          reason:
              'auto-refresh must not run on dry-run — no files were written',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group 8: auto-refresh hint fallback — registry null → info hint logged
  // ---------------------------------------------------------------------------

  group('MagicInstallCommand, auto-refresh hint fallback', () {
    test(
      'logs hint when registry is null (bare ctx without ArtisanApplication)',
      () async {
        // Default harness has no registry → ctx.registry is null.
        final (:cmd, :ctx, fs: _, prompt: _) = _buildHarness();

        final exit = await cmd.handle(ctx);

        expect(exit, 0, reason: (ctx.output as BufferedOutput).content);
        final out = (ctx.output as BufferedOutput).content;
        expect(
          out,
          contains('dart run magic:artisan plugins:refresh'),
          reason: 'hint must name the manual refresh command',
        );
      },
    );

    test(
      'logs hint when registry exists but plugins:refresh is not registered',
      () async {
        // Registry present but plugins:refresh is absent → hint path.
        final registry = ArtisanRegistry();
        final (:cmd, :ctx, fs: _, prompt: _) = _buildHarness(
          registry: registry,
        );

        final exit = await cmd.handle(ctx);

        expect(exit, 0, reason: (ctx.output as BufferedOutput).content);
        final out = (ctx.output as BufferedOutput).content;
        expect(
          out,
          contains('dart run magic:artisan plugins:refresh'),
          reason:
              'hint must appear when plugins:refresh is absent from registry',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group 9: consumer wrapper bootstrap — bin/artisan.dart published via manifest
  // ---------------------------------------------------------------------------

  group('MagicInstallCommand, consumer wrapper bootstrap', () {
    test(
      'install publishes bin/artisan.dart with the consumer wrapper content',
      () async {
        final (:cmd, :ctx, :fs, prompt: _) = _buildHarness();

        final exit = await cmd.handle(ctx);

        expect(exit, 0, reason: (ctx.output as BufferedOutput).content);
        // 1. The file must exist at the manifest-declared destination.
        expect(
          fs.exists('/proj/bin/artisan.dart'),
          isTrue,
          reason: 'bin/artisan.dart must be created during install',
        );
        final content = fs.readAsString('/proj/bin/artisan.dart');
        // 2. Must import the artisan runner package.
        expect(
          content,
          contains("import 'package:fluttersdk_artisan/artisan.dart';"),
          reason: 'consumer wrapper must import fluttersdk_artisan',
        );
        // 3. Must reference the Magic artisan provider via show clause.
        expect(
          content,
          contains('MagicArtisanProvider'),
          reason: 'consumer wrapper must reference MagicArtisanProvider',
        );
        // 4. Must delegate execution via runArtisan.
        expect(
          content,
          contains('runArtisan('),
          reason: 'consumer wrapper must call runArtisan()',
        );
      },
    );
  });
}
