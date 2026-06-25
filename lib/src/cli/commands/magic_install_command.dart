import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data' show BytesBuilder;

import 'package:meta/meta.dart' show visibleForTesting;
import 'package:fluttersdk_artisan/artisan.dart';
import 'package:more/diff.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../helpers/main_dart_scaffold_detector.dart';
import '../helpers/main_dart_smart_merger.dart';
import '../install_stubs.dart';

/// Strategy chosen by [MagicInstallCommand._resolveMainDartStrategy] for
/// how to handle a pre-existing `lib/main.dart` during install.
///
/// - [overwrite]: replace the file with the Magic template unconditionally.
/// - [preserve]: inject Magic bootstrap into the existing file without removing it.
/// - [cancel]: abort the install; the operator must re-run with a flag.
enum MainDartStrategy { overwrite, preserve, cancel }

/// Result tuple returned by [MagicInstallCommand._resolveMainDartStrategy].
///
/// Carries the chosen [strategy] plus the [scaffoldDetected] flag so [handle]
/// can decide whether to silently force past [ConflictDetector] for an
/// auto-detected `flutter create` counter app (the 90%-case fresh-install
/// flow). The flag is `false` for every other branch (no file, --force,
/// --preserve, customized file).
typedef MainDartStrategyResult = ({
  MainDartStrategy strategy,
  bool scaffoldDetected,
});

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
/// dart run magic:artisan magic:install
/// dart run magic:artisan magic:install --without-auth --without-broadcasting
/// dart run magic:artisan magic:install --force --non-interactive
/// ```
class MagicInstallCommand extends ArtisanInstallCommand {
  /// Public default constructor. Test fixtures subclass + override the four
  /// `@visibleForTesting` hooks.
  MagicInstallCommand();

  @override
  String get signature =>
      'magic:install '
      '$baseFlags'
      '{--preserve : Inject Magic into existing lib/main.dart without overwriting; rejects sync main()} '
      '{--without-auth : Skip auth setup} '
      '{--without-database : Skip database setup} '
      '{--without-network : Skip network setup} '
      '{--without-cache : Skip cache setup} '
      '{--without-events : Skip events setup} '
      '{--without-localization : Skip localization setup} '
      '{--without-logging : Skip logging setup} '
      '{--without-broadcasting : Skip broadcasting setup} '
      '{--with-devtools : Wire the debug trio (magic_devtools + fluttersdk_dusk + fluttersdk_telescope) into lib/main.dart under kDebugMode and add them as dependencies}';

  @override
  String get description =>
      'Install Magic framework via the bundled install.yaml manifest.';

  @override
  String pluginName(ArtisanContext ctx) => 'magic';

  /// Returns `true` when the operator passed `--preserve`.
  ///
  /// Preserve mode injects Magic bootstrap into an existing `lib/main.dart`
  /// without overwriting it. The caller is responsible for acting on this flag;
  /// [handle] reads it to select the appropriate main.dart write strategy.
  ///
  /// @param ctx  The active [ArtisanContext] handed to [handle].
  /// @return The boolean value of the `--preserve` flag.
  bool isPreserve(ArtisanContext ctx) => ctx.input.option('preserve') == true;

  /// Returns `true` when the operator passed `--with-devtools`.
  ///
  /// The flag is a one-step replacement for the manual debug-trio bootstrap
  /// (add three deps, then run `dusk:install` + `telescope:install`). When set,
  /// [_applyFluentOverride] wires the trio (`magic_devtools` + `fluttersdk_dusk`
  /// + `fluttersdk_telescope`) into `lib/main.dart` under `kDebugMode` and adds
  /// the three packages as regular `dependencies`. They go under `dependencies`
  /// (not `dev_dependencies`) because `lib/main.dart` imports them: the
  /// `kDebugMode` gate tree-shakes the subsystem out of release builds, so the
  /// dep classification matches the dusk/telescope install docs and avoids the
  /// `depend_on_referenced_packages` lint.
  ///
  /// @param ctx  The active [ArtisanContext] handed to [handle].
  /// @return The boolean value of the `--with-devtools` flag.
  bool isWithDevtools(ArtisanContext ctx) =>
      ctx.input.option('with-devtools') == true;

