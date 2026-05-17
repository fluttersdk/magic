import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '../install_stubs.dart';

/// Initialize Magic Framework in an existing Flutter project.
///
/// Creates the recommended directory structure, config files, starter providers,
/// and injects the Magic bootstrap into `main.dart`.
///
/// ## Usage
///
/// ```bash
/// artisan magic:install
/// artisan magic:install --without-database --without-auth
/// ```
///
/// ## Options
///
/// | Flag | Description |
/// |------|-------------|
/// | `--without-database` | Skip database directories and `config/database.dart` |
/// | `--without-auth` | Skip `config/auth.dart` |
/// | `--without-network` | Skip `config/network.dart` |
/// | `--without-cache` | Skip `config/cache.dart` |
/// | `--without-events` | Skip events setup |
/// | `--without-localization` | Skip `assets/lang/` directory |
/// | `--without-logging` | Skip `config/logging.dart` |
/// | `--without-broadcasting` | Skip broadcasting setup |
class MagicInstallCommand extends ArtisanCommand {
  @override
  CommandBoot get boot => CommandBoot.none;

  @override
  String get name => 'magic:install';

  @override
  String get description => 'Initialize Magic in a Flutter project';

  /// Return the Flutter project root directory.
  ///
  /// Overridable in tests to point at a temp directory.
  String getProjectRoot() {
    return FileHelper.findProjectRoot();
  }

  @override
  void configure(ArgParser parser) {
    parser.addFlag('without-auth', help: 'Skip auth setup', negatable: false);
    parser.addFlag(
      'without-database',
      help: 'Skip database setup',
      negatable: false,
    );
    parser.addFlag(
      'without-network',
      help: 'Skip network setup',
      negatable: false,
    );
    parser.addFlag('without-cache', help: 'Skip cache setup', negatable: false);
    parser.addFlag(
      'without-events',
      help: 'Skip events setup',
      negatable: false,
    );
    parser.addFlag(
      'without-localization',
      help: 'Skip localization setup',
      negatable: false,
    );
    parser.addFlag(
      'without-logging',
      help: 'Skip logging setup',
      negatable: false,
    );
    parser.addFlag(
      'without-broadcasting',
      help: 'Skip broadcasting setup',
      negatable: false,
    );
  }

