import '../support/service_provider.dart';
import 'launch_service.dart';

/// The Launch Service Provider.
///
/// Registers the `LaunchService` into the Magic IOC container under the key 'launch'.
class LaunchServiceProvider extends ServiceProvider {
  /// Create a new launch service provider instance.
  LaunchServiceProvider(super.app);

  @override
  void register() {
    app.singleton('launch', () => LaunchService());
  }

  @override
  Future<void> boot() async {}
}