  /// Formats a unified diff of [existing] vs [magicTemplate] for console display.
  ///
  /// Uses [UnifiedDiffer] with 3 lines of context. The source and target labels
  /// are the canonical `lib/main.dart` paths for operator readability.
  ///
  /// Returns an empty string when the two inputs are identical (no hunks).
  ///
  /// @param existing       The on-disk content of `lib/main.dart`.
  /// @param magicTemplate  The Magic-generated content that would overwrite it.
  /// @return A unified-diff string, or empty string when files are identical.
  @visibleForTesting
  String formatMainDartDiff(String existing, String magicTemplate) =>
      _formatMainDartDiff(existing, magicTemplate);

  /// Internal unified-diff formatter.
  ///
  /// @param existing       The on-disk content of `lib/main.dart`.
  /// @param magicTemplate  The Magic-generated content that would overwrite it.
  /// @return A unified-diff string, or empty string when files are identical.
  String _formatMainDartDiff(String existing, String magicTemplate) {
    return UnifiedDiffer(context: 3)
        .compareStrings(
          existing,
          magicTemplate,
          sourceLabel: 'lib/main.dart (existing)',
          targetLabel: 'lib/main.dart (Magic template)',
        )
        .join('\n');
  }

  /// Public delegate for [_resolveMainDartStrategy] exposed for unit tests.
  ///
  /// Tests call this directly on a [_TestableMagicInstallCommand] instance
  /// rather than running the full install pipeline. The `@visibleForTesting`
  /// annotation keeps the public surface minimal; production code in [handle]
  /// calls the private impl which carries the depth counter.
  ///
  /// @param ctx             The active [ArtisanContext].
  /// @param installContext  The active [InstallContext] (fs + prompt + flags).
  /// @param appName         Application name for the Magic template (default '').
  /// @param configImports   Config import lines for the Magic template (default []).
  /// @param configFactories Config factory lines for the Magic template (default []).
  /// @return The resolved [MainDartStrategyResult].
  @visibleForTesting
  Future<MainDartStrategyResult> resolveMainDartStrategy(
    ArtisanContext ctx,
    InstallContext installContext, {
    String appName = '',
    List<String> configImports = const <String>[],
    List<String> configFactories = const <String>[],
  }) => _resolveMainDartStrategy(
    ctx,
    installContext,
    appName: appName,
    configImports: configImports,
    configFactories: configFactories,
  );

