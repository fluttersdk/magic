import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:meta/meta.dart' show visibleForTesting;
import 'package:fluttersdk_artisan/artisan.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../install_stubs.dart';

/// `magic:install`, installs the Magic Framework via the bundled install.yaml
/// manifest layered with a fluent override for the conditional 40% the v1
/// manifest schema cannot express.
///
/// ## Layered architecture
///
/// 1. `install.yaml` at `<magic_root>/install.yaml` declares the
///    always-rendered 60% (10 static config + starter + .env publishes,
///    8 `--without-*` bool prompts, the `appName` placeholder slot, the
///    post_install message, and the bootstrap_command).
/// 2. [resolveManifestPath] locates that file via [Isolate.resolvePackageUri]
///    starting from `package:magic/magic.dart`.
/// 3. [handle] parses the manifest, computes prompt overrides from the
///    `--without-X` CLI flags, extracts `appName` from the consumer's
///    pubspec.yaml.name (snake_case -> Title Case), and constructs a
///    [ManifestInstaller] seeded with those overrides plus the appName
///    placeholder.
/// 4. [ManifestInstaller.prepare] returns a staged [PluginInstaller] with the
///    10 always-on publishes queued. The fluent override layer
///    ([_applyFluentOverride]) then:
///       - emits the 6 CONDITIONAL config publishes via
///         `installer.publishConfig` (auth / database / network / cache /
///         logging / broadcasting) ONLY when the matching `--without-X`
///         answer is `false`.
///       - OVERWRITES the manifest-published `lib/config/app.dart` with the
///         dynamic provider list assembled from the same flag set via
///         `installer.writeFile`. The write runs after the manifest publish
///         in commit order, so the dynamic content wins.
///       - WRITES `lib/main.dart` (NOT in publish:) with the dynamic
///         configFactories + configImports lists.
/// 5. [PluginInstaller.commit] dispatches the now-conditional op list.
/// 6. On [Success], the post_install message is echoed to the operator.
/// 7. [_renderResult] translates the sealed [TransactionResult] into the
///    process exit code.
///
/// ## Test seam
///
/// [resolveManifestPath], [resolveMagicStubsDir], [buildContext], and
/// [snakeCaseToTitleCase] carry `@visibleForTesting` annotations so a test
/// subclass can inject:
///   - a pinned manifest path (no `Isolate.resolvePackageUri` round-trip)
///   - a pinned stubs directory (the real `references/magic/assets/stubs/`)
///   - an in-memory [InstallContext.test] backed by [InMemoryFs] /
///     [FakePromptDriver] / [FakeStubDriver]
///
/// ## Why Option B (conditional emit) over Option A (conditional remove)
///
/// The plan considered two ways to handle the 6 conditional configs:
///
///   - Option A: list ALL 16 publishes in the manifest, then add a
///     `removeOpsTargeting` helper on [PluginInstaller] and have the fluent
///     override call it for each `--without-X = true`.
///   - Option B (chosen): list only the 10 always-on publishes in the
///     manifest; have the fluent override emit the 6 conditional publishes
///     via direct `publishConfig` calls when their flag is `false`.
///
/// Option B keeps the manifest a clean static spec, requires no
/// fluttersdk_artisan additions, and makes the conditional ownership
/// boundary explicit (install.yaml owns the always-on layer, the override
/// owns the conditional layer).
///
/// ## Usage
///
/// ```bash
/// dart run :artisan magic:install
/// dart run :artisan magic:install --without-auth --without-broadcasting
/// dart run :artisan magic:install --force --non-interactive
/// ```
class MagicInstallCommand extends ArtisanInstallCommand {
  /// Public default constructor. Test fixtures subclass + override the four
  /// `@visibleForTesting` hooks.
  MagicInstallCommand();

  @override
  String get signature =>
      'magic:install '
      '$baseFlags'
      '{--without-auth : Skip auth setup} '
      '{--without-database : Skip database setup} '
      '{--without-network : Skip network setup} '
      '{--without-cache : Skip cache setup} '
      '{--without-events : Skip events setup} '
      '{--without-localization : Skip localization setup} '
      '{--without-logging : Skip logging setup} '
      '{--without-broadcasting : Skip broadcasting setup}';

  @override
  String get description =>
      'Install Magic framework via the bundled install.yaml manifest.';

  @override
  String pluginName(ArtisanContext ctx) => 'magic';

