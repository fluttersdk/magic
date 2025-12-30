import '../../config/app.dart';
import '../../config/auth.dart';
import '../../config/cache.dart';
import '../../config/database.dart';
import '../../config/localization.dart';
import '../../config/logging.dart';
import '../../config/network.dart';
import '../../config/view.dart';
import '../support/service_provider.dart';
import 'config_repository.dart';
import 'env.dart';

/// The Application Container.
///
/// This is the heart of the Magic framework - a powerful IoC (Inversion of
/// Control) container that manages all service bindings and their lifecycle.
///
/// Think of it like Laravel's `app()` helper - a central place where all your
/// application's services live. You can bind services, resolve them lazily,
/// and register service providers that bootstrap your entire application.
///
/// ## Quick Start
///
/// ```dart
/// // Initialize the app (loads .env and configs)
/// await MagicApp.init(configs: [appConfig, databaseConfig]);
///
/// // Bind a service
/// MagicApp.instance.bind('api', () => ApiService());
///
/// // Resolve it later (lazy loading)
/// final api = MagicApp.instance.make<ApiService>('api');
///
/// // Register as singleton (resolved only once)
/// MagicApp.instance.singleton('auth', () => AuthService());
/// ```
///
/// ## Service Providers
///
/// For larger applications, organize your bindings into Service Providers:
///
/// ```dart
/// MagicApp.instance.register(AuthServiceProvider());
/// MagicApp.instance.boot(); // Boots all registered providers
/// ```
class MagicApp {
  // ---------------------------------------------------------------------------
  // Singleton Pattern
  // ---------------------------------------------------------------------------

  /// Private constructor prevents external instantiation.
  MagicApp._();

  /// The single instance of the application container.
  static MagicApp? _instance;

  /// Access the global application instance.
  ///
  /// This is your gateway to the IoC container from anywhere in your app.
  /// Equivalent to Laravel's `app()` helper function.
  ///
  /// ```dart
  /// MagicApp.instance.make<UserService>('user');
  /// ```
  static MagicApp get instance {
    _instance ??= MagicApp._();
    return _instance!;
  }

  /// Whether the app has been initialized.
  static bool _initialized = false;

  /// The configuration repository.
  static final ConfigRepository _config = ConfigRepository();

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Initialize the Magic application.
  ///
  /// This loads environment variables and merges configuration.
  /// Call this at the start of your app before accessing config values.
  ///
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///
  ///   await MagicApp.init(
  ///     configs: [appConfig, databaseConfig, servicesConfig],
  ///   );
  ///
  ///   runApp(const MagicApplication());
  /// }
  /// ```
  ///
  /// **Parameters:**
  /// - [envFileName]: Path to .env file (default: '.env')
  /// - [configs]: List of configuration maps to merge
  static Future<void> init({
    String envFileName = '.env',
    List<Map<String, dynamic>> configs = const [],
  }) async {
    if (_initialized) return;

    // 1. Load environment variables
    await Env.load(fileName: envFileName);

    // 2. Load default framework config
    _config.merge(_defaultConfig());

    // 3. Merge user-provided configs
    for (final config in configs) {
      _config.merge(config);
    }

    _initialized = true;

    // Bind config to the container
    instance.setInstance('config', _config);
  }

  /// Check if the app has been initialized.
  static bool get isInitialized => _initialized;

  /// Get the configuration repository.
  static ConfigRepository get config => _config;

  /// Default framework configuration.
  static Map<String, dynamic> _defaultConfig() {
    return <String, dynamic>{}
      ..addAll(defaultAppConfig)
      ..addAll(defaultAuthConfig)
      ..addAll(defaultCacheConfig)
      ..addAll(defaultDatabaseConfig)
      ..addAll(defaultLoggingConfig)
      ..addAll(defaultNetworkConfig)
      ..addAll(defaultViewConfig)
      ..addAll(defaultLocalizationConfig);
  }

  // ---------------------------------------------------------------------------
  // Container Storage
  // ---------------------------------------------------------------------------

  /// Factory closures keyed by their abstract name.
  ///
  /// Each entry stores a factory function that creates the service instance,
  /// along with metadata about whether it should be shared (singleton).
  final Map<String, _Binding> _bindings = {};

  /// Resolved singleton instances.
  ///
  /// When a service is marked as `shared`, its instance is cached here
  /// after the first resolution.
  final Map<String, dynamic> _instances = {};

  /// Registered service providers.
  final List<ServiceProvider> _providers = [];

  /// Whether the application has been booted.
  bool _booted = false;

  // ---------------------------------------------------------------------------
  // Service Binding
  // ---------------------------------------------------------------------------

  /// Bind a service into the container.
  ///
  /// Use this to register factories that will be resolved later. By default,
  /// a new instance is created each time you call `make()`.
  ///
  /// Set `shared: true` to make it a singleton (same instance every time).
  ///
  /// ```dart
  /// // New instance each time
  /// app.bind('logger', () => Logger());
  ///
  /// // Singleton (shared instance)
  /// app.bind('cache', () => CacheService(), shared: true);
  /// ```
  ///
  /// **Parameters:**
  /// - [key]: The unique identifier for this service.
  /// - [closure]: A factory function that creates the service.
  /// - [shared]: If true, resolves to the same instance (singleton).
  void bind(String key, Function closure, {bool shared = false}) {
    _bindings[key] = _Binding(closure, shared);
  }