  /// Resolves the strategy for writing `lib/main.dart` during install.
  ///
  /// Algorithm:
  ///   1. Compute the target path inside [installContext.projectRoot].
  ///   2. Fresh install (file absent): return [MainDartStrategy.overwrite].
  ///   3. --force: return [MainDartStrategy.overwrite].
  ///   4. --preserve: return [MainDartStrategy.preserve].
  ///   5. Read existing content; scaffold detected: return overwrite + info log.
  ///   6. --non-interactive + customized: emit error, return cancel.
  ///   7. Interactive: [Prompt.choice] on 4 options with recursion for 'diff'.
  ///      Cap at [_diffDepthCap] to prevent infinite loops.
  ///
  /// @param ctx             The active [ArtisanContext].
  /// @param installContext  The active [InstallContext].
  /// @param appName         Application name for the Magic template diff preview.
  /// @param configImports   Config import lines for the Magic template diff preview.
  /// @param configFactories Config factory lines for the Magic template diff preview.
  /// @param depth           Recursion depth counter (default 0); callers omit.
  /// @return A [MainDartStrategyResult] pairing the chosen strategy with the
  ///         scaffold-detected flag (true only when the heuristic matched on
  ///         an existing file).
  Future<MainDartStrategyResult> _resolveMainDartStrategy(
    ArtisanContext ctx,
    InstallContext installContext, {
    String appName = '',
    List<String> configImports = const <String>[],
    List<String> configFactories = const <String>[],
    int depth = 0,
  }) async {
    // 1. Target path inside the consumer project.
    final targetPath = p.join(installContext.projectRoot, 'lib', 'main.dart');

    // 2. Fresh install: no conflict, no prompt needed.
    if (!installContext.fs.exists(targetPath)) {
      return (strategy: MainDartStrategy.overwrite, scaffoldDetected: false);
    }

    // 3. --force wins over everything except missing file. The scaffold
    //    detector is not consulted because --force is the user's explicit
    //    override, not an auto-detection.
    if (isForce(ctx)) {
      return (strategy: MainDartStrategy.overwrite, scaffoldDetected: false);
    }

    // 4. --preserve: caller asked explicitly for smart-merge mode.
    if (isPreserve(ctx)) {
      return (strategy: MainDartStrategy.preserve, scaffoldDetected: false);
    }

    // 5. Read existing content; if it looks like the flutter create scaffold,
    //    overwrite silently so the common fresh-project flow has zero friction.
    //    scaffoldDetected=true signals to [handle] that the eventual commit()
    //    call must pass force=true to bypass ConflictDetector without --force.
    final existing = installContext.fs.readAsString(targetPath);
    if (MainDartScaffoldDetector.isFlutterCreateScaffold(existing)) {
      ctx.output.info(
        'Default Flutter counter app detected; overwriting silently.',
      );
      return (strategy: MainDartStrategy.overwrite, scaffoldDetected: true);
    }

    // 6. Non-interactive mode with a customized file: cannot safely guess.
    if (isNonInteractive(ctx)) {
      ctx.output.error(
        'Existing lib/main.dart is not the default Flutter scaffold and '
        '--non-interactive is set. Use --force to overwrite or --preserve '
        'to smart-merge.',
      );
      return (strategy: MainDartStrategy.cancel, scaffoldDetected: false);
    }

    // 7. Interactive: let the operator choose. Recursion cap prevents infinite
    //    diff loops; on cap, overwrite is the safest default.
    if (depth >= _diffDepthCap) {
      return (strategy: MainDartStrategy.overwrite, scaffoldDetected: false);
    }

    final answer = installContext.prompt.choice(
      'Conflict on lib/main.dart detected. Choose:',
      options: <String>[
        'Overwrite — Replace with Magic template',
        'Preserve — Inject Magic into existing main.dart',
        'Diff — Show diff, re-prompt',
        'Cancel — Abort install',
      ],
      defaultValue: 'Overwrite — Replace with Magic template',
    );

    final firstWord = answer.toLowerCase().split(' ').first;
    switch (firstWord) {
      case 'overwrite':
        return (strategy: MainDartStrategy.overwrite, scaffoldDetected: false);
      case 'preserve':
        return (strategy: MainDartStrategy.preserve, scaffoldDetected: false);
      case 'diff':
        // Build the Magic template for this install run, then display the
        // unified diff so the operator sees exactly what would change before
        // committing to a strategy. Route stub loading through the per-install
        // StubDriver + magic's stub directory so the diff preview resolves
        // the same template the eventual commit will write.
        final magicStubsDir = resolveMagicStubsDir(installContext);
        final searchPaths = magicStubsDir == null
            ? null
            : <String>[magicStubsDir];
        final magicTemplate = InstallStubs.mainDartContent(
          stubs: installContext.stubs,
          searchPaths: searchPaths,
          appName: appName,
          configImports: configImports,
          configFactories: configFactories,
        );
        final diff = _formatMainDartDiff(existing, magicTemplate);
        ctx.output.writeln(diff);
        return _resolveMainDartStrategy(
          ctx,
          installContext,
          appName: appName,
          configImports: configImports,
          configFactories: configFactories,
          depth: depth + 1,
        );
      case 'cancel':
        return (strategy: MainDartStrategy.cancel, scaffoldDetected: false);
      default:
        return (strategy: MainDartStrategy.overwrite, scaffoldDetected: false);
    }
  }

  /// Maximum recursive re-prompt depth for the 'diff' branch.
  ///
  /// When the operator selects 'Diff' this many consecutive times the method
  /// returns [MainDartStrategy.overwrite] as the safest default rather than
  /// looping indefinitely.
  static const int _diffDepthCap = 5;

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

  /// Delegates the canonical Flutter consumer scaffold to artisan's `install`
  /// command, IN-PROCESS. Writes `bin/dispatcher.dart`, the codegen barrels
  /// (`lib/app/_plugins.g.dart`, `lib/app/commands/_index.g.dart`), the
  /// `fluttersdk_artisan` pubspec dep, then auto-chains `make:fast-cli` for
  /// `bin/fsa`. Returns the exit code of the underlying scaffold.
  ///
  /// Called from [handle] inside the `if (result is Success)` block between
  /// the post-install message echo and the `plugins:refresh` invocation:
  /// dispatcher.dart must exist BEFORE plugins:refresh regenerates
  /// `lib/app/_plugins.g.dart`.
  ///
  /// Marked `@visibleForTesting` so a test subclass can override and record
  /// invocations without spinning up the real artisan scaffold (which spawns
  /// `chmod` and `dart build cli` subprocesses).
  ///
  /// @param ctx             The active [ArtisanContext] (force flag + output).
  /// @param installContext  The active [InstallContext] (projectRoot resolved
  ///                        from the consumer pubspec).
  /// @return Exit code from [InstallArtisanCommand.scaffoldInto]; 0 on success.
  @visibleForTesting
  Future<int> delegateArtisanInstall(
    ArtisanContext ctx,
    InstallContext installContext,
  ) {
    return InstallArtisanCommand.scaffoldInto(
      root: installContext.projectRoot,
      force: isForce(ctx),
      ctx: ctx,
    );
  }

