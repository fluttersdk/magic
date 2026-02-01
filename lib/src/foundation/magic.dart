import 'package:flutter/widgets.dart';

import '../database/seeding/seeder.dart';
import '../facades/config.dart';
import '../facades/log.dart';
import '../logging/log_manager.dart';
import '../routing/magic_router.dart';
import '../support/service_provider.dart';
import '../ui/magic_feedback.dart';
import '../ui/magic_view_registry.dart';
import 'application.dart';
import 'env.dart';
import 'magic_app_widget.dart';

/// The Magic Facade.
///
/// This is your global entry point to the Magic framework. Instead of
/// accessing `MagicApp.instance` directly, you can use the cleaner `Magic`
/// facade for common operations.
///
/// ## Service Container Access
///
/// ```dart
/// // Bind a service
/// Magic.bind('api', () => ApiService());
///
/// // Register a singleton
/// Magic.singleton('cache', () => CacheManager());
///
/// // Resolve a service
/// final api = Magic.make<ApiService>('api');
/// ```
///
/// ## Global UI Feedback (Context-Free!)
///
/// ```dart
/// Magic.snackbar('Success', 'User created!');
/// Magic.dialog(ConfirmDialog());
/// Magic.loading();
/// Magic.closeLoading();
/// ```
class Magic {
  // Prevent instantiation
  Magic._();

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Initialize the Magic framework.
  ///
  /// This bootstraps the application, loads environment variables,
  /// initializes storage, and registers core services.
  ///
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await Magic.init(configs: [appConfig]);
  ///   runApp(const MagicApplication());
  /// }
  /// ```
  static Future<void> init({
    String envFileName = '.env',
    List<Map<String, dynamic>> configs = const [],
    List<Map<String, dynamic> Function()> configFactories = const [],
    List<ServiceProvider> providers = const [],
  }) async {
    // 1. Load Environment Variables (Must be first!)
    await Env.load(fileName: envFileName);

    // 2. Evaluate config factories now that Env is loaded
    final factoryConfigs = configFactories.map((f) => f()).toList();
    final allConfigs = [...configs, ...factoryConfigs];

    // 3. Initialize MagicApp
    await MagicApp.init(envFileName: envFileName, configs: allConfigs);

    // 2. Bind Core Services (before providers so they can use Log)
    app.singleton('log', () => LogManager());

    // 3. Register Core Providers
    // register(CacheServiceProvider(app));
    // register(EncryptionServiceProvider(app));
    // register(DatabaseServiceProvider(app));

    // 4. Register Configured Providers
    final configuredProviders = Config.get('app.providers', []) as List;
    for (final factory in configuredProviders) {
      if (factory is ServiceProvider Function(MagicApp)) {
        register(factory(app));
      }
    }

    // 5. Register Runtime Providers
    for (final provider in providers) {
      register(provider);
    }

    // 6. Boot Framework (Async)
    await boot();

    // 7. Pre-build router to ensure it's ready before runApp
    // This prevents "Could not navigate to initial route" errors on Flutter Web
    final _ = MagicRouter.instance.routerConfig;

    Log.info('Magic framework initialized');
  }

  // ---------------------------------------------------------------------------
  // Application Access
  // ---------------------------------------------------------------------------

  /// Get the application container instance.
  ///
  /// Equivalent to Laravel's `app()` helper.
  ///
  /// ```dart
  /// final app = Magic.app;
  /// app.register(MyServiceProvider(app));
  /// ```
  static MagicApp get app => MagicApp.instance;

  // ---------------------------------------------------------------------------
  // Service Container Shortcuts
  // ---------------------------------------------------------------------------

  /// Bind a service into the container.
  ///
  /// ```dart
  /// Magic.bind('logger', () => Logger());
  /// ```
  ///
  /// See [MagicApp.bind] for more details.
  static void bind(String key, Function closure, {bool shared = false}) {
    app.bind(key, closure, shared: shared);
  }