  /// Register a singleton service (shared binding).
  ///
  /// This is a convenience method equivalent to `bind(key, closure, shared: true)`.
  /// The service will be instantiated only once, on its first resolution.
  ///
  /// ```dart
  /// app.singleton('database', () => DatabaseConnection());
  ///
  /// // Both resolve to the same instance:
  /// final db1 = app.make('database');
  /// final db2 = app.make('database');
  /// print(identical(db1, db2)); // true
  /// ```
  void singleton(String key, Function closure) {
    bind(key, closure, shared: true);
  }

  /// Store an existing instance in the container.
  ///
  /// Unlike `singleton()`, this doesn't take a factory - it stores
  /// an already-instantiated object directly.
  ///
  /// ```dart
  /// final config = Config.load();
  /// app.instance('config', config);
  /// ```
  void setInstance(String key, dynamic value) {
    _instances[key] = value;
  }

  // ---------------------------------------------------------------------------
  // Service Resolution
  // ---------------------------------------------------------------------------

  /// Resolve a service from the container.
  ///
  /// This is the primary way to retrieve services. The container will:
  /// 1. Return a cached instance if it's a singleton that's been resolved.
  /// 2. Call the factory function to create a new instance.
  /// 3. Cache the instance if it's a shared (singleton) binding.
  ///
  /// ```dart
  /// final auth = app.make<AuthService>('auth');
  /// ```
  ///
  /// Throws an [Exception] if the service is not registered.
  T make<T>(String key) {
    // Check for existing singleton instance
    if (_instances.containsKey(key)) {
      return _instances[key] as T;
    }

    // Check for binding
    if (!_bindings.containsKey(key)) {
      throw Exception(
        'Service [$key] is not registered in the container. '
        'Did you forget to bind it or register a ServiceProvider?',
      );
    }

    final binding = _bindings[key]!;
    final instance = binding.factory();

    // Cache if it's a singleton
    if (binding.shared) {
      _instances[key] = instance;
    }

    return instance as T;
  }

  /// Check if a service is bound in the container.
  ///
  /// ```dart
  /// if (app.bound('cache')) {
  ///   final cache = app.make<CacheService>('cache');
  /// }
  /// ```
  bool bound(String key) {
    return _bindings.containsKey(key) || _instances.containsKey(key);
  }

  // ---------------------------------------------------------------------------
  // Service Providers
  // ---------------------------------------------------------------------------

  /// Register a service provider with the application.
  ///
  /// Service providers are the central place to configure your application.
  /// When registered, the provider's `register()` method is called immediately
  /// to bind services. The `boot()` method is called later via `app.boot()`.
  ///
  /// ```dart
  /// app.register(AuthServiceProvider());
  /// app.register(RouteServiceProvider());
  /// app.boot(); // Boots all providers
  /// ```
  void register(ServiceProvider provider) {
    _providers.add(provider);
    provider.register();
  }

  /// Boot all registered service providers.
  ///
  /// This calls the `boot()` method on each provider. Boot methods are
  /// guaranteed to run after ALL providers have been registered, so you
  /// can safely resolve services from other providers here.
  ///
  /// Typically called once after all providers are registered:
  ///
  /// ```dart
  /// // In your main.dart
  /// void main() async {
  ///   final app = MagicApp.instance;
  ///
  ///   // Register phase
  ///   app.register(AuthServiceProvider());
  ///   app.register(RouteServiceProvider());
  ///
  ///   // Boot phase
  ///   await app.boot();
  ///
  ///   runApp(MyApp());
  /// }
  /// ```
  Future<void> boot() async {
    if (_booted) return;

    for (final provider in _providers) {
      await provider.boot();
    }

    _booted = true;
  }

  /// Check if the application has been booted.
  bool get isBooted => _booted;

  // ---------------------------------------------------------------------------
  // Testing & Reset
  // ---------------------------------------------------------------------------

  /// Flush the container, clearing all bindings and instances.
  ///
  /// Primarily useful for testing to reset the container between tests:
  ///
  /// ```dart
  /// tearDown(() {
  ///   MagicApp.instance.flush();
  /// });
  /// ```
  void flush() {
    _bindings.clear();
    _instances.clear();
    _providers.clear();
    _booted = false;
  }

  /// Reset the singleton instance.
  ///
  /// Use with caution - this destroys the entire application instance.
  /// Only useful in specific testing scenarios.
  static void reset() {
    _instance?.flush();
    _instance = null;
    _initialized = false;
    _config.flush();
  }
}

/// Internal class to store binding metadata.
class _Binding {
  /// The factory function that creates the service.
  final Function factory;

  /// Whether this is a shared (singleton) binding.
  final bool shared;

  _Binding(this.factory, this.shared);
}