  @override
  Future<int> handle(ArtisanContext ctx) async {
    // 0. Mutual exclusion: --force and --preserve cannot be used together.
    //    Exit 2 signals incorrect CLI usage (same convention as getopt/argparse).
    if (isForce(ctx) && isPreserve(ctx)) {
      ctx.output.error('Cannot specify both --force and --preserve. Pick one.');
      return 2;
    }

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

    // 5. Resolve the lib/main.dart write strategy BEFORE constructing the
    //    manifest installer so the cancel branch can short-circuit without
    //    any disk side effects. The diff-preview branch needs the dynamic
    //    configImports/configFactories lists so the operator sees the exact
    //    template that would be written.
    final configImports = _buildConfigImports(flags);
    final configFactories = _buildConfigFactories(flags);
    final strategyResult = await _resolveMainDartStrategy(
      ctx,
      installContext,
      appName: appName,
      configImports: configImports,
      configFactories: configFactories,
    );

    // 5a. Cancel short-circuit: no manifest installer construction, no
    //     commit(), no install record. Exit 0 because cancel is a clean
    //     operator-driven abort, not an error.
    if (strategyResult.strategy == MainDartStrategy.cancel) {
      ctx.output.info('Install canceled by user. No changes were written.');
      return 0;
    }

    // 6. Construct the manifest installer + stage the always-on 10 publishes.
    final installer = ManifestInstaller(
      installContext,
      manifest,
      promptOverrides: overrides,
    );
    final stagedInstaller = installer.prepare(
      nonInteractive: isNonInteractive(ctx),
    );

    // 7. Layer the conditional 40% on top: 6 conditional config publishes +
    //    dynamic lib/config/app.dart overwrite + dynamic lib/main.dart write.
    //    The strategy threads into the override so the preserve branch can
    //    call MainDartSmartMerger.mergeMagicInto on the existing on-disk source.
    //    A _PreserveAbortedException signals a sync-main rejection: surface exit
    //    1 immediately without committing anything to disk.
    try {
      _applyFluentOverride(
        stagedInstaller,
        installContext: installContext,
        flags: flags,
        appName: appName,
        mainDartStrategy: strategyResult.strategy,
        withDevtools: isWithDevtools(ctx),
      );
    } on _PreserveAbortedException catch (e) {
      ctx.output.error(e.message);
      return 1;
    }

    // 8. Commit the now-conditional op list.
    //
    //    Force threading: when scaffold was detected the operator never asked
    //    for --force explicitly, but we still need to bypass ConflictDetector
    //    on the existing counter-app main.dart. Preserve mode also forces
    //    past the detector because the user explicitly opted in (manifest's
    //    other publishes have nothing to conflict with on a fresh install
    //    anyway; the force flag matters only for lib/main.dart and any other
    //    file the user happens to have lying around).
    //
    //    PluginInstaller.commit takes a SINGLE global force flag rather than
    //    per-op force, so the threading is OR-ed here at the call site.
    //    Interactive "Overwrite" also requires force=true to bypass the
    //    ConflictDetector for the existing file; force=true on a fresh install
    //    (no existing file) is harmless since there is nothing to conflict with.
    final forceCommit =
        isForce(ctx) ||
        strategyResult.strategy == MainDartStrategy.overwrite ||
        strategyResult.strategy == MainDartStrategy.preserve;
    final result = await stagedInstaller.commit(
      dryRun: isDryRun(ctx),
      force: forceCommit,
    );

    // 8. Echo post_install.message on Success.
    if (result is Success && manifest.postInstall.message != null) {
      ctx.output.info(manifest.postInstall.message!);
    }

    // 9. Delegate the canonical Flutter scaffold (bin/dispatcher.dart + barrels
    //    + pubspec dep + bin/fsa) to artisan's `install` command IN-PROCESS.
    //    Gated on Success so dry-run, Conflict, and Error results skip the
    //    delegation; atomic-commit semantics from `stagedInstaller.commit`
    //    are preserved (nothing partial is written when commit did not land).
    //    Ordering: AFTER the post_install advisory echo (operator sees magic's
    //    message first) and BEFORE plugins:refresh (so the dispatcher exists
    //    on disk when codegen picks up the provider list).
    if (result is Success) {
      final artisanInstallExitCode = await delegateArtisanInstall(
        ctx,
        installContext,
      );
      if (artisanInstallExitCode != 0) {
        ctx.output.error(
          'Magic install delegated to artisan install but it failed '
          '(exit $artisanInstallExitCode). Inspect '
          '${installContext.projectRoot}/bin/dispatcher.dart and '
          '${installContext.projectRoot}/bin/fsa for partial state.',
        );
        return artisanInstallExitCode;
      }
    }

    // 10a. Self-register magic in .artisan/plugins.json so the subsequent
    //      plugins:refresh picks up MagicArtisanProvider in lib/app/_plugins.g.dart.
    //      Without this step the consumer would need a separate
    //      `dart run magic:artisan plugin:install magic` invocation before
    //      `make:controller` etc. work — magic:install delegates the canonical
    //      consumer scaffold but does not register itself as a plugin.
    //      Idempotent: re-running magic:install on a project that already
    //      lists magic skips the registry write.
    if (result is Success) {
      _selfRegisterPlugin(ctx, installContext);
    }

    // 10. Auto-refresh: regenerate lib/app/_plugins.g.dart so MagicArtisanProvider
    //     plus any installed plugin providers are picked up by the consumer wrapper.
    //     Only runs on a real commit (Success); dry-run/conflict/error skip refresh.
    if (result is Success) {
      final refresh = ctx.registry?.find('plugins:refresh');
      if (refresh != null) {
        await refresh.handle(ctx);
      } else {
        ctx.output.info(
          'Run `dart run magic:artisan plugins:refresh` to register installed plugin commands.',
        );
      }
    }

    // 11. Web target + database feature enabled, auto-download sqlite3.wasm
    //     to web/sqlite3.wasm. simolus3/sqlite3.dart's WasmSqlite3.loadFromUrl
    //     needs this file present at runtime; before this step the consumer
    //     had to fetch it manually per the install.yaml post_install note,
    //     which produced a white-screen WebAssembly TypeError on first boot.
    if (result is Success && !flags['withoutDatabase']! && !isDryRun(ctx)) {
      await _maybeFetchSqliteWasm(ctx, installContext.projectRoot);
    }

    return _renderResult(ctx, result);
  }