  /// Register a singleton service.
  ///
  /// ```dart
  /// Magic.singleton('database', () => DatabaseConnection());
  /// ```
  ///
  /// See [MagicApp.singleton] for more details.
  static void singleton(String key, Function closure) {
    app.singleton(key, closure);
  }

  /// Resolve a service from the container.
  ///
  /// ```dart
  /// final db = Magic.make<DatabaseConnection>('database');
  /// ```
  ///
  /// See [MagicApp.make] for more details.
  static T make<T>(String key) {
    return app.make<T>(key);
  }

  /// Check if a service is bound in the container.
  ///
  /// ```dart
  /// if (Magic.bound('cache')) {
  ///   final cache = Magic.make<CacheService>('cache');
  /// }
  /// ```
  static bool bound(String key) {
    return app.bound(key);
  }

  /// Register a service provider.
  ///
  /// ```dart
  /// Magic.register(AuthServiceProvider(Magic.app));
  /// ```
  static void register(ServiceProvider provider) {
    app.register(provider);
  }

  /// Boot all registered service providers.
  ///
  /// ```dart
  /// Magic.boot();
  /// ```
  static Future<void> boot() async {
    await app.boot();
  }

  /// Flush the container (useful for testing).
  ///
  /// ```dart
  /// tearDown(() => Magic.flush());
  /// ```
  static void flush() {
    app.flush();
    _controllers.clear();
  }

  // ---------------------------------------------------------------------------
  // Controller Management (MVC)
  // ---------------------------------------------------------------------------

  /// Controller instances by type.
  static final Map<Type, dynamic> _controllers = {};

  /// Register a controller instance.
  ///
  /// ```dart
  /// Magic.put(UserController());
  /// ```
  static T put<T>(T controller) {
    _controllers[T] = controller;
    return controller;
  }

  /// Find a controller by type.
  ///
  /// ```dart
  /// final user = Magic.find<UserController>();
  /// ```
  static T find<T>() {
    final controller = _controllers[T];
    if (controller == null) {
      throw Exception('Controller $T not found. Did you call Magic.put()?');
    }
    return controller as T;
  }

  /// Delete a controller.
  ///
  /// ```dart
  /// Magic.delete<UserController>();
  /// ```
  static void delete<T>() {
    _controllers.remove(T);
  }

  /// Check if a controller exists.
  ///
  /// ```dart
  /// if (Magic.isRegistered<UserController>()) {...}
  /// ```
  static bool isRegistered<T>() {
    return _controllers.containsKey(T);
  }

  /// Find a controller or register it if not found.
  ///
  /// Helper for lazy singleton accessors.
  ///
  /// ```dart
  /// static AuthController get instance => Magic.findOrPut(AuthController.new);
  /// ```
  static T findOrPut<T>(T Function() builder) {
    if (isRegistered<T>()) {
      return find<T>();
    }
    return put<T>(builder());
  }

  // ---------------------------------------------------------------------------
  // View Registry
  // ---------------------------------------------------------------------------

  /// Access the view registry to customize UI components.
  ///
  /// ```dart
  /// Magic.view.setLoadingBuilder((context, message) {
  ///   return MyCustomLoadingWidget();
  /// });
  /// ```
  static MagicViewRegistry get view => MagicViewRegistry.instance;

  // ---------------------------------------------------------------------------
  // Global UI Helpers (Context-Free!)
  // ---------------------------------------------------------------------------

  /// Show a snackbar notification.
  ///
  /// Can be called from anywhere - controllers, services, or pure Dart classes.
  ///
  /// ```dart
  /// Magic.snackbar('Success', 'User created!');
  /// Magic.snackbar('Error', 'Failed', type: 'error');
  /// ```
  static void snackbar(
    String title,
    String message, {
    String type = 'info',
    Duration? duration,
  }) {
    MagicFeedback.showSnackbar(title, message, type: type, duration: duration);
  }