  @override
  Future<int> handle(ArtisanContext ctx) async {
    final root = getProjectRoot();

    final withoutAuth = (ctx.input.option('without-auth') as bool?) ?? false;
    final withoutDatabase =
        (ctx.input.option('without-database') as bool?) ?? false;
    final withoutNetwork =
        (ctx.input.option('without-network') as bool?) ?? false;
    final withoutCache = (ctx.input.option('without-cache') as bool?) ?? false;
    final withoutEvents =
        (ctx.input.option('without-events') as bool?) ?? false;
    final withoutLocalization =
        (ctx.input.option('without-localization') as bool?) ?? false;
    final withoutLogging =
        (ctx.input.option('without-logging') as bool?) ?? false;
    final withoutBroadcasting =
        (ctx.input.option('without-broadcasting') as bool?) ?? false;

    _createDirectories(
      root,
      withoutDatabase: withoutDatabase,
      withoutEvents: withoutEvents,
      withoutLocalization: withoutLocalization,
    );

    _createConfigFiles(
      root,
      withoutAuth: withoutAuth,
      withoutDatabase: withoutDatabase,
      withoutNetwork: withoutNetwork,
      withoutCache: withoutCache,
      withoutLogging: withoutLogging,
      withoutLocalization: withoutLocalization,
      withoutBroadcasting: withoutBroadcasting,
    );

    _createStarterFiles(root);

    _createMainDart(
      root,
      withoutAuth: withoutAuth,
      withoutDatabase: withoutDatabase,
      withoutNetwork: withoutNetwork,
      withoutCache: withoutCache,
      withoutLogging: withoutLogging,
      withoutBroadcasting: withoutBroadcasting,
    );

    _patchDefaultWidgetTest(root);
    _createEnvFiles(root, withoutBroadcasting: withoutBroadcasting);

    _registerEnvAsset(root);

    if (!withoutDatabase) {
      await _setupWebSupport(root, ctx);
    }

    ctx.output.success('Magic installed successfully!');
    return 0;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Creates all required directories under [root]. Skips optional dirs when
  /// the corresponding feature flag is disabled.
  void _createDirectories(
    String root, {
    required bool withoutDatabase,
    required bool withoutEvents,
    required bool withoutLocalization,
  }) {
    final appDirs = [
      'lib/app/controllers',
      'lib/app/models',
      'lib/app/enums',
      'lib/app/middleware',
      'lib/app/policies',
      'lib/app/providers',
      'lib/resources/views',
      'lib/routes',
      'lib/config',
    ];

    if (!withoutEvents) {
      appDirs.addAll(['lib/app/listeners', 'lib/app/events']);
    }

    for (final dir in appDirs) {
      FileHelper.ensureDirectoryExists(path.join(root, dir));
    }

    if (!withoutDatabase) {
      final dbDirs = [
        'lib/database/migrations',
        'lib/database/seeders',
        'lib/database/factories',
      ];
      for (final dir in dbDirs) {
        FileHelper.ensureDirectoryExists(path.join(root, dir));
      }
    }

    if (!withoutLocalization) {
      FileHelper.ensureDirectoryExists(path.join(root, 'assets/lang'));
    }
  }

  /// Writes all config files under `lib/config/`.
  void _createConfigFiles(
    String root, {
    required bool withoutAuth,
    required bool withoutDatabase,
    required bool withoutNetwork,
    required bool withoutCache,
    required bool withoutLogging,
    required bool withoutLocalization,
    required bool withoutBroadcasting,
  }) {
    final providerImports = <String>[];
    final providerEntries = <String>[];
    final authProviderEntries = <String>[];

    if (!withoutCache) {
      providerEntries.add('(app) => CacheServiceProvider(app),');
    }
    if (!withoutDatabase) {
      providerEntries.add('(app) => DatabaseServiceProvider(app),');
    }

    // Launch is always registered — the welcome view uses Launch.url().
    providerEntries.add('(app) => LaunchServiceProvider(app),');

    if (!withoutLocalization) {
      providerEntries.add('(app) => LocalizationServiceProvider(app),');
    }
    if (!withoutNetwork) {
      providerEntries.add('(app) => NetworkServiceProvider(app),');
    }
    if (!withoutAuth) {
      providerEntries.add('(app) => VaultServiceProvider(app),');
    }
    if (!withoutBroadcasting) {
      providerEntries.add('(app) => BroadcastServiceProvider(app),');
    }

    if (!withoutAuth) {
      authProviderEntries.add('(app) => AuthServiceProvider(app),');
    }

    _writeIfNotExists(
      path.join(root, 'lib/config/app.dart'),
      InstallStubs.appConfigContent(
        providerImports: providerImports,
        providerEntries: providerEntries,
        authProviderEntries: authProviderEntries,
      ),
    );

    _writeIfNotExists(
      path.join(root, 'lib/config/view.dart'),
      InstallStubs.viewConfigContent(),
    );

    _writeIfNotExists(
      path.join(root, 'lib/config/routing.dart'),
      InstallStubs.routingConfigContent(),
    );

    if (!withoutAuth) {
      _writeIfNotExists(
        path.join(root, 'lib/config/auth.dart'),
        InstallStubs.authConfigContent(),
      );
    }
    if (!withoutDatabase) {
      _writeIfNotExists(
        path.join(root, 'lib/config/database.dart'),
        InstallStubs.databaseConfigContent(),
      );
    }
    if (!withoutNetwork) {
      _writeIfNotExists(
        path.join(root, 'lib/config/network.dart'),
        InstallStubs.networkConfigContent(),
      );
    }
    if (!withoutCache) {
      _writeIfNotExists(
        path.join(root, 'lib/config/cache.dart'),
        InstallStubs.cacheConfigContent(),
      );
    }
    if (!withoutLogging) {
      _writeIfNotExists(
        path.join(root, 'lib/config/logging.dart'),
        InstallStubs.loggingConfigContent(),
      );
    }
    if (!withoutBroadcasting) {
      _writeIfNotExists(
        path.join(root, 'lib/config/broadcasting.dart'),
        InstallStubs.broadcastingConfigContent(),
      );
    }
  }

  /// Writes the framework starter files that are always created.
  void _createStarterFiles(String root) {
    _writeIfNotExists(
      path.join(root, 'lib/app/providers/route_service_provider.dart'),
      InstallStubs.routeServiceProviderContent(),
    );

    _writeIfNotExists(
      path.join(root, 'lib/app/providers/app_service_provider.dart'),
      InstallStubs.appServiceProviderContent(),
    );

    _writeIfNotExists(
      path.join(root, 'lib/app/kernel.dart'),
      InstallStubs.kernelDartContent(),
    );

    final appName = _getAppName(root);

    _writeIfNotExists(
      path.join(root, 'lib/routes/app.dart'),
      InstallStubs.routesAppContent(appName: appName),
    );

    _writeIfNotExists(
      path.join(root, 'lib/resources/views/welcome_view.dart'),
      InstallStubs.welcomeViewContent(appName: appName),
    );
  }

  /// Writes `lib/main.dart` with Magic bootstrap.
  void _createMainDart(
    String root, {
    required bool withoutAuth,
    required bool withoutDatabase,
    required bool withoutNetwork,
    required bool withoutCache,
    required bool withoutLogging,
    required bool withoutBroadcasting,
  }) {
    final mainPath = path.join(root, 'lib/main.dart');

    if (FileHelper.fileExists(mainPath)) {
      final existing = FileHelper.readFile(mainPath);
      if (existing.contains('Magic.init')) {
        // Idempotency: Magic.init already present — preserve existing bootstrap.
        return;
      }
    }

    final configImports = <String>[
      "import 'config/app.dart';",
      "import 'config/routing.dart';",
      "import 'config/view.dart';",
    ];

    final configFactories = <String>[
      '() => appConfig',
      '() => routingConfig',
      '() => viewConfig',
    ];

    if (!withoutAuth) {
      configImports.add("import 'config/auth.dart';");
      configFactories.add('() => authConfig');
    }
    if (!withoutDatabase) {
      configImports.add("import 'config/database.dart';");
      configFactories.add('() => databaseConfig');
    }
    if (!withoutNetwork) {
      configImports.add("import 'config/network.dart';");
      configFactories.add('() => networkConfig');
    }
    if (!withoutCache) {
      configImports.add("import 'config/cache.dart';");
      configFactories.add('() => cacheConfig');
    }
    if (!withoutLogging) {
      configImports.add("import 'config/logging.dart';");
      configFactories.add('() => loggingConfig');
    }
    if (!withoutBroadcasting) {
      configImports.add("import 'config/broadcasting.dart';");
      configFactories.add('() => broadcastingConfig');
    }

    final appName = _getAppName(root);

    FileHelper.writeFile(
      mainPath,
      InstallStubs.mainDartContent(
        appName: appName,
        configImports: configImports,
        configFactories: configFactories,
      ),
    );
  }

  /// Replaces Flutter's default counter widget test when it still references
  /// `MyApp`, which is removed by Magic bootstrap generation.
  void _patchDefaultWidgetTest(String root) {
    final widgetTestPath = path.join(root, 'test/widget_test.dart');

    if (!FileHelper.fileExists(widgetTestPath)) {
      return;
    }

    final existingContent = FileHelper.readFile(widgetTestPath);
    final isDefaultCounterTest =
        existingContent.contains('Counter increments smoke test') &&
        existingContent.contains('const MyApp()');

    if (!isDefaultCounterTest) {
      return;
    }

    FileHelper.writeFile(widgetTestPath, InstallStubs.widgetTestContent());
  }

  /// Writes `.env` and `.env.example` to [root] if they do not already exist.
  void _createEnvFiles(String root, {required bool withoutBroadcasting}) {
    final appName = _getAppName(root);

    _writeIfNotExists(
      path.join(root, '.env'),
      InstallStubs.envContent(
        appName: appName,
        withoutBroadcasting: withoutBroadcasting,
      ),
    );

    _writeIfNotExists(
      path.join(root, '.env.example'),
      InstallStubs.envExampleContent(withoutBroadcasting: withoutBroadcasting),
    );
  }

  /// Reads the `name` field from `pubspec.yaml` and converts it to Title Case.
  String _getAppName(String root) {
    final pubspecPath = path.join(root, 'pubspec.yaml');
    if (FileHelper.fileExists(pubspecPath)) {
      try {
        final yaml = FileHelper.readYamlFile(pubspecPath);
        final name = yaml['name'] as String? ?? 'My App';
        return name
            .split('_')
            .map((w) => w[0].toUpperCase() + w.substring(1))
            .join(' ');
      } catch (_) {
        // pubspec.yaml unreadable or malformed — fall back to default name.
        return 'My App';
      }
    }
    return 'My App';
  }

  // ---------------------------------------------------------------------------
  // Asset & Web Setup
  // ---------------------------------------------------------------------------

  /// Adds `.env` to the `flutter.assets` list in `pubspec.yaml`.
  void _registerEnvAsset(String root) {
    final pubspecPath = path.join(root, 'pubspec.yaml');

    if (!FileHelper.fileExists(pubspecPath)) {
      return;
    }

    final content = FileHelper.readFile(pubspecPath);
    final doc = loadYaml(content);

    // 1. Check if .env is already registered — skip if so.
    if (doc is Map && doc['flutter'] is Map) {
      final assets = doc['flutter']['assets'];
      if (assets is List && assets.contains('.env')) {
        return;
      }
    }

    // 2. Build the updated assets list.
    final existingAssets = <String>[];
    if (doc is Map && doc['flutter'] is Map) {
      final assets = doc['flutter']['assets'];
      if (assets is List) {
        existingAssets.addAll(assets.cast<String>());
      }
    }
    existingAssets.add('.env');

    // 3. Write back using yaml_edit.
    final editor = YamlEditor(content);

    try {
      editor.parseAt(['flutter', 'assets']);
      // Path exists — update it.
      editor.update(['flutter', 'assets'], existingAssets);
    } catch (_) {
      // Path doesn't exist — create it.
      try {
        editor.parseAt(['flutter']);
        // flutter key exists but no assets.
        editor.update(['flutter', 'assets'], existingAssets);
      } catch (_) {
        // flutter key doesn't exist at all.
        editor.update(['flutter'], {'assets': existingAssets});
      }
    }

    FileHelper.writeFile(pubspecPath, editor.toString());
  }

  /// Downloads `sqlite3.wasm` to the `web/` directory for web platform support.
  Future<void> _setupWebSupport(String root, ArtisanContext ctx) async {
    final targetPath = path.join(root, 'web', 'sqlite3.wasm');

    if (FileHelper.fileExists(targetPath)) {
      return;
    }

    final version = _resolveSqliteVersion(root);
    final url = Uri.parse(
      'https://github.com/simolus3/sqlite3.dart'
      '/releases/download/sqlite3-$version/sqlite3.wasm',
    );

    ctx.output.info('Downloading sqlite3.wasm ($version) for web support...');

    final downloaded = await downloadFile(url, targetPath);

    if (downloaded) {
      ctx.output.info('sqlite3.wasm downloaded to web/');
    } else {
      ctx.output.warning('Could not download sqlite3.wasm automatically.');
      ctx.output.warning('Download manually from: $url');
    }
  }

  /// Resolves the sqlite3 package version from `pubspec.lock`.
  String _resolveSqliteVersion(String root) {
    const fallback = '2.4.6';
    final lockPath = path.join(root, 'pubspec.lock');

    if (!FileHelper.fileExists(lockPath)) {
      return fallback;
    }

    try {
      final content = FileHelper.readFile(lockPath);
      final yaml = loadYaml(content) as YamlMap?;
      final packages = yaml?['packages'] as YamlMap?;
      final sqlite3 = packages?['sqlite3'] as YamlMap?;
      final version = sqlite3?['version'] as String?;

      return version ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  /// Downloads a file from [url] to [targetPath].
  ///
  /// Returns `true` on success, `false` on failure. Creates parent directories
  /// if they do not exist. Overridable in tests to avoid real HTTP requests.
  Future<bool> downloadFile(Uri url, String targetPath) async {
    final client = HttpClient();

    try {
      // 1. Follow redirects and fetch the response.
      final request = await client.getUrl(url);
      final response = await request.close();

      if (response.statusCode != 200) {
        await response.drain<void>();
        return false;
      }

      // 2. Ensure target directory exists.
      final file = File(targetPath);
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }

      // 3. Stream response body to disk.
      await response.pipe(file.openWrite());

      return true;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  /// Writes [content] to [filePath] only if the file does not already exist.
  void _writeIfNotExists(String filePath, String content) {
    if (!FileHelper.fileExists(filePath)) {
      FileHelper.writeFile(filePath, content);
    }
  }
}
