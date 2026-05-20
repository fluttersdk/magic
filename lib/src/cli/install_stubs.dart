/// Install command stub templates for Magic.
///
/// All methods return valid Dart code strings ready to be written to files.
/// Unlike model_stubs.dart (which uses const String), these methods accept
/// parameters to generate dynamic content based on active feature flags.
library;

import 'package:fluttersdk_artisan/artisan.dart';

/// Install command stub templates.
///
/// All methods are static and return valid Dart source code strings.
class InstallStubs {
  /// Prevent instantiation — this is a pure static utility class.
  const InstallStubs._();

  // ---------------------------------------------------------------------------
  // main.dart
  // ---------------------------------------------------------------------------

  /// Generates the `lib/main.dart` bootstrap file.
  ///
  /// Produces a full main.dart with `WidgetsFlutterBinding.ensureInitialized()`,
  /// `Magic.init()` with dynamic config factories, and `MagicApplication`.
  ///
  /// Stub loading is routed through the per-install [StubDriver] supplied by
  /// the caller (the active [InstallContext]'s `stubs` field) and an explicit
  /// [searchPaths] list pointing at magic's bundled `assets/stubs/`. The
  /// static [StubLoader] defaults resolve to fluttersdk_artisan's own
  /// `assets/stubs/`, where magic-only stubs do not exist; routing through
  /// the driver preserves multi-publisher correctness and lets in-memory test
  /// drivers serve fixture content without touching the host filesystem.
  ///
  /// [stubs] — the active [StubDriver] (production: [RealStubDriver];
  ///   tests: an in-memory fixture driver). Required so resolution honours
  ///   the magic-side stub bundle rather than the substrate's default.
  /// [searchPaths] — directories to search before the driver's defaults.
  ///   In production the caller resolves magic's stub directory via the
  ///   consumer's `package_config.json` and passes it here; pass `null`
  ///   when the test driver ignores [searchPaths].
  /// [appName] — the human-readable application name (e.g. `My App`).
  /// [configImports] — list of import statements (one per config file).
  /// [configFactories] — list of factory lambda strings (e.g. `() => appConfig`).
  static String mainDartContent({
    required StubDriver stubs,
    required String appName,
    required List<String> configImports,
    required List<String> configFactories,
    List<String>? searchPaths,
  }) {
    final imports = configImports.join('\n');
    final factories = configFactories.map((f) => '      $f,').join('\n');

    return stubs.replace(stubs.load('install/main', searchPaths: searchPaths), {
      'configImports': imports,
      'configFactories': factories,
      'appName': appName,
    });
  }

  // ---------------------------------------------------------------------------
  // Config files
  // ---------------------------------------------------------------------------

  /// Generates `lib/config/app.dart` with a dynamic providers list.
  ///
  /// Stub loading is routed through the per-install [StubDriver] supplied by
  /// the caller (the active [InstallContext]'s `stubs` field) and an explicit
  /// [searchPaths] list pointing at magic's bundled `assets/stubs/`. The
  /// static [StubLoader] defaults resolve to fluttersdk_artisan's own
  /// `assets/stubs/`, where magic-only stubs do not exist; routing through
  /// the driver preserves multi-publisher correctness and lets in-memory test
  /// drivers serve fixture content without touching the host filesystem.
  ///
  /// [stubs] — the active [StubDriver] (production: [RealStubDriver];
  ///   tests: an in-memory fixture driver). Required so resolution honours
  ///   the magic-side stub bundle rather than the substrate's default.
  /// [searchPaths] — directories to search before the driver's defaults.
  ///   In production the caller resolves magic's stub directory via the
  ///   consumer's `package_config.json` and passes it here; pass `null`
  ///   when the test driver ignores [searchPaths].
  /// [providerImports] — additional provider import statements beyond the
  ///   always-present `RouteServiceProvider` and `AppServiceProvider`.
  /// [providerEntries] — infrastructure `(app) => Provider(app),` strings.
  ///   These boot BEFORE AppServiceProvider and AuthServiceProvider.
  /// [authProviderEntries] — auth-related providers that must boot AFTER
  ///   AppServiceProvider (which registers `setUserFactory`).
  static String appConfigContent({
    required StubDriver stubs,
    required List<String> providerImports,
    required List<String> providerEntries,
    List<String> authProviderEntries = const [],
    List<String>? searchPaths,
  }) {
    final allImports = [
      "import 'package:magic/magic.dart';",
      "import '../app/providers/app_service_provider.dart';",
      "import '../app/providers/route_service_provider.dart';",
      ...providerImports,
    ].join('\n');

    // Boot order matters:
    // 1. RouteServiceProvider — routes
    // 2. Infrastructure providers — cache, database, network, vault, etc.
    // 3. AppServiceProvider — registers userFactory via setUserFactory()
    // 4. AuthServiceProvider — calls Auth.restore() (needs userFactory)
    final allProviders = [
      '      (app) => RouteServiceProvider(app),',
      ...providerEntries.map((e) => '      $e'),
      '      (app) => AppServiceProvider(app),',
      ...authProviderEntries.map((e) => '      $e'),
    ].join('\n');

    return stubs.replace(
      stubs.load('install/app_config', searchPaths: searchPaths),
      {'allImports': allImports, 'allProviders': allProviders},
    );
  }

  /// Generates `lib/config/auth.dart` matching the Uptizm production pattern.
  @Deprecated('Migrated to install.yaml publish:; will be removed in V2')
  static String authConfigContent() {
    return StubLoader.load('install/auth_config');
  }

