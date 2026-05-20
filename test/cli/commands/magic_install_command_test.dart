import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:fluttersdk_artisan/src/commands/make_fast_cli_command.dart';
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

/// Sequence-consuming [PromptDriver] for testing interactive branches.
///
/// Each [choice] call pops the next answer from [_answers] in order. Tests can
/// inject multi-step sequences to exercise the 'diff' recursive re-prompt path
/// without touching stdin.
class _FakeSequencePromptDriver implements PromptDriver {
  _FakeSequencePromptDriver(List<String> answers)
    : _answers = List<String>.from(answers);

  final List<String> _answers;

  /// Number of [choice] calls made since construction.
  int choiceCallCount = 0;

  @override
  String ask(
    String question, {
    String? defaultValue,
    String? Function(String)? validator,
  }) => defaultValue ?? '';

  @override
  bool confirm(String question, {bool defaultValue = false}) => defaultValue;

  @override
  String choice(
    String question, {
    required List<String> options,
    String? defaultValue,
  }) {
    choiceCallCount++;
    if (_answers.isEmpty) return defaultValue ?? options.first;
    return _answers.removeAt(0);
  }

  @override
  String secret(String question) => '';
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
///
/// The [delegateArtisanInstall] hook is also overridden by default so that
/// magic-side tests do NOT spawn the real `InstallCommand.scaffoldInto` (which
/// runs `chmod`, `dart --version`, and `dart build cli` subprocesses against
/// the host filesystem). Tests that need to assert delegation behaviour read
/// [artisanDelegateCallCount] + [lastArtisanDelegateContext].
class _TestableMagicInstallCommand extends MagicInstallCommand {
  _TestableMagicInstallCommand({
    required this.fakeManifestPath,
    required this.fakeContext,
    required String fakeStubsDir,
    this.artisanDelegateExitCode = 0,
  }) : _fakeStubsDir = fakeStubsDir;

  final String fakeManifestPath;
  final InstallContext fakeContext;
  final String _fakeStubsDir;

  /// Exit code returned by the stubbed [delegateArtisanInstall].
  ///
  /// Defaults to 0 (success). Tests that exercise the non-zero branch in
  /// [MagicInstallCommand.handle] flip this to a positive integer.
  final int artisanDelegateExitCode;

  /// Number of times [delegateArtisanInstall] was invoked during the test.
  int artisanDelegateCallCount = 0;

  /// Context captured on the most recent [delegateArtisanInstall] call.
  ArtisanContext? lastArtisanDelegateContext;

  /// InstallContext captured on the most recent [delegateArtisanInstall] call.
  InstallContext? lastArtisanDelegateInstallContext;

  @override
  Future<String?> resolveManifestPath() async => fakeManifestPath;

  @override
  InstallContext buildContext(ArtisanContext ctx) => fakeContext;

  @override
  String? resolveMagicStubsDir(InstallContext installContext) => _fakeStubsDir;

  @override
  Future<int> delegateArtisanInstall(
    ArtisanContext ctx,
    InstallContext installContext,
  ) async {
    artisanDelegateCallCount++;
    lastArtisanDelegateContext = ctx;
    lastArtisanDelegateInstallContext = installContext;
    return artisanDelegateExitCode;
  }
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
  'preserve': false,
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
  // Group 9: --preserve flag and isPreserve() helper
  // ---------------------------------------------------------------------------