  /// Ordered list of the 8 `--without-X` CLI flag names.
  ///
  /// Used by [_buildPromptOverrides] when converting CLI options into the
  /// camelCase prompt-key map the manifest expects, and by [_flagsFromCtx]
  /// when re-deriving the same map for the fluent override layer.
  static const List<String> _withoutFlagNames = <String>[
    'without-auth',
    'without-database',
    'without-network',
    'without-cache',
    'without-events',
    'without-localization',
    'without-logging',
    'without-broadcasting',
  ];

  /// Resolves the absolute filesystem path of magic's `install.yaml`.
  ///
  /// Production path: resolves `package:magic/magic.dart` via
  /// [Isolate.resolvePackageUri], walks two directories up to the plugin root,
  /// and returns `<plugin_root>/install.yaml` when present.
  ///
  /// Returns `null` when the manifest cannot be located so [handle] can
  /// surface a clean error instead of throwing.
  ///
  /// @return The absolute manifest path, or `null` when no manifest is found.
  @visibleForTesting
  Future<String?> resolveManifestPath() async {
    final resolved = await Isolate.resolvePackageUri(
      Uri.parse('package:magic/magic.dart'),
    );
    if (resolved == null || resolved.scheme != 'file') return null;

    // resolved -> <plugin_root>/lib/magic.dart, two dirname() calls back out.
    final libBarrel = resolved.toFilePath();
    final pluginRoot = p.dirname(p.dirname(libBarrel));
    final manifestPath = p.join(pluginRoot, 'install.yaml');
    return File(manifestPath).existsSync() ? manifestPath : null;
  }

  /// Resolves magic's `assets/stubs/` directory inside the consumer's
  /// `.dart_tool/package_config.json`.
  ///
  /// The default [StubLoader] search paths resolve to fluttersdk_artisan's
  /// own `assets/stubs/`, NOT magic's. The 6 conditional `publishConfig`
  /// calls emitted by the fluent override layer must therefore pass an
  /// explicit `searchPaths` pointing at magic's stub bundle.
  ///
  /// Returns `null` when the package_config.json is missing or the magic
  /// entry is absent; callers fall back to letting the dispatcher try the
  /// default paths (which will fail with a clear `FileSystemException`).
  ///
  /// @param installContext  The active [InstallContext] (used for FS access
  ///                        + projectRoot resolution).
  /// @return Absolute path to `<magic_root>/assets/stubs/`, or `null`.
  @visibleForTesting
  String? resolveMagicStubsDir(InstallContext installContext) {
    final pkgConfigPath = p.join(
      installContext.projectRoot,
      '.dart_tool',
      'package_config.json',
    );
    if (!installContext.fs.exists(pkgConfigPath)) return null;

    final content = installContext.fs.readAsString(pkgConfigPath);
    final json = jsonDecode(content) as Map<String, dynamic>;
    final packages = json['packages'] as List<dynamic>?;
    if (packages == null) return null;

    for (final pkg in packages) {
      final entry = pkg as Map<String, dynamic>;
      if (entry['name'] != 'magic') continue;
      final rootUri = entry['rootUri'] as String;
      final pkgRoot = rootUri.startsWith('file://')
          ? Uri.parse(rootUri).toFilePath()
          : p.normalize(
              p.join(installContext.projectRoot, '.dart_tool', rootUri),
            );
      return p.join(pkgRoot, 'assets', 'stubs');
    }
    return null;
  }