  /// Generates `lib/config/database.dart` with SQLite as the default driver.
  @Deprecated('Migrated to install.yaml publish:; will be removed in V2')
  static String databaseConfigContent() {
    return StubLoader.load('install/database_config');
  }

  /// Generates `lib/config/network.dart` with a single API driver.
  @Deprecated('Migrated to install.yaml publish:; will be removed in V2')
  static String networkConfigContent() {
    return StubLoader.load('install/network_config');
  }

  /// Generates `lib/config/view.dart` with Wind UI dialog/confirm classes.
  @Deprecated('Migrated to install.yaml publish:; will be removed in V2')
  static String viewConfigContent() {
    return StubLoader.load('install/view_config');
  }

  /// Generates `lib/config/cache.dart` with `FileStore()` driver and default TTL.
  @Deprecated('Migrated to install.yaml publish:; will be removed in V2')
  static String cacheConfigContent() {
    return StubLoader.load('install/cache_config');
  }

  /// Generates `lib/config/logging.dart` with stack -> console channel setup.
  @Deprecated('Migrated to install.yaml publish:; will be removed in V2')
  static String loggingConfigContent() {
    return StubLoader.load('install/logging_config');
  }

  /// Generates `lib/config/broadcasting.dart` with Reverb and null connections.
  @Deprecated('Migrated to install.yaml publish:; will be removed in V2')
  static String broadcastingConfigContent() {
    return StubLoader.load('install/broadcasting_config');
  }

  /// Generates `lib/config/routing.dart` with URL strategy config.
  @Deprecated('Migrated to install.yaml publish:; will be removed in V2')
  static String routingConfigContent() {
    return StubLoader.load('install/routing_config');
  }

  // ---------------------------------------------------------------------------
  // Service Providers
  // ---------------------------------------------------------------------------

  /// Generates `lib/app/providers/route_service_provider.dart`.
  @Deprecated('Migrated to install.yaml publish:; will be removed in V2')
  static String routeServiceProviderContent() {
    return StubLoader.load('install/route_service_provider');
  }

  /// Generates `lib/app/providers/app_service_provider.dart`.
  @Deprecated('Migrated to install.yaml publish:; will be removed in V2')
  static String appServiceProviderContent() {
    return StubLoader.load('install/app_service_provider');
  }

  // ---------------------------------------------------------------------------
  // Kernel
  // ---------------------------------------------------------------------------

  /// Generates `lib/app/kernel.dart`, the HTTP middleware registry.
  @Deprecated('Migrated to install.yaml publish:; will be removed in V2')
  static String kernelDartContent() {
    return StubLoader.load('install/kernel');
  }

  // ---------------------------------------------------------------------------
  // Routes
  // ---------------------------------------------------------------------------

  /// Generates `lib/routes/app.dart` with a single welcome route.
  ///
  /// [appName] used only for documentation context; not embedded in code.
  @Deprecated('Migrated to install.yaml publish:; will be removed in V2')
  static String routesAppContent({required String appName}) {
    // Note: The original template doesn't actually use appName in the body,
    // so this is just loading the static stub.
    return StubLoader.load('install/routes_app');
  }

  // ---------------------------------------------------------------------------
  // Views
  // ---------------------------------------------------------------------------

  /// Generates `lib/resources/views/welcome_view.dart`.
  ///
  /// [appName] is the human-readable application name shown in the hero
  /// section.
  @Deprecated('Migrated to install.yaml publish:; will be removed in V2')
  static String welcomeViewContent({required String appName}) {
    return StubLoader.replace(StubLoader.load('install/welcome_view'), {
      'appName': appName,
    });
  }

  // ---------------------------------------------------------------------------
  // Environment files
  // ---------------------------------------------------------------------------

  /// Generates a `.env` template file with sensible defaults.
  ///
  /// [appName] is written as the default value for `APP_NAME`.
  /// [withoutBroadcasting] when `true`, omits the `BROADCAST_CONNECTION`
  ///   and `REVERB_*` environment variables.
  @Deprecated('Migrated to install.yaml publish:; will be removed in V2')
  static String envContent({
    required String appName,
    bool withoutBroadcasting = false,
  }) {
    var content = StubLoader.replace(StubLoader.load('install/env'), {
      'appName': appName,
    });

    if (!withoutBroadcasting) {
      content +=
          '\nBROADCAST_CONNECTION=null\n'
          'REVERB_HOST=localhost\n'
          'REVERB_PORT=8080\n'
          'REVERB_SCHEME=ws\n'
          'REVERB_APP_KEY=\n';
    }

    return content;
  }

  /// Generates a `.env.example` template file with empty values.
  @Deprecated('Migrated to install.yaml publish:; will be removed in V2')
  static String envExampleContent({bool withoutBroadcasting = false}) {
    var content = StubLoader.load('install/env_example');

    if (!withoutBroadcasting) {
      content +=
          '\nBROADCAST_CONNECTION=\n'
          'REVERB_HOST=\n'
          'REVERB_PORT=\n'
          'REVERB_SCHEME=\n'
          'REVERB_APP_KEY=\n';
    }

    return content;
  }

  /// Generates a Magic-compatible smoke test for `test/widget_test.dart`.
  static String widgetTestContent() {
    return '''import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

void main() {
  testWidgets('Magic app boots smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MagicApplication(
        title: 'Test App',
      ),
    );

    expect(find.byType(MagicApplication), findsOneWidget);
  });
}
  ''';
  }
}