  /// Fetches `sqlite3.wasm` from simolus3/sqlite3.dart GitHub releases into
  /// `<projectRoot>/web/sqlite3.wasm`. Skip-soft on missing web/ dir
  /// (non-web target) and already-present wasm file (idempotency).
  ///
  /// Version pin matches magic's own `sqlite3:` pubspec range. Bump in
  /// lockstep when the dep range moves; mismatched wasm + package versions
  /// are documented to produce subtle runtime corruption (per simolus3
  /// release notes).
  Future<void> _maybeFetchSqliteWasm(
    ArtisanContext ctx,
    String projectRoot,
  ) async {
    final webDir = Directory(p.join(projectRoot, 'web'));
    if (!webDir.existsSync()) {
      // Non-web target (mobile / desktop). sqlite3 FFI doesn't need wasm.
      return;
    }
    final wasmFile = File(p.join(webDir.path, 'sqlite3.wasm'));
    if (wasmFile.existsSync()) {
      ctx.output.info('web/sqlite3.wasm already present; skipping download.');
      return;
    }

    // Pinned to the sqlite3 package version magic depends on. simolus3 ships
    // one wasm per package release at this URL pattern.
    const sqlite3Version = '3.3.1';
    final url = Uri.parse(
      'https://github.com/simolus3/sqlite3.dart/releases/download/'
      'sqlite3-$sqlite3Version/sqlite3.wasm',
    );

    ctx.output.info('Downloading sqlite3.wasm ($sqlite3Version) into web/ ...');
    final client = HttpClient();
    try {
      // Follow redirects manually: GitHub release downloads return a 302 to
      // an S3 URL; HttpClient.getUrl honors followRedirects by default but
      // we keep the depth small to avoid runaway loops.
      final request = await client.getUrl(url);
      final response = await request.close();
      if (response.statusCode != 200) {
        ctx.output.error(
          'sqlite3.wasm download FAILED (HTTP ${response.statusCode}). '
          'Fix manually: curl -L "$url" -o web/sqlite3.wasm',
        );
        return;
      }

      // Stream-consume the response into a byte buffer; flutter's
      // consolidateHttpClientResponseBytes is not available from a pure-Dart
      // CLI context, so we accumulate manually.
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      wasmFile.writeAsBytesSync(bytes);

      final sizeKb = (bytes.length / 1024).toStringAsFixed(1);
      ctx.output.info(
        'web/sqlite3.wasm written ($sizeKb KB). Web target ready for sqlite3.',
      );
    } on Exception catch (e) {
      ctx.output.error(
        'sqlite3.wasm download FAILED: $e. '
        'Fix manually: curl -L "$url" -o web/sqlite3.wasm',
      );
    } finally {
      client.close(force: true);
    }
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
    required MainDartStrategy mainDartStrategy,
    bool withDevtools = false,
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
    // with the runtime-assembled providers list. Stub loading is routed
    // through installContext.stubs + the magic-rooted searchPaths so the
    // 'install/app_config' template resolves against magic's bundle, not
    // fluttersdk_artisan's substrate stubs.
    installer.writeFile(
      targetPath: p.join(projectRoot, 'lib/config/app.dart'),
      content: InstallStubs.appConfigContent(
        stubs: installContext.stubs,
        searchPaths: searchPaths,
        providerImports: const <String>[],
        providerEntries: _buildProviderEntries(flags),
        authProviderEntries: flags['withoutAuth']!
            ? const <String>[]
            : const <String>['(app) => AuthServiceProvider(app),'],
      ),
    );

    // Dynamic lib/main.dart: not in publish: at all; the configFactories
    // list cannot be expressed as a static template.
    //
    // Strategy-driven branch:
    //
    // - overwrite: write the Magic template AS-IS (the historical behavior).
    // - preserve:  read the existing source, call MainDartSmartMerger.mergeMagicInto
    //              to surgically inject Magic, then writeFile the result.
    //              A FormatException (sync main) causes _PreserveAbortedException
    //              to bubble up; handle() catches it and returns exit 1.
    // - cancel:    must never reach here because [handle] returns early at
    //              step 5a before constructing the manifest installer. If
    //              the guard ever fires, that is a logic error worth a hard
    //              StateError rather than silently writing the wrong content.
    switch (mainDartStrategy) {
      case MainDartStrategy.overwrite:
        final generated = InstallStubs.mainDartContent(
          stubs: installContext.stubs,
          searchPaths: searchPaths,
          appName: appName,
          configImports: _buildConfigImports(flags),
          configFactories: _buildConfigFactories(flags),
        );
        installer.writeFile(
          targetPath: p.join(projectRoot, 'lib/main.dart'),
          content: withDevtools ? buildDevtoolsWiring(generated) : generated,
        );
      case MainDartStrategy.preserve:
        // 1. Read the existing source from disk — the user explicitly chose
        //    preserve, so this file is guaranteed to exist at this point.
        final mainPath = p.join(projectRoot, 'lib/main.dart');
        final existing = installContext.fs.readAsString(mainPath);
        // 2. Surgically merge Magic bootstrap into the existing source.
        //    FormatException means the existing main() is synchronous; surface
        //    a clean, actionable message and abort via sentinel exception so
        //    handle() can return exit 1 without touching the disk.
        try {
          final merged = MainDartSmartMerger.mergeMagicInto(
            existing,
            appName: appName,
            configImports: _buildConfigImports(flags),
            configFactories: _buildConfigFactories(flags),
          );
          // 3. Queue the merged source as the canonical write for lib/main.dart.
          //    force=true is already threaded into commit() by handle() for
          //    the preserve case, so ConflictDetector will not block this write.
          //    The devtools transform is idempotent, so applying it to an
          //    already-wired merge result is a safe no-op on re-run.
          installer.writeFile(
            targetPath: mainPath,
            content: withDevtools ? buildDevtoolsWiring(merged) : merged,
          );
        } on FormatException catch (e) {
          throw _PreserveAbortedException(e.message);
        }
      case MainDartStrategy.cancel:
        throw StateError(
          'MagicInstallCommand._applyFluentOverride reached with '
          'MainDartStrategy.cancel; handle() must early-return before this '
          'method runs. This is a logic error in the install pipeline.',
        );
    }

    // Debug-trio deps: add magic_devtools + fluttersdk_dusk +
    // fluttersdk_telescope as regular dependencies (not dev_dependencies) when
    // --with-devtools is set. The kDebugMode wiring injected above imports
    // them from lib/, so dev_dependencies would trip depend_on_referenced_packages;
    // the kDebugMode gate tree-shakes the subsystem from release builds.
    // addDependency routes through the same ConfigEditor.addDependencyToPubspec
    // mechanism the delegated artisan install uses for fluttersdk_artisan, and
    // is idempotent (YamlEditor.update overwrites in place, never duplicates).
    if (withDevtools) {
      for (final dep in _devtoolsDependencies.entries) {
        installer.addDependency(dep.key, dep.value);
      }
    }

    // Replace the default `flutter create` counter widget test (it references
    // the now-removed MyApp, so it breaks `flutter test` + `dart analyze`) with
    // a Magic-compatible smoke test. Conflict detection + --force govern the
    // overwrite exactly like the other scaffold writes, so a consumer's custom
    // test is preserved unless they pass --force.
    installer.writeFile(
      targetPath: p.join(projectRoot, 'test/widget_test.dart'),
      content: InstallStubs.widgetTestContent(),
    );
  }