  @override
  Future<int> handle(ArtisanContext ctx) async {
    // 1. Resolve + parse the manifest. A null result means the asset bundle
    //    is missing or the package was loaded from an unexpected location.
    final manifestPath = await resolveManifestPath();
    if (manifestPath == null) {
      ctx.output.error(
        'magic install.yaml could not be resolved. The plugin asset bundle '
        'is missing or the package was loaded from an unexpected location.',
      );
      return 1;
    }

    final InstallManifest manifest;
    try {
      manifest = ManifestParser.parseFile(manifestPath);
    } on FormatException catch (e) {
      ctx.output.error('install.yaml at $manifestPath: $e');
      return 1;
    } on ManifestValidationException catch (e) {
      ctx.output.error('install.yaml at $manifestPath: ${e.message}');
      return 1;
    }

    // 2. Build prompt overrides from the --without-X CLI flags. CLI keys are
    //    kebab-case; manifest prompt keys are camelCase.
    final flags = _flagsFromCtx(ctx);
    final overrides = _buildPromptOverrides(flags);

    // 3. Build the install context + extract appName from pubspec.yaml.
    //    Test subclasses override [buildContext] to inject InMemoryFs.
    final installContext = buildContext(ctx);
    final appName = _extractAppName(installContext);

    // 4. Pre-populate the appName placeholder BEFORE the manifest installer
    //    runs (placeholders are resolved during prepare()).
    overrides['appName'] = appName;

    // 5. Construct the manifest installer + stage the always-on 10 publishes.
    final installer = ManifestInstaller(
      installContext,
      manifest,
      promptOverrides: overrides,
    );
    final stagedInstaller = installer.prepare(
      nonInteractive: isNonInteractive(ctx),
    );

    // 6. Layer the conditional 40% on top: 6 conditional config publishes +
    //    dynamic lib/config/app.dart overwrite + dynamic lib/main.dart write.
    _applyFluentOverride(
      stagedInstaller,
      installContext: installContext,
      flags: flags,
      appName: appName,
    );

    // 7. Commit the now-conditional op list.
    final result = await stagedInstaller.commit(
      dryRun: isDryRun(ctx),
      force: isForce(ctx),
    );

    // 8. Echo post_install.message on Success.
    if (result is Success && manifest.postInstall.message != null) {
      ctx.output.info(manifest.postInstall.message!);
    }

    return _renderResult(ctx, result);
  }

  /// Reads the 8 `--without-X` CLI flag values from [ctx] into a camelCase
  /// flag map.
  ///
  /// Defaults to `false` for absent or non-bool option values. The same
  /// camelCase shape is consumed by [_buildPromptOverrides] (which converts
  /// to the manifest prompt-key map) and by [_applyFluentOverride] (which
  /// branches conditional emission on each flag directly).
  ///
  /// @param ctx  The active [ArtisanContext].
  /// @return Map of `withoutX` flag name to its bool answer.
  Map<String, bool> _flagsFromCtx(ArtisanContext ctx) {
    final flags = <String, bool>{};
    for (final flag in _withoutFlagNames) {
      final value = ctx.input.option(flag);
      flags[_kebabToCamel(flag)] = value is bool ? value : false;
    }
    return flags;
  }

  /// Converts the flag map into the prompt-override map consumed by
  /// [ManifestInstaller]. Booleans are encoded as the strings `'true'` /
  /// `'false'` so the placeholder substitution layer can treat every answer
  /// as a String.
  ///
  /// @param flags  Map of `withoutX` flag name to its bool answer.
  /// @return Manifest prompt-key map ready for [ManifestInstaller].
  Map<String, String> _buildPromptOverrides(Map<String, bool> flags) {
    return <String, String>{
      for (final entry in flags.entries)
        entry.key: entry.value ? 'true' : 'false',
    };
  }

  /// Kebab-case to camelCase: `without-auth` -> `withoutAuth`.
  String _kebabToCamel(String kebab) {
    final parts = kebab.split('-');
    return parts.first +
        parts
            .skip(1)
            .map(
              (part) =>
                  part.isEmpty ? '' : part[0].toUpperCase() + part.substring(1),
            )
            .join();
  }

  /// Reads the consumer's `pubspec.yaml.name` and transforms snake_case to
  /// Title Case (`my_cool_app` -> `My Cool App`).
  ///
  /// Returns the empty string when pubspec.yaml is missing, unreadable, or
  /// lacks a `name:` field. The empty placeholder still satisfies the
  /// manifest's placeholder validation; downstream stubs that interpolate
  /// `{{ appName }}` render with an empty substitution which the operator
  /// can fill in by hand.
  String _extractAppName(InstallContext installContext) {
    final pubspecPath = p.join(installContext.projectRoot, 'pubspec.yaml');
    if (!installContext.fs.exists(pubspecPath)) return '';
    final content = installContext.fs.readAsString(pubspecPath);
    final YamlMap? yaml;
    try {
      final parsed = loadYaml(content);
      yaml = parsed is YamlMap ? parsed : null;
    } on YamlException {
      return '';
    }
    if (yaml == null) return '';
    final name = yaml['name'];
    if (name is! String || name.isEmpty) return '';
    return snakeCaseToTitleCase(name);
  }