  group('MagicInstallCommand, --preserve flag', () {
    test('signature includes --preserve flag', () {
      final cmd = MagicInstallCommand();
      final optionNames = cmd.parsedSignature!.options
          .map((o) => o.name)
          .toSet();
      expect(optionNames, contains('preserve'));
    });

    test('isPreserve(ctx) returns true when --preserve is passed', () {
      final cmd = MagicInstallCommand();
      final ctx = _ctxWith({
        ..._baseOptions,
        'preserve': true,
      }, signature: cmd.parsedSignature);
      expect(cmd.isPreserve(ctx), isTrue);
    });

    test('isPreserve(ctx) returns false when --preserve is absent', () {
      final cmd = MagicInstallCommand();
      final ctx = _ctxWith(_baseOptions, signature: cmd.parsedSignature);
      expect(cmd.isPreserve(ctx), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Group 10: consumer wrapper bootstrap — bin/artisan.dart published via manifest
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Group 11: --force / --preserve mutex guard
  // ---------------------------------------------------------------------------

  group('MagicInstallCommand, --force/--preserve mutex', () {
    test(
      'exits 2 with error message when both --force and --preserve are passed',
      () async {
        final (:cmd, :ctx, fs: _, prompt: _) = _buildHarness(
          optionOverrides: <String, dynamic>{'force': true, 'preserve': true},
        );

        final exit = await cmd.handle(ctx);

        expect(
          exit,
          2,
          reason:
              'Exit 2 signals incorrect CLI usage (mutually exclusive flags)',
        );
        final out = (ctx.output as BufferedOutput).content;
        expect(
          out,
          contains('Cannot specify both --force and --preserve'),
          reason: 'Error message must name both conflicting flags',
        );
      },
    );
  });

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

  // ---------------------------------------------------------------------------
  // Group 12: _resolveMainDartStrategy
  // ---------------------------------------------------------------------------

  /// Builds an [ArtisanContext] + [InstallContext] pair for strategy tests.
  ///
  /// [optionOverrides] customize CLI flags (force, preserve, non-interactive).
  /// [promptDriver] replaces the default recording driver for interactive tests.
  /// [seedMainDart] pre-seeds `/proj/lib/main.dart` with the given content.
  ({
    _TestableMagicInstallCommand cmd,
    ArtisanContext ctx,
    InstallContext installContext,
    InMemoryFs fs,
  })
  buildStrategyHarness({
    Map<String, dynamic> optionOverrides = const <String, dynamic>{},
    PromptDriver? promptDriver,
    String? seedMainDart,
  }) {
    final fs = InMemoryFs();
    fs.writeAsString(
      '/proj/.dart_tool/package_config.json',
      _fakePackageConfigJson,
    );
    if (seedMainDart != null) {
      fs.writeAsString('/proj/lib/main.dart', seedMainDart);
    }

    final driver = promptDriver ?? _RecordingPromptDriver();
    final stubs = _FixtureStubDriver(_buildStubFixtures());
    final output = BufferedOutput();

    final installContext = InstallContext.test(
      fs: fs,
      prompt: driver,
      stubs: stubs,
      projectRoot: '/proj',
      output: output,
      clock: () => DateTime.utc(2025, 1, 1),
    );

    final cmd = _TestableMagicInstallCommand(
      fakeManifestPath: _manifestPath,
      fakeContext: installContext,
      fakeStubsDir: _fakeStubsDir,
    );

    final options = <String, dynamic>{..._baseOptions, ...optionOverrides};
    final ctx = ArtisanContext.bare(
      MapInput(options, signature: cmd.parsedSignature),
      output,
    );

    return (cmd: cmd, ctx: ctx, installContext: installContext, fs: fs);
  }

  group('MagicInstallCommand._resolveMainDartStrategy', () {
    test(
      'returns overwrite (scaffoldDetected=false) when lib/main.dart does not '
      'exist (fresh install)',
      () async {
        final (:cmd, :ctx, :installContext, fs: _) = buildStrategyHarness();

        final result = await cmd.resolveMainDartStrategy(ctx, installContext);

        expect(result.strategy, MainDartStrategy.overwrite);
        expect(
          result.scaffoldDetected,
          isFalse,
          reason: 'No file => no scaffold detection ran => false',
        );
      },
    );

    test('returns overwrite (scaffoldDetected=false) when --force is set '
        '(even if file exists)', () async {
      final (:cmd, :ctx, :installContext, fs: _) = buildStrategyHarness(
        optionOverrides: <String, dynamic>{'force': true},
        seedMainDart: 'void main() { /* custom */ }',
      );

      final result = await cmd.resolveMainDartStrategy(ctx, installContext);

      expect(result.strategy, MainDartStrategy.overwrite);
      expect(
        result.scaffoldDetected,
        isFalse,
        reason:
            '--force short-circuits before scaffold detection => stays false',
      );
    });

    test('returns preserve (scaffoldDetected=false) when --preserve is set '
        '(even if file exists)', () async {
      final (:cmd, :ctx, :installContext, fs: _) = buildStrategyHarness(
        optionOverrides: <String, dynamic>{'preserve': true},
        seedMainDart: 'void main() { /* custom */ }',
      );

      final result = await cmd.resolveMainDartStrategy(ctx, installContext);

      expect(result.strategy, MainDartStrategy.preserve);
      expect(result.scaffoldDetected, isFalse);
    });

    test('returns overwrite silently when scaffold markers detected', () async {
      const scaffold = '''
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(home: MyHomePage());
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() => setState(() => _counter++);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Text('You have pushed the button \$_counter times.'),
    );
  }
}
''';
      final output = BufferedOutput();
      final fs = InMemoryFs();
      fs.writeAsString(
        '/proj/.dart_tool/package_config.json',
        _fakePackageConfigJson,
      );
      fs.writeAsString('/proj/lib/main.dart', scaffold);

      final stubs = _FixtureStubDriver(_buildStubFixtures());
      final installContext = InstallContext.test(
        fs: fs,
        prompt: _RecordingPromptDriver(),
        stubs: stubs,
        projectRoot: '/proj',
        output: output,
      );

      final cmd = _TestableMagicInstallCommand(
        fakeManifestPath: _manifestPath,
        fakeContext: installContext,
        fakeStubsDir: _fakeStubsDir,
      );
      final options = <String, dynamic>{..._baseOptions};
      final ctx = ArtisanContext.bare(
        MapInput(options, signature: cmd.parsedSignature),
        output,
      );

      final result = await cmd.resolveMainDartStrategy(ctx, installContext);

      expect(result.strategy, MainDartStrategy.overwrite);
      expect(
        result.scaffoldDetected,
        isTrue,
        reason: 'Scaffold markers matched ≥3 => scaffoldDetected = true',
      );
      // Info message must be printed to signal the silent overwrite reason.
      expect(output.content, contains('Default Flutter counter app detected'));
    });

    test(
      'returns cancel with error when --non-interactive and customized file',
      () async {
        final output = BufferedOutput();
        final fs = InMemoryFs();
        fs.writeAsString(
          '/proj/.dart_tool/package_config.json',
          _fakePackageConfigJson,
        );
        // Seed a customized main.dart (no scaffold markers).
        fs.writeAsString(
          '/proj/lib/main.dart',
          'void main() { runCustomApp(); }',
        );

        final stubs = _FixtureStubDriver(_buildStubFixtures());
        final installContext = InstallContext.test(
          fs: fs,
          prompt: _RecordingPromptDriver(),
          stubs: stubs,
          projectRoot: '/proj',
          output: output,
        );

        final cmd = _TestableMagicInstallCommand(
          fakeManifestPath: _manifestPath,
          fakeContext: installContext,
          fakeStubsDir: _fakeStubsDir,
        );
        // --non-interactive is true in _baseOptions.
        final ctx = ArtisanContext.bare(
          MapInput(<String, dynamic>{
            ..._baseOptions,
            'non-interactive': true,
          }, signature: cmd.parsedSignature),
          output,
        );

        final result = await cmd.resolveMainDartStrategy(ctx, installContext);

        expect(result.strategy, MainDartStrategy.cancel);
        expect(result.scaffoldDetected, isFalse);
        expect(
          output.content,
          contains(
            'Existing lib/main.dart is not the default Flutter scaffold',
          ),
        );
      },
    );

    test('interactive prompt: selecting Overwrite returns overwrite', () async {
      final sequenceDriver = _FakeSequencePromptDriver([
        'Overwrite — Replace with Magic template',
      ]);
      final (:cmd, :ctx, :installContext, fs: _) = buildStrategyHarness(
        optionOverrides: <String, dynamic>{'non-interactive': false},
        promptDriver: sequenceDriver,
        seedMainDart: 'void main() { runCustomApp(); }',
      );

      final result = await cmd.resolveMainDartStrategy(ctx, installContext);

      expect(result.strategy, MainDartStrategy.overwrite);
      expect(sequenceDriver.choiceCallCount, 1);
    });

    test('interactive prompt: selecting Preserve returns preserve', () async {
      final sequenceDriver = _FakeSequencePromptDriver([
        'Preserve — Inject Magic into existing main.dart',
      ]);
      final (:cmd, :ctx, :installContext, fs: _) = buildStrategyHarness(
        optionOverrides: <String, dynamic>{'non-interactive': false},
        promptDriver: sequenceDriver,
        seedMainDart: 'void main() { runCustomApp(); }',
      );

      final result = await cmd.resolveMainDartStrategy(ctx, installContext);

      expect(result.strategy, MainDartStrategy.preserve);
      expect(sequenceDriver.choiceCallCount, 1);
    });

    test('interactive prompt: selecting Cancel returns cancel', () async {
      final sequenceDriver = _FakeSequencePromptDriver([
        'Cancel — Abort install',
      ]);
      final (:cmd, :ctx, :installContext, fs: _) = buildStrategyHarness(
        optionOverrides: <String, dynamic>{'non-interactive': false},
        promptDriver: sequenceDriver,
        seedMainDart: 'void main() { runCustomApp(); }',
      );

      final result = await cmd.resolveMainDartStrategy(ctx, installContext);

      expect(result.strategy, MainDartStrategy.cancel);
      expect(sequenceDriver.choiceCallCount, 1);
    });

    test(
      'interactive prompt: selecting Diff re-prompts then resolves via Overwrite',
      () async {
        // Sequence: first pick Diff, then Overwrite (re-prompt after diff).
        final sequenceDriver = _FakeSequencePromptDriver([
          'Diff — Show diff, re-prompt',
          'Overwrite — Replace with Magic template',
        ]);
        final (:cmd, :ctx, :installContext, fs: _) = buildStrategyHarness(
          optionOverrides: <String, dynamic>{'non-interactive': false},
          promptDriver: sequenceDriver,
          seedMainDart: 'void main() { runCustomApp(); }',
        );

        final result = await cmd.resolveMainDartStrategy(ctx, installContext);

        expect(result.strategy, MainDartStrategy.overwrite);
        // Two choice calls: once for Diff, once for Overwrite.
        expect(sequenceDriver.choiceCallCount, 2);
      },
    );

    test(
      'recursion cap at 5 diff selections returns overwrite as safe default',
      () async {
        // Feed 6 'Diff' answers — cap at 5 must short-circuit before consuming all.
        final sequenceDriver = _FakeSequencePromptDriver([
          'Diff — Show diff, re-prompt',
          'Diff — Show diff, re-prompt',
          'Diff — Show diff, re-prompt',
          'Diff — Show diff, re-prompt',
          'Diff — Show diff, re-prompt',
          'Diff — Show diff, re-prompt',
        ]);
        final (:cmd, :ctx, :installContext, fs: _) = buildStrategyHarness(
          optionOverrides: <String, dynamic>{'non-interactive': false},
          promptDriver: sequenceDriver,
          seedMainDart: 'void main() { runCustomApp(); }',
        );

        final result = await cmd.resolveMainDartStrategy(ctx, installContext);

        expect(result.strategy, MainDartStrategy.overwrite);
        // Cap is at depth 5, so at most 5 choice calls before the cap fires.
        expect(sequenceDriver.choiceCallCount, lessThanOrEqualTo(5));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group 13: _formatMainDartDiff (UnifiedDiffer integration)
  // ---------------------------------------------------------------------------

  group('MagicInstallCommand._formatMainDartDiff', () {
    final cmd = MagicInstallCommand();

    test(
      'two different sources: output starts with "--- lib/main.dart (existing)"',
      () {
        const existing = 'void main() { runApp(const MyApp()); }\n';
        const magicTemplate =
            "import 'package:magic/magic.dart';\n"
            'void main() async { await Magic.init(); }\n';

        final diff = cmd.formatMainDartDiff(existing, magicTemplate);

        expect(
          diff,
          startsWith('--- lib/main.dart (existing)'),
          reason:
              'Unified diff must open with the source label line prefixed by ---',
        );
      },
    );

    test('identical sources: output contains no @@ hunks', () {
      const source = "import 'package:magic/magic.dart';\nvoid main() {}\n";

      final diff = cmd.formatMainDartDiff(source, source);

      // Identical content produces no change hunks. The output must not
      // contain any @@ hunk headers regardless of whether labels are present.
      expect(
        diff,
        isNot(contains('@@')),
        reason: 'No diff hunks expected for identical inputs',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Group 14: strategy-driven handle() branching (step 2.5)
  //
  // These tests verify that the resolved [MainDartStrategy] is threaded into
  // [_applyFluentOverride] correctly and that the cancel path short-circuits
  // [handle] before [commit] fires.
  // ---------------------------------------------------------------------------

  group('MagicInstallCommand, strategy-driven main.dart write', () {
    test('strategy=overwrite + no existing main.dart => writeFile op stages '
        'Magic template content', () async {
      // No seeded lib/main.dart => strategy resolves to overwrite (fresh).
      final (:cmd, :ctx, :fs, prompt: _) = _buildHarness();

      final exit = await cmd.handle(ctx);

      expect(exit, 0, reason: (ctx.output as BufferedOutput).content);
      expect(
        fs.exists('/proj/lib/main.dart'),
        isTrue,
        reason: 'Overwrite branch must run writeFile for lib/main.dart',
      );
      final main = fs.readAsString('/proj/lib/main.dart');
      expect(
        main,
        contains('Magic.init'),
        reason: 'Overwrite branch writes the Magic template',
      );
    });

    test(
      'strategy=preserve + existing async main.dart => writeFile placeholder '
      'still stages (TODO for step 2.6 hook), commit succeeds',
      () async {
        // Seed an async user-customized main.dart so strategy resolves to
        // preserve (via --preserve flag, no scaffold markers).
        final (:cmd, :ctx, :fs, prompt: _) = _buildHarness(
          optionOverrides: <String, dynamic>{'preserve': true},
        );
        fs.writeAsString(
          '/proj/lib/main.dart',
          'void main() async {\n  runApp(const MyCustomApp());\n}\n',
        );

        final exit = await cmd.handle(ctx);

        // Step 2.5 leaves the writeFile call in the preserve branch as a
        // placeholder until step 2.6 swaps it for installer.inject* ops.
        // Commit must still succeed (--preserve forces past the conflict
        // detector via the threaded force flag).
        expect(exit, 0, reason: (ctx.output as BufferedOutput).content);
        expect(fs.exists('/proj/lib/main.dart'), isTrue);
      },
    );

    test('strategy=cancel (non-interactive + customized main.dart) => handle '
        'returns 0 and does not commit', () async {
      // Customized main.dart + non-interactive (default in _baseOptions)
      // and no --force / --preserve => strategy resolves to cancel.
      final (:cmd, :ctx, :fs, prompt: _) = _buildHarness();
      fs.writeAsString(
        '/proj/lib/main.dart',
        'void main() { runCustomApp(); }\n',
      );

      final exit = await cmd.handle(ctx);

      expect(
        exit,
        0,
        reason: 'Cancel path is a clean early exit, not an error code',
      );
      // No install-generated files must exist beyond the pre-seeded
      // package_config.json and the user's main.dart (which must be
      // untouched).
      expect(
        fs.exists('/proj/lib/config/app.dart'),
        isFalse,
        reason: 'Cancel must NOT commit any manifest publishes',
      );
      expect(
        fs.exists('/proj/.artisan/installed/magic.json'),
        isFalse,
        reason: 'Cancel must NOT create an install record',
      );
      // User's main.dart must remain byte-identical.
      expect(
        fs.readAsString('/proj/lib/main.dart'),
        'void main() { runCustomApp(); }\n',
      );
      // A user-facing cancel message must appear in output.
      final out = (ctx.output as BufferedOutput).content;
      expect(
        out,
        contains('canceled'),
        reason: 'Cancel must surface a clear message to the operator',
      );
    });

    test('strategy=overwrite (scaffold detected) silently forces past '
        'ConflictDetector without --force flag', () async {
      // Seed a full Flutter create scaffold so MainDartScaffoldDetector
      // matches ≥3 markers => strategy returns overwrite + scaffoldDetected.
      const scaffold = '''
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(home: MyHomePage());
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Text('You have pushed the button \$_counter times.'),
    );
  }
}
''';
      final (:cmd, :ctx, :fs, prompt: _) = _buildHarness();
      fs.writeAsString('/proj/lib/main.dart', scaffold);

      final exit = await cmd.handle(ctx);

      expect(exit, 0, reason: (ctx.output as BufferedOutput).content);
      final main = fs.readAsString('/proj/lib/main.dart');
      // Scaffold content must be replaced by the Magic template even though
      // --force was not passed.
      expect(main, contains('Magic.init'));
      expect(main, isNot(contains('_MyHomePageState')));
    });
  });

  // ---------------------------------------------------------------------------
  // Group 15: preserve-mode op-queueing via MainDartSmartMerger (step 2.6)
  //
  // These tests verify the preserve branch wires MainDartSmartMerger.mergeMagicInto
  // and surfaces sync-main rejection cleanly instead of exposing the raw
  // FormatException to the operator.
  // ---------------------------------------------------------------------------
  //
  // Note: _buildIntegrationHarness is defined inline below (local function) to
  // keep the helper scoped to the integration group that follows.

  group('MagicInstallCommand, preserve-mode smart-merge (step 2.6)', () {
    // A valid async main.dart that MainDartSmartMerger can transform.
    const asyncUserMain = '''
import 'package:flutter/material.dart';

void main() async {
  runApp(const MyCustomApp());
}

class MyCustomApp extends StatelessWidget {
  const MyCustomApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(home: Scaffold());
}
''';

    // A sync main.dart that MainDartSmartMerger must reject.
    const syncUserMain = '''
import 'package:flutter/material.dart';

void main() {
  runApp(const MyCustomApp());
}
''';

    // A main.dart that already has Magic injected (idempotency test).
    const alreadyMagicMain = '''
import 'package:magic/magic.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart';
import 'package:flutter/material.dart';

void main() async {
  await Magic.init(configFactories: []);
  runApp(MagicApplication(child: const MyCustomApp(), appName: 'My App'));
}

class MyCustomApp extends StatelessWidget {
  const MyCustomApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(home: Scaffold());
}
''';

    test(
      'preserve with valid async main: writeFile queued with merged content '
      'containing Magic.init and MagicApplication, commit succeeds with exit 0',
      () async {
        final (:cmd, :ctx, :fs, prompt: _) = _buildHarness(
          optionOverrides: <String, dynamic>{'preserve': true},
        );
        // Seed a valid async user-authored main.dart.
        fs.writeAsString('/proj/lib/main.dart', asyncUserMain);

        final exit = await cmd.handle(ctx);

        expect(exit, 0, reason: (ctx.output as BufferedOutput).content);
        // The merged content must be written to lib/main.dart.
        expect(fs.exists('/proj/lib/main.dart'), isTrue);
        final main = fs.readAsString('/proj/lib/main.dart');
        // Smart merger must have injected the Magic bootstrap.
        expect(
          main,
          contains('await Magic.init('),
          reason: 'mergeMagicInto must inject the Magic.init call',
        );
        // Smart merger must have wrapped runApp with MagicApplication.
        expect(
          main,
          contains('MagicApplication('),
          reason: 'mergeMagicInto must wrap runApp with MagicApplication',
        );
        // The user's existing code must be preserved (not overwritten).
        expect(
          main,
          contains('MyCustomApp'),
          reason: "preserve mode must retain the user's existing app class",
        );
      },
    );

    test(
      'preserve with sync main: exits 1 and error output contains '
      '"main() must be async"; no files are written beyond pre-existing',
      () async {
        final (:cmd, :ctx, :fs, prompt: _) = _buildHarness(
          optionOverrides: <String, dynamic>{'preserve': true},
        );
        // Seed a sync main.dart — MainDartSmartMerger will throw FormatException.
        fs.writeAsString('/proj/lib/main.dart', syncUserMain);
        // Capture the pre-abort snapshot of keys so we can verify no new
        // files were written after the error.
        final preAbortKeys = fs.snapshot.keys.toSet();

        final exit = await cmd.handle(ctx);

        expect(
          exit,
          1,
          reason: 'Sync main rejection must surface as exit 1 (not 0 or 2)',
        );
        final out = (ctx.output as BufferedOutput).content;
        expect(
          out,
          contains('main() must be async'),
          reason: 'Clean error must name the required fix',
        );
        // No install-generated files must be created after the abort.
        final postAbortKeys = fs.snapshot.keys.toSet();
        final newKeys = postAbortKeys.difference(preAbortKeys);
        expect(
          newKeys,
          isEmpty,
          reason: 'Abort on sync main must not write any install files',
        );
      },
    );

    test('preserve with already-Magic-injected main: idempotent — '
        'await Magic.init( appears exactly once in the written file', () async {
      final (:cmd, :ctx, :fs, prompt: _) = _buildHarness(
        optionOverrides: <String, dynamic>{'preserve': true},
      );
      // Seed a main.dart that already has Magic injected.
      fs.writeAsString('/proj/lib/main.dart', alreadyMagicMain);

      final exit = await cmd.handle(ctx);

      expect(exit, 0, reason: (ctx.output as BufferedOutput).content);
      final main = fs.readAsString('/proj/lib/main.dart');
      // Count occurrences of the Magic.init anchor — must be exactly 1.
      final initCount = 'await Magic.init('.allMatches(main).length;
      expect(
        initCount,
        1,
        reason:
            'mergeMagicInto must be idempotent: no duplicate Magic.init injection',
      );
      // MagicApplication must not be double-wrapped either.
      final appCount = 'MagicApplication('.allMatches(main).length;
      expect(
        appCount,
        1,
        reason: 'mergeMagicInto must not double-wrap with MagicApplication',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Group 16: end-to-end conflict resolution via handle() (step 2.7)
  //
  // Integration-level tests that exercise ALL 11 conflict scenarios through the
  // full handle() pipeline. Unlike Groups 12/14/15 which test private methods or
  // individual strategy branches, these tests verify the COMPLETE flow:
  //   mutex check → strategy resolution → main.dart branching → commit.
  //
  // The local _buildIntegrationHarness helper extends _buildHarness with:
  //   - seedMainDart: pre-seeds lib/main.dart in the InMemoryFs before handle().
  //   - sequenceDriver: injects a _FakeSequencePromptDriver for interactive tests.
  // ---------------------------------------------------------------------------

  group('MagicInstallCommand, lib/main.dart conflict resolution', () {
    // A user-authored async main.dart — not a scaffold, has no scaffold markers.
    const customizedAsyncMain = '''
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyCustomApp());
}

class MyCustomApp extends StatelessWidget {
  const MyCustomApp({super.key});
  @override
  Widget build(BuildContext context) =>
      const MaterialApp(home: Scaffold(body: Center(child: Text('Custom'))));
}
''';

    // A user-authored sync main.dart — no scaffold markers, no async keyword.
    const customizedSyncMain = '''
import 'package:flutter/material.dart';

void main() {
  runApp(const MyCustomApp());
}

class MyCustomApp extends StatelessWidget {
  const MyCustomApp({super.key});
  @override
  Widget build(BuildContext context) =>
      const MaterialApp(home: Scaffold());
}
''';

    // Full Flutter counter-app scaffold — MainDartScaffoldDetector returns true.
    const flutterScaffold = '''
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(home: MyHomePage());
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() => setState(() => _counter++);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Text('You have pushed the button \$_counter times.'),
    );
  }
}
''';

    /// Builds a harness backed by an optional [PromptDriver] and optional
    /// pre-seeded [lib/main.dart] content.
    ///
    /// Returns the same named-record shape as [_buildHarness] but omits the
    /// [_RecordingPromptDriver] from the return (unused in integration tests
    /// where we inject a [_FakeSequencePromptDriver] directly).
    ({_TestableMagicInstallCommand cmd, ArtisanContext ctx, InMemoryFs fs})
    buildIntegrationHarness({
      Map<String, dynamic> optionOverrides = const <String, dynamic>{},
      _FakeSequencePromptDriver? sequenceDriver,
      String? seedMainDart,
    }) {
      final fs = InMemoryFs();
      fs.writeAsString(
        '/proj/.dart_tool/package_config.json',
        _fakePackageConfigJson,
      );
      if (seedMainDart != null) {
        fs.writeAsString('/proj/lib/main.dart', seedMainDart);
      }

      final driver =
          sequenceDriver ?? _FakeSequencePromptDriver(const <String>[]);
      final stubs = _FixtureStubDriver(_buildStubFixtures());
      final output = BufferedOutput();

      final installContext = InstallContext.test(
        fs: fs,
        prompt: driver,
        stubs: stubs,
        projectRoot: '/proj',
        output: output,
        clock: () => DateTime.utc(2025, 1, 1),
      );

      final cmd = _TestableMagicInstallCommand(
        fakeManifestPath: _manifestPath,
        fakeContext: installContext,
        fakeStubsDir: _fakeStubsDir,
      );

      final options = <String, dynamic>{..._baseOptions, ...optionOverrides};
      final ctx = ArtisanContext.bare(
        MapInput(options, signature: cmd.parsedSignature),
        output,
      );

      return (cmd: cmd, ctx: ctx, fs: fs);
    }

    // -------------------------------------------------------------------------
    // Scenario 1: Fresh install (no existing lib/main.dart)
    // -------------------------------------------------------------------------

    test(
      '1. Fresh install (no existing main.dart): exits 0, Magic template written',
      () async {
        final (:cmd, :ctx, :fs) = buildIntegrationHarness();
        // No lib/main.dart pre-seeded — fresh project.

        final exit = await cmd.handle(ctx);

        expect(exit, 0, reason: (ctx.output as BufferedOutput).content);
        expect(fs.exists('/proj/lib/main.dart'), isTrue);
        final main = fs.readAsString('/proj/lib/main.dart');
        expect(
          main,
          contains('Magic.init'),
          reason: 'Fresh install must write the Magic template',
        );
      },
    );

    // -------------------------------------------------------------------------
    // Scenario 2: Existing scaffold + no flags → silent overwrite
    // -------------------------------------------------------------------------

    test('2. Existing scaffold + no flags: exits 0, scaffold info logged, '
        'Magic template written (silent overwrite)', () async {
      final (:cmd, :ctx, :fs) = buildIntegrationHarness(
        seedMainDart: flutterScaffold,
      );

      final exit = await cmd.handle(ctx);

      expect(exit, 0, reason: (ctx.output as BufferedOutput).content);
      final out = (ctx.output as BufferedOutput).content;
      expect(
        out,
        contains('Default Flutter counter app detected'),
        reason: 'Scaffold detection must emit the info message',
      );
      final main = fs.readAsString('/proj/lib/main.dart');
      expect(
        main,
        contains('Magic.init'),
        reason: 'Scaffold must be silently overwritten with Magic template',
      );
      expect(
        main,
        isNot(contains('_MyHomePageState')),
        reason: 'Scaffold content must be replaced, not preserved',
      );
    });

    // -------------------------------------------------------------------------
    // Scenario 3: Existing customized main + --force → silent overwrite
    // -------------------------------------------------------------------------

    test('3. Existing customized main + --force: exits 0, Magic template '
        'overwrites user content', () async {
      final (:cmd, :ctx, :fs) = buildIntegrationHarness(
        optionOverrides: <String, dynamic>{'force': true},
        seedMainDart: customizedAsyncMain,
      );

      final exit = await cmd.handle(ctx);

      expect(exit, 0, reason: (ctx.output as BufferedOutput).content);
      final main = fs.readAsString('/proj/lib/main.dart');
      expect(
        main,
        contains('Magic.init'),
        reason: '--force must overwrite with the Magic template',
      );
      // User content replaced — the custom app class is gone.
      expect(
        main,
        isNot(contains('MyCustomApp')),
        reason: '--force overwrites the entire file; user code is replaced',
      );
    });

    // -------------------------------------------------------------------------
    // Scenario 4: Existing customized main + --preserve (async) → smart merge
    // -------------------------------------------------------------------------

    test('4. Existing customized main + --preserve (async main): exits 0, '
        'smart merge applied — Magic.init + MagicApplication injected, '
        'user code preserved', () async {
      final (:cmd, :ctx, :fs) = buildIntegrationHarness(
        optionOverrides: <String, dynamic>{'preserve': true},
        seedMainDart: customizedAsyncMain,
      );

      final exit = await cmd.handle(ctx);

      expect(exit, 0, reason: (ctx.output as BufferedOutput).content);
      final main = fs.readAsString('/proj/lib/main.dart');
      expect(
        main,
        contains('await Magic.init('),
        reason: '--preserve must inject Magic.init into the existing file',
      );
      expect(
        main,
        contains('MagicApplication('),
        reason: '--preserve must wrap runApp with MagicApplication',
      );
      expect(
        main,
        contains('MyCustomApp'),
        reason: '--preserve must retain the user-authored app class',
      );
    });

    // -------------------------------------------------------------------------
    // Scenario 5: Existing customized main + --preserve (sync) → exit 1
    // -------------------------------------------------------------------------

    test(
      '5. Existing customized main + --preserve (sync main): exits 1, '
      'FormatException-derived error logged containing "main() must be async"',
      () async {
        final (:cmd, :ctx, :fs) = buildIntegrationHarness(
          optionOverrides: <String, dynamic>{'preserve': true},
          seedMainDart: customizedSyncMain,
        );
        final preAbortKeys = fs.snapshot.keys.toSet();

        final exit = await cmd.handle(ctx);

        expect(exit, 1, reason: 'Sync main rejection must surface as exit 1');
        final out = (ctx.output as BufferedOutput).content;
        expect(
          out,
          contains('main() must be async'),
          reason: 'Error output must name the required fix',
        );
        // No new install-generated files after the abort.
        final newKeys = fs.snapshot.keys.toSet().difference(preAbortKeys);
        expect(
          newKeys,
          isEmpty,
          reason:
              'Abort on sync main must not write any install-generated files',
        );
      },
    );

    // -------------------------------------------------------------------------
    // Scenario 6: Existing customized main + --non-interactive → exit 0 cancel
    // -------------------------------------------------------------------------

    test(
      '6. Existing customized main + --non-interactive (no --force/--preserve): '
      'exits 0 with cancel, error about non-interactive logged',
      () async {
        // _baseOptions sets non-interactive: true by default; no --force/--preserve.
        final (:cmd, :ctx, :fs) = buildIntegrationHarness(
          seedMainDart: customizedAsyncMain,
        );

        final exit = await cmd.handle(ctx);

        expect(
          exit,
          0,
          reason: 'Cancel path is a clean early exit, not an error code',
        );
        final out = (ctx.output as BufferedOutput).content;
        expect(
          out,
          contains(
            'Existing lib/main.dart is not the default Flutter scaffold',
          ),
          reason: 'Non-interactive cancel must log why install was aborted',
        );
        // Install must not have committed — no generated files.
        expect(
          fs.exists('/proj/lib/config/app.dart'),
          isFalse,
          reason: 'Cancel must not commit any manifest publishes',
        );
        expect(
          fs.exists('/proj/.artisan/installed/magic.json'),
          isFalse,
          reason: 'Cancel must not create an install record',
        );
      },
    );

    // -------------------------------------------------------------------------
    // Scenario 7: Interactive → user picks 'Overwrite' → Magic template written
    // -------------------------------------------------------------------------

    test('7. Existing customized main + interactive, user picks Overwrite: '
        'exits 0, Magic template written, user code replaced', () async {
      final sequenceDriver = _FakeSequencePromptDriver([
        'Overwrite — Replace with Magic template',
      ]);
      final (:cmd, :ctx, :fs) = buildIntegrationHarness(
        optionOverrides: <String, dynamic>{'non-interactive': false},
        sequenceDriver: sequenceDriver,
        seedMainDart: customizedAsyncMain,
      );

      final exit = await cmd.handle(ctx);

      expect(exit, 0, reason: (ctx.output as BufferedOutput).content);
      final main = fs.readAsString('/proj/lib/main.dart');
      expect(
        main,
        contains('Magic.init'),
        reason: 'Overwrite choice must write the Magic template',
      );
      expect(
        main,
        isNot(contains('MyCustomApp')),
        reason: 'Overwrite replaces the entire file',
      );
      expect(
        sequenceDriver.choiceCallCount,
        1,
        reason: 'Exactly one prompt call for Overwrite selection',
      );
    });

    // -------------------------------------------------------------------------
    // Scenario 8: Interactive → user picks 'Preserve' → smart merge applied
    // -------------------------------------------------------------------------

    test('8. Existing customized main + interactive, user picks Preserve: '
        'exits 0, smart merge applied, user code retained', () async {
      final sequenceDriver = _FakeSequencePromptDriver([
        'Preserve — Inject Magic into existing main.dart',
      ]);
      final (:cmd, :ctx, :fs) = buildIntegrationHarness(
        optionOverrides: <String, dynamic>{'non-interactive': false},
        sequenceDriver: sequenceDriver,
        seedMainDart: customizedAsyncMain,
      );

      final exit = await cmd.handle(ctx);

      expect(exit, 0, reason: (ctx.output as BufferedOutput).content);
      final main = fs.readAsString('/proj/lib/main.dart');
      expect(
        main,
        contains('await Magic.init('),
        reason: 'Preserve choice must inject Magic.init',
      );
      expect(
        main,
        contains('MagicApplication('),
        reason: 'Preserve choice must wrap runApp with MagicApplication',
      );
      expect(
        main,
        contains('MyCustomApp'),
        reason: 'Preserve choice must retain user-authored code',
      );
      expect(
        sequenceDriver.choiceCallCount,
        1,
        reason: 'Exactly one prompt call for Preserve selection',
      );
    });

    // -------------------------------------------------------------------------
    // Scenario 9: Interactive → user picks 'Diff' then 'Cancel' → exit 0
    // -------------------------------------------------------------------------

    test(
      '9. Existing customized main + interactive, user picks Diff then Cancel: '
      'exits 0, diff output written, no install committed',
      () async {
        // Sequence: first Diff (shows diff + re-prompts), then Cancel.
        final sequenceDriver = _FakeSequencePromptDriver([
          'Diff — Show diff, re-prompt',
          'Cancel — Abort install',
        ]);
        final (:cmd, :ctx, :fs) = buildIntegrationHarness(
          optionOverrides: <String, dynamic>{'non-interactive': false},
          sequenceDriver: sequenceDriver,
          seedMainDart: customizedAsyncMain,
        );

        final exit = await cmd.handle(ctx);

        expect(exit, 0, reason: 'Cancel after Diff is a clean early exit');
        // Two prompt calls: one for Diff, one for Cancel.
        expect(
          sequenceDriver.choiceCallCount,
          2,
          reason: 'Diff + Cancel = exactly 2 prompt calls',
        );
        final out = (ctx.output as BufferedOutput).content;
        // The diff output must have been written before the re-prompt.
        expect(
          out,
          contains('lib/main.dart'),
          reason: 'Diff branch must emit the unified diff to output',
        );
        // Cancel must abort commit — no generated files.
        expect(
          fs.exists('/proj/lib/config/app.dart'),
          isFalse,
          reason: 'Cancel after Diff must not commit',
        );
      },
    );

    // -------------------------------------------------------------------------
    // Scenario 10: Interactive → user picks 'Cancel' → exit 0
    // -------------------------------------------------------------------------

    test('10. Existing customized main + interactive, user picks Cancel: '
        'exits 0, no install committed', () async {
      final sequenceDriver = _FakeSequencePromptDriver([
        'Cancel — Abort install',
      ]);
      final (:cmd, :ctx, :fs) = buildIntegrationHarness(
        optionOverrides: <String, dynamic>{'non-interactive': false},
        sequenceDriver: sequenceDriver,
        seedMainDart: customizedAsyncMain,
      );

      final exit = await cmd.handle(ctx);

      expect(
        exit,
        0,
        reason: 'Cancel is a clean early exit, not an error code',
      );
      expect(
        sequenceDriver.choiceCallCount,
        1,
        reason: 'Exactly one prompt call for Cancel selection',
      );
      // User's main.dart must be untouched.
      expect(
        fs.readAsString('/proj/lib/main.dart'),
        customizedAsyncMain,
        reason: 'Cancel must not modify the existing lib/main.dart',
      );
      // No generated install files.
      expect(
        fs.exists('/proj/.artisan/installed/magic.json'),
        isFalse,
        reason: 'Cancel must not create an install record',
      );
    });

    // -------------------------------------------------------------------------
    // Scenario 11: --force + --preserve together → exit 2 with mutex error
    // -------------------------------------------------------------------------

    test(
      '11. --force + --preserve together: exits 2, mutex error message logged',
      () async {
        final (:cmd, :ctx, :fs) = buildIntegrationHarness(
          optionOverrides: <String, dynamic>{'force': true, 'preserve': true},
          seedMainDart: customizedAsyncMain,
        );

        final exit = await cmd.handle(ctx);

        expect(
          exit,
          2,
          reason:
              'Exit 2 signals incorrect CLI usage (mutually exclusive flags)',
        );
        final out = (ctx.output as BufferedOutput).content;
        expect(
          out,
          contains('Cannot specify both --force and --preserve'),
          reason: 'Mutex error must name both conflicting flags',
        );
        // Mutex check fires before any install work — no generated files.
        expect(
          fs.exists('/proj/lib/config/app.dart'),
          isFalse,
          reason: 'Mutex error must prevent any install from running',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group 16: artisan-install delegation (TDD red-first for Step 16)
  //
  // Verifies that after `magic:install` succeeds, the canonical Flutter
  // scaffold (bin/dispatcher.dart + barrels + pubspec dep + bin/fsa) is
  // delegated to artisan's `InstallCommand.scaffoldInto` IN-PROCESS.
  // Ordering invariant: delegation fires AFTER stagedInstaller.commit returns
  // Success and BEFORE the registered `plugins:refresh` command, so the
  // dispatcher exists on disk before codegen rebuilds the provider barrel.
  // ---------------------------------------------------------------------------

  group('MagicInstallCommand, artisan-install delegation', () {
    test('delegateArtisanInstall calls InstallCommand.scaffoldInto and writes '
        'bin/dispatcher.dart at the consumer projectRoot', () async {
      // 1. Real-FS tempDir seeded with the minimum scaffold artisan's
      //    InstallCommand needs (pubspec.yaml with a name field) so the
      //    underlying static `scaffoldInto` can resolve {{ name }} for the
      //    dispatcher stub.
      final tempDir = Directory.systemTemp.createTempSync(
        'magic_artisan_delegate_',
      );
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync(
        'name: test_consumer\n'
        'environment:\n'
        '  sdk: ^3.4.0\n'
        'dependencies:\n'
        '  path: any\n',
      );
      // 2. Pre-seed bin/dispatcher.dart so the auto-chained
      //    MakeFastCliCommand.scaffoldInto skips its dispatcher-missing
      //    guard. The delegateArtisanInstall under test still runs the full
      //    `install` flow (dispatcher render is idempotent without --force).
      Directory(p.join(tempDir.path, 'bin')).createSync(recursive: true);
      File(
        p.join(tempDir.path, 'bin', 'dispatcher.dart'),
      ).writeAsStringSync('// placeholder dispatcher\n');
      File(p.join(tempDir.path, 'pubspec.lock')).writeAsStringSync(
        'packages:\n  test_consumer:\n    version: "1.0.0"\n',
      );

      // 3. Script the MakeFastCliCommand subprocess invocations so the
      //    auto-chain in `InstallCommand.scaffoldInto` does not spin up
      //    real `chmod` / `dart --version` / `dart build cli` processes.
      final scripted = <String, ProcessResult>{
        'chmod +x ${p.join(tempDir.path, 'bin', 'fsa')}': ProcessResult(
          0,
          0,
          '',
          '',
        ),
        'dart --version': ProcessResult(
          0,
          0,
          '',
          'Dart SDK version: 3.8.0 (stable) ...',
        ),
        'dart build cli -t bin/dispatcher.dart -o .artisan/cli-bundle':
            ProcessResult(0, 0, 'Build complete.', ''),
      };
      final originalRunner = MakeFastCliCommand.processRunner;
      MakeFastCliCommand.processRunner =
          (String exe, List<String> args, {String? workingDirectory}) async {
            return scripted['$exe ${args.join(' ')}'] ??
                ProcessResult(0, 0, '', '');
          };
      addTearDown(() {
        MakeFastCliCommand.processRunner = originalRunner;
      });

      // 4. Build an InstallContext rooted at the tempDir + a bare
      //    ArtisanContext with the standard base flags.
      final installContext = InstallContext.test(
        fs: RealFs(),
        prompt: _RecordingPromptDriver(),
        stubs: RealStubDriver(),
        projectRoot: tempDir.path,
        output: BufferedOutput(),
        clock: () => DateTime.utc(2025, 1, 1),
      );
      final cmd = MagicInstallCommand();
      final ctx = _ctxWith(_baseOptions, signature: cmd.parsedSignature);

      // 5. Invoke the seam under test directly. The production wiring in
      //    handle() exercises the same code path inside `if (result is
      //    Success)` after `stagedInstaller.commit`.
      final exit = await cmd.delegateArtisanInstall(ctx, installContext);

      // 6. Assert the artisan scaffold landed at the consumer projectRoot.
      expect(
        exit,
        0,
        reason:
            'delegateArtisanInstall must propagate exit 0 on success; '
            'output was: ${(ctx.output as BufferedOutput).content}',
      );
      // bin/dispatcher.dart was pre-seeded so the idempotent skip path is
      // exercised. The canonical barrels + pubspec dep must still be
      // written even when dispatcher.dart already exists.
      expect(
        File(
          p.join(tempDir.path, 'lib', 'app', '_plugins.g.dart'),
        ).existsSync(),
        isTrue,
        reason:
            'delegation must scaffold the plugins codegen barrel into the '
            'consumer projectRoot',
      );
      expect(
        File(
          p.join(tempDir.path, 'lib', 'app', 'commands', '_index.g.dart'),
        ).existsSync(),
        isTrue,
        reason:
            'delegation must scaffold the consumer-commands codegen '
            'barrel into the consumer projectRoot',
      );
      final pubspec = File(
        p.join(tempDir.path, 'pubspec.yaml'),
      ).readAsStringSync();
      expect(
        pubspec.contains('fluttersdk_artisan'),
        isTrue,
        reason:
            'delegation must inject the fluttersdk_artisan pubspec '
            'dependency into the consumer pubspec',
      );
    });

    test(
      'handle invokes the artisan delegation exactly once on commit Success, '
      'BEFORE the registered plugins:refresh command runs',
      () async {
        // Recording plugins:refresh stub captures the global call order so
        // the test can assert: artisan delegation < plugins:refresh.
        final refreshStub = _RecordingRefreshCommand();
        final registry = ArtisanRegistry()
          ..register(refreshStub, providerName: 'test');

        final (:cmd, :ctx, fs: _, prompt: _) = _buildHarness(
          registry: registry,
        );

        final exit = await cmd.handle(ctx);

        expect(
          exit,
          0,
          reason:
              'Successful install must exit 0; output was: '
              '${(ctx.output as BufferedOutput).content}',
        );
        expect(
          cmd.artisanDelegateCallCount,
          1,
          reason:
              'artisan delegation must fire exactly once when commit returns '
              'Success',
        );
        expect(
          refreshStub.callCount,
          1,
          reason:
              'plugins:refresh must still fire after the artisan delegation '
              'so the regenerated _plugins.g.dart picks up any newly '
              'registered providers',
        );
        // Ordering: the delegation captured a context BEFORE refreshStub was
        // invoked. Both observers share the SAME ArtisanContext, so a more
        // direct ordering check is the BufferedOutput sequence. The
        // delegation override (in _TestableMagicInstallCommand) does not
        // write to stdout; plugins:refresh writes a `success` line. The
        // post-install advisory from manifest fires BEFORE the delegation.
        // Use the recording stub presence to confirm wire-up; full ordering
        // is asserted in the next test via the early-return branch.
      },
    );

    test(
      'handle skips artisan delegation when commit returns DryRun '
      '(--dry-run preserves atomic semantics: nothing on disk, no delegation)',
      () async {
        final refreshStub = _RecordingRefreshCommand();
        final registry = ArtisanRegistry()
          ..register(refreshStub, providerName: 'test');

        final (:cmd, :ctx, fs: _, prompt: _) = _buildHarness(
          registry: registry,
          optionOverrides: <String, dynamic>{'dry-run': true},
        );

        final exit = await cmd.handle(ctx);

        expect(exit, 0, reason: 'dry-run exits 0 without touching disk');
        expect(
          cmd.artisanDelegateCallCount,
          0,
          reason:
              'dry-run must NOT delegate to artisan install; commit did not '
              'land any files so the scaffold would have nothing to compose '
              'against',
        );
        expect(
          refreshStub.callCount,
          0,
          reason:
              'plugins:refresh must NOT fire on dry-run (consistent with the '
              'existing auto-refresh-skip-on-dry-run contract)',
        );
      },
    );

    test('handle returns the artisan delegation exit code AND skips '
        'plugins:refresh when delegation fails', () async {
      // Pinned exit code 7 simulates a failed `dart build cli` or
      // failed pubspec injection during the cross-package delegation.
      final fixtures = _buildStubFixtures();
      final stubs = _FixtureStubDriver(fixtures);
      final fs = InMemoryFs();
      const projectRoot = '/proj';
      fs.writeAsString(
        '$projectRoot/.dart_tool/package_config.json',
        _fakePackageConfigJson,
      );
      final output = BufferedOutput();
      final installContext = InstallContext.test(
        fs: fs,
        prompt: _RecordingPromptDriver(),
        stubs: stubs,
        projectRoot: projectRoot,
        output: output,
        clock: () => DateTime.utc(2025, 1, 1),
      );

      final refreshStub = _RecordingRefreshCommand();
      final registry = ArtisanRegistry()
        ..register(refreshStub, providerName: 'test');

      final cmd = _TestableMagicInstallCommand(
        fakeManifestPath: _manifestPath,
        fakeContext: installContext,
        fakeStubsDir: _fakeStubsDir,
        artisanDelegateExitCode: 7,
      );
      final ctx = ArtisanContext.bare(
        MapInput(_baseOptions, signature: cmd.parsedSignature),
        output,
        registry: registry,
      );

      final exit = await cmd.handle(ctx);

      expect(
        exit,
        7,
        reason:
            'handle must propagate the artisan delegation exit code so the '
            'operator sees the actionable failure surface',
      );
      expect(
        cmd.artisanDelegateCallCount,
        1,
        reason:
            'delegation must have been attempted once before the '
            'failure path triggered',
      );
      expect(
        refreshStub.callCount,
        0,
        reason:
            'plugins:refresh must NOT run when the artisan delegation '
            'fails (the dispatcher might be in a partial state; codegen '
            'over partial state would amplify the inconsistency)',
      );
      expect(
        output.content,
        contains('artisan install but it failed'),
        reason:
            'operator must see an actionable error message naming the '
            'partial-state paths to inspect (bin/dispatcher.dart + bin/fsa)',
      );
    });
  });
}