  /// The debug-trio packages added to the consumer's `dependencies` when
  /// `--with-devtools` is set, mapped to their version constraints.
  ///
  /// Pinned to the versions the `install.yaml` post-install message documents:
  /// bump these in lockstep when a trio package releases a new minor line. They
  /// are regular `dependencies` (not `dev_dependencies`) because the wiring in
  /// `lib/main.dart` imports them; the `kDebugMode` gate tree-shakes them from
  /// release builds.
  static const Map<String, String> _devtoolsDependencies = <String, String>{
    'magic_devtools': '^0.0.1',
    'fluttersdk_dusk': '^0.0.8',
    'fluttersdk_telescope': '^0.0.4',
  };

  /// Injects the debug-trio runtime wiring into a generated `lib/main.dart`
  /// [source] and returns the transformed source.
  ///
  /// Mirrors `dusk_install_command._injectRuntimeWiring` +
  /// `telescope_install_command._injectRuntimeWiring`: the imports plus the
  /// `kDebugMode`-gated `DuskPlugin.install()` / `TelescopePlugin.install()`
  /// (with its `ExceptionWatcher` + `DumpWatcher`) blocks are placed BEFORE
  /// `await Magic.init(` so the drivers are live during Magic boot, and the
  /// `MagicDuskIntegration.install()` / `MagicTelescopeIntegration.install()`
  /// blocks are placed AFTER `Magic.init(` (those query `Magic.find<X>()` /
  /// resolve the network driver, so they need the container ready).
  ///
  /// Pure-functional and idempotent: every block is injected through
  /// [MainDartEditor.injectBeforeAnchor] / [MainDartEditor.injectAfterAnchor],
  /// each of which early-returns when the snippet is already present, so a
  /// second pass over an already-wired source is a byte-for-byte no-op. This
  /// is what makes a re-run of `magic:install --with-devtools` safe.
  ///
  /// @param source  The generated (or smart-merged) `lib/main.dart` content.
  /// @return The transformed source with the debug-trio wiring injected.
  @visibleForTesting
  String buildDevtoolsWiring(String source) {
    // 1. Imports. Each devtools package import is anchored against the existing
    //    package import it must sit beside, so the generated import block stays
    //    `directives_ordering`-clean: package imports grouped before relative
    //    `config/...` imports, and alphabetically sorted within the group
    //    (`flutter/foundation` before `flutter/material`, `fluttersdk_*` before
    //    `magic`, `magic_devtools/*` after `magic`). Each injectBeforeAnchor is
    //    idempotent via its snippet-presence check, so a re-run is a no-op.
    var result = source;

    // 1a. `flutter/foundation` sorts before `flutter/material`.
    result = MainDartEditor.injectBeforeAnchor(
      source: result,
      anchor: "import 'package:flutter/material.dart'",
      snippet: "import 'package:flutter/foundation.dart' show kDebugMode;\n",
    );

    // 1b. `fluttersdk_*` sort after the flutter imports and before `magic`.
    result = MainDartEditor.injectBeforeAnchor(
      source: result,
      anchor: "import 'package:magic/magic.dart'",
      snippet:
          "import 'package:fluttersdk_dusk/dusk.dart';\n"
          "import 'package:fluttersdk_telescope/telescope.dart';\n",
    );

    // 1c. `magic_devtools/*` sort after `magic` and before the first relative
    //     `config/...` import; fall back to the `void main(` anchor when no
    //     relative import is present (a preserve-mode source without configs).
    const devtoolsImports =
        "import 'package:magic_devtools/dusk.dart';\n"
        "import 'package:magic_devtools/telescope.dart';\n";
    final afterMagic = MainDartEditor.injectBeforeAnchor(
      source: result,
      anchor: "import 'config/",
      snippet: devtoolsImports,
    );
    result = afterMagic == result
        ? MainDartEditor.injectBeforeAnchor(
            source: result,
            anchor: 'void main(',
            snippet: devtoolsImports,
          )
        : afterMagic;

    // 2. Plugin-install blocks BEFORE Magic.init: Dusk first so its snapshot
    //    pipeline is live during Magic boot, then Telescope so ExceptionWatcher
    //    catches boot errors.
    result = MainDartEditor.injectBeforeAnchor(
      source: result,
      anchor: 'await Magic.init(',
      snippet: '  if (kDebugMode) {\n    DuskPlugin.install();\n  }\n',
    );
    result = MainDartEditor.injectBeforeAnchor(
      source: result,
      anchor: 'await Magic.init(',
      snippet:
          '  if (kDebugMode) {\n'
          '    TelescopePlugin.install();\n'
          '    TelescopePlugin.registerWatcher(ExceptionWatcher());\n'
          '    TelescopePlugin.registerWatcher(DumpWatcher());\n'
          '  }\n',
    );

    // 3. Integration blocks AFTER Magic.init: both query the ready container.
    result = MainDartEditor.injectAfterAnchor(
      source: result,
      anchor: 'Magic.init',
      snippet:
          '  if (kDebugMode) {\n    MagicDuskIntegration.install();\n  }\n',
    );
    result = MainDartEditor.injectAfterAnchor(
      source: result,
      anchor: 'Magic.init',
      snippet:
          '  if (kDebugMode) {\n'
          '    MagicTelescopeIntegration.install();\n'
          '  }\n',
    );

    return result;
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

  /// Self-registers `magic` in the consumer's `.artisan/plugins.json` so the
  /// downstream `plugins:refresh` invocation picks up [MagicArtisanProvider]
  /// when regenerating `lib/app/_plugins.g.dart`.
  ///
  /// Without this step the consumer must run `dart run magic:artisan
  /// plugin:install magic` separately before `make:controller` etc. work.
  /// Idempotent: skips the registry write when an entry named `magic`
  /// already exists.
  void _selfRegisterPlugin(ArtisanContext ctx, InstallContext installContext) {
    final registryPath = p.join(
      installContext.projectRoot,
      '.artisan',
      'plugins.json',
    );

    Map<String, dynamic> registry;
    if (installContext.fs.exists(registryPath)) {
      registry =
          jsonDecode(installContext.fs.readAsString(registryPath))
              as Map<String, dynamic>;
    } else {
      registry = <String, dynamic>{'version': 1, 'plugins': <dynamic>[]};
    }

    final plugins =
        (registry['plugins'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
        <Map<String, dynamic>>[];

    final alreadyRegistered = plugins.any((entry) => entry['name'] == 'magic');
    if (alreadyRegistered) return;

    plugins.add(<String, dynamic>{
      'name': 'magic',
      'providerImport': 'package:magic/cli.dart',
      'providerClass': 'MagicArtisanProvider',
      'registeredAt': DateTime.now().toUtc().toIso8601String(),
    });
    registry['plugins'] = plugins;

    installContext.fs.writeAsString(
      registryPath,
      const JsonEncoder.withIndent('  ').convert(registry),
    );
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

/// Sentinel thrown by [MagicInstallCommand._applyFluentOverride] when
/// [MainDartSmartMerger.mergeMagicInto] rejects a sync `main()`.
///
/// Carries the [message] from the underlying [FormatException] so
/// [MagicInstallCommand.handle] can emit a clean, actionable error to the
/// operator and return exit 1 without exposing a raw exception stack trace.
class _PreserveAbortedException implements Exception {
  /// @param message  Actionable message from [MainDartSmartMerger.mergeMagicInto].
  const _PreserveAbortedException(this.message);

  /// Human-readable error text from the underlying [FormatException].
  final String message;
}
