import '../facades/config.dart';
import '../support/service_provider.dart';
import 'broadcast_manager.dart';

/// Broadcast Service Provider.
///
/// Registers the [BroadcastManager] as a singleton in the service container
/// and, during the boot phase, auto-connects the default driver — unless the
/// configured default connection is `'null'`, in which case the connect step
/// is intentionally skipped.
///
/// This provider is **not** auto-registered. Add it explicitly to your
/// application's `providers` list, the same way as [EncryptionServiceProvider]:
///
/// ```dart
/// await Magic.init(
///   configs: [
///     {
///       'app': {
///         'providers': [
///           (app) => BroadcastServiceProvider(app),
///         ],
///       },
///     },
///   ],
/// );
/// ```
class BroadcastServiceProvider extends ServiceProvider {
  /// Creates the provider with a reference to the application container.
  BroadcastServiceProvider(super.app);

  /// Bind the [BroadcastManager] singleton into the service container.
  ///
  /// After this phase any other provider or service can resolve the manager via
  /// `app.make<BroadcastManager>('broadcasting')` or the `Broadcast` facade.
  @override
  void register() {
    app.singleton('broadcasting', () => BroadcastManager());
  }

  /// Auto-connect the default broadcast connection.
  ///
  /// Skips the connection attempt when `broadcasting.default` is `'null'`
  /// to avoid unnecessary work during local development or testing.
  @override
  Future<void> boot() async {
    final manager = app.make<BroadcastManager>('broadcasting');
    final defaultConnection = Config.get<String>(
      'broadcasting.default',
      'null',
    );

    if (defaultConnection != 'null') {
      await manager.connection().connect();
    }
  }
}
