import '../facades/gate.dart';
import '../support/service_provider.dart';

/// The Gate Service Provider.
///
/// This provider is responsible for registering authorization abilities
/// and policies. Extend this class to customize gate definitions.
///
/// ## Usage
///
/// 1. Create your provider:
///
/// ```dart
/// class AppGateServiceProvider extends GateServiceProvider {
///   AppGateServiceProvider(super.app);
///
///   @override
///   Future<void> boot() async {
///     await super.boot();
///
///     // Register super admin bypass
///     Gate.before((user, ability) {
///       if (user.isAdmin) return true;
///       return null;
///     });
///
///     // Register abilities
///     Gate.define('update-post', (user, post) => user.id == post.userId);
///     Gate.define('delete-post', (user, post) => user.isAdmin);
///
///     // Or use policies
///     PostPolicy().register();
///     CommentPolicy().register();
///   }
/// }
/// ```
///
/// 2. Register in `config/app.dart`:
///
/// ```dart
/// 'providers': [
///   (app) => AppGateServiceProvider(app),
/// ],
/// ```
class GateServiceProvider extends ServiceProvider {
  /// Create a new Gate service provider.
  GateServiceProvider(super.app);

  @override
  void register() {
    // Gate manager is eagerly created as a singleton
    app.bind('gate', () => Gate.manager);
  }

  @override
  Future<void> boot() async {
    // Override this method to register your abilities and policies
    //
    // Example:
    // Gate.define('update-post', (user, post) => user.id == post.userId);
    //
    // Or with before callback:
    // Gate.before((user, ability) {
    //   if (user.isAdmin) return true;
    //   return null;
    // });
  }
}
