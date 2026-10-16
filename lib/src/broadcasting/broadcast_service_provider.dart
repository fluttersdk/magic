import 'dart:async';

import '../facades/config.dart';
import '../facades/log.dart';
import '../network/contracts/network_driver.dart';
import '../support/service_provider.dart';
import 'broadcast_manager.dart';
import 'socket_id_interceptor.dart';

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
  /// `app.make<BroadcastManager>('broadcasting')` or the `Echo` facade.
  @override
  void register() {
    app.singleton('broadcasting', () => BroadcastManager());
  }

  /// Starts connecting the default broadcast connection, without waiting.
  ///
  /// Skips the connection attempt when `broadcasting.default` is `'null'`
  /// to avoid unnecessary work during local development or testing.
  ///
  /// Also adds a [SocketIdInterceptor] to the network driver, so Laravel's
  /// `toOthers()` can tell which socket made a request. It is skipped for the
  /// `'null'` connection, which never has a socket id, and when no network
  /// driver is bound (add `NetworkServiceProvider` to receive the header).
  ///
  /// Not awaited, and a failure is logged rather than thrown. Boot used to
  /// wait for the socket, so a server that refused it failed every provider
  /// after this one and the app never drew a frame, and a server that never
  /// answered held the app at launch for the whole connection timeout. A
  /// realtime socket is an enhancement over a working app: the driver keeps
  /// retrying on its own, and a caller that needs the connection awaits
  /// `Echo.connect()`, which joins the attempt in flight.
  @override
  Future<void> boot() async {
    final manager = app.make<BroadcastManager>('broadcasting');
    final defaultConnection = Config.get<String>(
      'broadcasting.default',
      'null',
    );

    if (defaultConnection == 'null') return;

    if (app.bound('network')) {
      app.make<NetworkDriver>('network').addInterceptor(SocketIdInterceptor());
    }

    unawaited(
      manager.connection().connect().catchError((Object error) {
        Log.warning(
          'Broadcasting could not connect at boot ($error); the driver '
          'keeps retrying.',
        );
      }),
    );
  }
}