  /// Show a success snackbar.
  ///
  /// ```dart
  /// Magic.success('Done', 'Profile updated');
  /// ```
  static void success(String title, String message) {
    MagicFeedback.success(title, message);
  }

  /// Show an error snackbar.
  ///
  /// ```dart
  /// Magic.error('Error', 'Failed to save');
  /// ```
  static void error(String title, String message) {
    MagicFeedback.error(title, message);
  }

  /// Show a toast notification.
  ///
  /// A lighter alternative to snackbar for brief messages.
  ///
  /// ```dart
  /// Magic.toast('Copied to clipboard');
  /// ```
  static void toast(String message,
      {Duration duration = const Duration(seconds: 2)}) {
    MagicFeedback.toast(message, duration: duration);
  }

  /// Show a custom dialog.
  ///
  /// ```dart
  /// Magic.dialog(
  ///   AlertDialog(
  ///     title: Text('Confirm'),
  ///     content: Text('Are you sure?'),
  ///     actions: [...],
  ///   ),
  /// );
  /// ```
  static Future<T?> dialog<T>(
    Widget dialog, {
    bool barrierDismissible = true,
  }) {
    return MagicFeedback.showCustomDialog<T>(
      dialog,
      barrierDismissible: barrierDismissible,
    );
  }

  /// Close the currently open dialog.
  ///
  /// ```dart
  /// Magic.closeDialog();
  /// ```
  static void closeDialog() {
    MagicFeedback.closeDialog();
  }

  /// Show a confirmation dialog.
  ///
  /// Returns `true` if confirmed, `false` if cancelled.
  ///
  /// ```dart
  /// final confirmed = await Magic.confirm(
  ///   title: 'Delete User',
  ///   message: 'Are you sure?',
  /// );
  /// if (confirmed) deleteUser();
  /// ```
  static Future<bool> confirm({
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDangerous = false,
  }) {
    return MagicFeedback.confirm(
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      isDangerous: isDangerous,
    );
  }

  /// Show a loading dialog.
  ///
  /// ```dart
  /// Magic.loading();
  /// await someAsyncOperation();
  /// Magic.closeLoading();
  /// ```
  static void loading({String? message}) {
    MagicFeedback.showLoading(message: message);
  }

  /// Close the loading dialog.
  ///
  /// ```dart
  /// Magic.closeLoading();
  /// ```
  static void closeLoading() {
    MagicFeedback.closeLoading();
  }

  /// Check if a loading dialog is currently shown.
  static bool get isLoading => MagicFeedback.isLoading;

  // ---------------------------------------------------------------------------
  // App Control
  // ---------------------------------------------------------------------------

  /// Restart the application.
  ///
  /// Triggers a full rebuild of the widget tree without a hot restart.
  ///
  /// ```dart
  /// Magic.reload();
  /// ```
  static void reload() {
    MagicAppWidget.restart();
  }

  // ---------------------------------------------------------------------------
  // Database Seeding
  // ---------------------------------------------------------------------------

  /// Run database seeders.
  ///
  /// This is the primary way to seed your database in Flutter apps.
  /// Call this in your `main.dart` during development.
  ///
  /// ```dart
  /// void main() async {
  ///   await Magic.init(...);
  ///
  ///   // Seed database in development
  ///   if (kDebugMode) {
  ///     await Magic.seed([DatabaseSeeder()]);
  ///   }
  ///
  ///   runApp(MagicApplication(...));
  /// }
  /// ```
  ///
  /// Or seed specific factories:
  ///
  /// ```dart
  /// await Magic.seed([UserSeeder(), TodoSeeder()]);
  /// ```
  static Future<void> seed(List<Seeder> seeders) async {
    Log.info('🌱 Starting database seeding...');
    for (final seeder in seeders) {
      await seeder.run();
    }
    Log.info('✅ Database seeding complete');
  }
}
