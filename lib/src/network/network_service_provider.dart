import '../facades/config.dart';
import '../network/drivers/dio_network_driver.dart';
import '../support/service_provider.dart';

/// The Network Service Provider.
///
/// Registers the default network driver and applies configured interceptors.
class NetworkServiceProvider extends ServiceProvider {
  NetworkServiceProvider(super.app);

  @override
  void register() {
    app.singleton('network', () {
      final config =
          Config.get<Map<String, dynamic>>('network.drivers.api') ?? {};

      return DioNetworkDriver(
        baseUrl: config['base_url'] ?? '',
        timeout: config['timeout'] ?? 10000,
        defaultHeaders: Map<String, String>.from(config['headers'] ?? {}),
      );
    });
  }

  @override
  Future<void> boot() async {
    // Interceptors can be added here if resolved from container
    // final driver = app.make<NetworkDriver>('network');
    // final interceptors = Config.get<List>('network.drivers.api.interceptors') ?? [];
    // for (final factory in interceptors) {
    //   driver.addInterceptor(factory());
    // }
  }
}
