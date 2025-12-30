import '../support/service_provider.dart';
import '../facades/log.dart';
import '../facades/config.dart';
import 'cache_manager.dart';

/// Cache Service Provider.
///
/// Registers the cache manager as a singleton in the service container.
/// The cache driver is initialized automatically during the boot phase.
class CacheServiceProvider extends ServiceProvider {
  CacheServiceProvider(super.app);

  @override
  void register() {
    app.singleton('cache', () => CacheManager());
  }

  @override
  Future<void> boot() async {
    final manager = app.make<CacheManager>('cache');
    await manager.driver().init();

    final cacheConfig = Config.get<Map<String, dynamic>>('cache', {});
    final defaultDriver = cacheConfig?['default'] ?? 'file';

    Log.info('Cache ready [$defaultDriver]');
  }
}