  /// Title-cases a snake_case identifier.
  ///
  /// Exposed `@visibleForTesting` so the snake_case-to-Title-Case edge cases
  /// (camelCase preservation, empty input, single segment) are covered by
  /// unit tests without round-tripping through the full install pipeline.
  ///
  /// @param snake  Identifier in snake_case (or single-word camelCase).
  /// @return Space-separated Title Case rendering of [snake].
  @visibleForTesting
  String snakeCaseToTitleCase(String snake) {
    return snake
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  /// Conditional layer: emits the 6 `--without-X`-gated config publishes,
  /// then overwrites `lib/config/app.dart` and writes `lib/main.dart` with
  /// the dynamic provider + configFactories lists.
  ///
  /// Op-order note: the manifest publishes (including the static
  /// `lib/config/app.dart`) are already queued on [installer] by the
  /// preceding [ManifestInstaller.prepare] call. The conditional publishes
  /// added here append to that queue; the dynamic `writeFile` for
  /// `lib/config/app.dart` runs AFTER the manifest publish in commit order,
  /// so the dynamic content wins.
  void _applyFluentOverride(
    PluginInstaller installer, {
    required InstallContext installContext,
    required Map<String, bool> flags,
    required String appName,
  }) {
    final projectRoot = installContext.projectRoot;
    final magicStubsDir = resolveMagicStubsDir(installContext);
    final searchPaths = magicStubsDir == null ? null : <String>[magicStubsDir];

    // Conditional config publishes: one per --without-X flag that is false.
    const flagToStub = <String, _ConditionalConfig>{
      'withoutAuth': _ConditionalConfig(
        stubName: 'install/auth_config',
        target: 'lib/config/auth.dart',
      ),
      'withoutDatabase': _ConditionalConfig(
        stubName: 'install/database_config',
        target: 'lib/config/database.dart',
      ),
      'withoutNetwork': _ConditionalConfig(
        stubName: 'install/network_config',
        target: 'lib/config/network.dart',
      ),
      'withoutCache': _ConditionalConfig(
        stubName: 'install/cache_config',
        target: 'lib/config/cache.dart',
      ),
      'withoutLogging': _ConditionalConfig(
        stubName: 'install/logging_config',
        target: 'lib/config/logging.dart',
      ),
      'withoutBroadcasting': _ConditionalConfig(
        stubName: 'install/broadcasting_config',
        target: 'lib/config/broadcasting.dart',
      ),
    };

    flagToStub.forEach((flagKey, config) {
      if (flags[flagKey] == true) return;
      // Render via plugin-rooted stubs dir + writeFile, mirroring
      // ManifestInstaller._applyPublish (the dispatcher's default stub
      // search paths resolve to fluttersdk_artisan/assets/stubs/, not
      // magic's).
      final stub = installContext.stubs.load(
        config.stubName,
        searchPaths: searchPaths,
      );
      installer.writeFile(
        targetPath: p.join(projectRoot, config.target),
        content: stub,
      );
    });

    // Dynamic lib/config/app.dart: overwrites the manifest-published version
    // with the runtime-assembled providers list.
    installer.writeFile(
      targetPath: p.join(projectRoot, 'lib/config/app.dart'),
      content: InstallStubs.appConfigContent(
        providerImports: const <String>[],
        providerEntries: _buildProviderEntries(flags),
        authProviderEntries: flags['withoutAuth']!
            ? const <String>[]
            : const <String>['(app) => AuthServiceProvider(app),'],
      ),
    );

    // Dynamic lib/main.dart: not in publish: at all; the configFactories
    // list cannot be expressed as a static template.
    installer.writeFile(
      targetPath: p.join(projectRoot, 'lib/main.dart'),
      content: InstallStubs.mainDartContent(
        appName: appName,
        configImports: _buildConfigImports(flags),
        configFactories: _buildConfigFactories(flags),
      ),
    );
  }

  /// Assembles the provider list rendered into `lib/config/app.dart`.
  ///
  /// Order matters here: `RouteServiceProvider` always wraps the chain, then
  /// infrastructure providers (cache / database / launch / localization /
  /// network / vault / broadcasting), then `AppServiceProvider`, then the
  /// auth provider chain. The matching anchor strings are owned by
  /// [InstallStubs.appConfigContent]; this method only supplies the
  /// infrastructure layer.
  List<String> _buildProviderEntries(Map<String, bool> flags) {
    final entries = <String>[];
    if (!flags['withoutCache']!) {
      entries.add('(app) => CacheServiceProvider(app),');
    }
    if (!flags['withoutDatabase']!) {
      entries.add('(app) => DatabaseServiceProvider(app),');
    }
    // Launch is always registered, the welcome view uses Launch.url().
    entries.add('(app) => LaunchServiceProvider(app),');
    if (!flags['withoutLocalization']!) {
      entries.add('(app) => LocalizationServiceProvider(app),');
    }
    if (!flags['withoutNetwork']!) {
      entries.add('(app) => NetworkServiceProvider(app),');
    }
    if (!flags['withoutAuth']!) {
      entries.add('(app) => VaultServiceProvider(app),');
    }
    if (!flags['withoutBroadcasting']!) {
      entries.add('(app) => BroadcastServiceProvider(app),');
    }
    return entries;
  }

  /// Assembles the `import 'config/X.dart';` lines rendered into
  /// `lib/main.dart`.
  List<String> _buildConfigImports(Map<String, bool> flags) {
    final imports = <String>[
      "import 'config/app.dart';",
      "import 'config/routing.dart';",
      "import 'config/view.dart';",
    ];
    if (!flags['withoutAuth']!) imports.add("import 'config/auth.dart';");
    if (!flags['withoutDatabase']!) {
      imports.add("import 'config/database.dart';");
    }
    if (!flags['withoutNetwork']!) {
      imports.add("import 'config/network.dart';");
    }
    if (!flags['withoutCache']!) imports.add("import 'config/cache.dart';");
    if (!flags['withoutLogging']!) {
      imports.add("import 'config/logging.dart';");
    }
    if (!flags['withoutBroadcasting']!) {
      imports.add("import 'config/broadcasting.dart';");
    }
    return imports;
  }

  /// Assembles the `() => XConfig` factory list rendered into `lib/main.dart`.
  List<String> _buildConfigFactories(Map<String, bool> flags) {
    final factories = <String>[
      '() => appConfig',
      '() => routingConfig',
      '() => viewConfig',
    ];
    if (!flags['withoutAuth']!) factories.add('() => authConfig');
    if (!flags['withoutDatabase']!) factories.add('() => databaseConfig');
    if (!flags['withoutNetwork']!) factories.add('() => networkConfig');
    if (!flags['withoutCache']!) factories.add('() => cacheConfig');
    if (!flags['withoutLogging']!) factories.add('() => loggingConfig');
    if (!flags['withoutBroadcasting']!) {
      factories.add('() => broadcastingConfig');
    }
    return factories;
  }

  /// Translates a [TransactionResult] into a process exit code while writing
  /// the matching summary line through [ArtisanOutput].
  ///
  /// Exit map:
  ///   - [Success] -> 0 (record path echoed via success())
  ///   - [DryRun]  -> 0 (no disk side effect)
  ///   - [Conflict] -> 1 (operator must rerun with --force)
  ///   - [Error]    -> 2 (distinct from Conflict so CI can branch)
  ///
  /// @param ctx     The active [ArtisanContext] for output writes.
  /// @param result  The [TransactionResult] returned by [PluginInstaller.commit].
  /// @return The process exit code per the table above.
  int _renderResult(ArtisanContext ctx, TransactionResult result) {
    switch (result) {
      case Success(opCount: final n, recordPath: final path):
        ctx.output.success('magic installed ($n op(s)). Install record: $path');
        return 0;
      case DryRun(opCount: final n):
        ctx.output.info('Dry-run: $n op(s) staged; no files were written.');
        return 0;
      case Conflict(conflicts: final list):
        ctx.output.error(
          'Conflict on ${list.length} file(s). Re-run with --force to overwrite.',
        );
        for (final c in list) {
          ctx.output.warning('  ${c.absPath}: ${c.reason}');
        }
        return 1;
      case Error(error: final msg, rolledBack: final ok):
        ctx.output.error('Install failed: $msg (rolledBack: $ok)');
        return 2;
    }
  }
}

/// Pairing of a conditional config stub with its target path. Used by
/// [MagicInstallCommand._applyFluentOverride] to emit the 6 `--without-X`
/// gated publishes without repeating the stub/target pair literal across
/// the conditional branches.
class _ConditionalConfig {
  final String stubName;
  final String target;

  const _ConditionalConfig({required this.stubName, required this.target});
}
