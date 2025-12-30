import '../foundation/application.dart';

/// The Service Provider Contract.
///
/// Service providers are the central place to configure your application.
/// All of the Magic framework's core services are bootstrapped via providers,
/// and you should do the same for your own services.
///
/// Think of providers as the "blueprint" for your modules. They tell the
/// framework: "Here's what services I offer, and here's how to boot them up."
///
/// ## Creating a Provider
///
/// ```dart
/// class AuthServiceProvider extends ServiceProvider {
///   AuthServiceProvider(super.app);
///
///   @override
///   void register() {
///     // Bind your services here
///     app.singleton('auth', () => AuthManager());
///     app.bind('guard', () => SessionGuard());
///   }
///
///   @override
///   void boot() {
///     // Run code after ALL providers are registered
///     final auth = app.make<AuthManager>('auth');
///     auth.configure();
///   }
/// }
/// ```
///
/// ## Registering Providers
///
/// Providers are registered in your application bootstrap:
///
/// ```dart
/// void main() {
///   final app = MagicApp.instance;
///
///   app.register(AuthServiceProvider(app));
///   app.register(RouteServiceProvider(app));
///
///   app.boot();
///   runApp(MyApp());
/// }
/// ```
///
/// ## The Lifecycle
///
/// 1. **Register Phase**: `register()` is called immediately when you
///    call `app.register(provider)`. Bind your services here.
///
/// 2. **Boot Phase**: `boot()` is called when you call `app.boot()`,
///    AFTER all providers have been registered. This is where you can
///    safely resolve services from other providers.
abstract class ServiceProvider {
  /// Reference to the application container.
  ///
  /// Use this to bind services and resolve dependencies:
  ///
  /// ```dart
  /// app.singleton('logger', () => Logger());
  /// app.make<Config>('config');
  /// ```
  final MagicApp app;

  /// Create a new service provider instance.
  ///
  /// The application container is injected automatically when you
  /// register the provider.
  ServiceProvider(this.app);

  /// Register any application services.
  ///
  /// This is where you should bind things into the service container.
  /// This method is called immediately when the provider is registered.
  ///
  /// ```dart
  /// @override
  /// void register() {
  ///   app.singleton('mailer', () => SmtpMailer());
  /// }
  /// ```
  void register();

  /// Bootstrap any application services.
  ///
  /// This method is called AFTER all providers have been registered,
  /// so you can safely resolve any service here.
  ///
  /// Override this method to perform any initialization that depends
  /// on other services being available.
  ///
  /// ```dart
  /// @override
  /// void boot() {
  ///   final config = app.make<Config>('config');
  ///   final mailer = app.make<Mailer>('mailer');
  ///   mailer.setDefaultFrom(config.get('mail.from'));
  /// }
  /// ```
  Future<void> boot() async {
    // Default implementation does nothing.
    // Override in subclasses if needed.
  }
}
