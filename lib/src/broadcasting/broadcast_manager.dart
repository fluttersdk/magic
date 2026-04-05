import '../facades/config.dart';
import 'contracts/broadcast_driver.dart';
import 'drivers/null_broadcast_driver.dart';
import 'drivers/reverb_broadcast_driver.dart';

/// The Broadcast Manager.
///
/// Resolves the configured broadcasting connection and returns the appropriate
/// driver. Follows the same manager pattern as [LogManager] and [CacheManager].
///
/// ```dart
/// final driver = BroadcastManager().connection();
/// await driver.connect();
/// ```
class BroadcastManager {
  BroadcastDriver? _cachedConnection;

  static final Map<String, BroadcastDriver Function(Map<String, dynamic>)>
  _customDrivers = {};

  /// Register a custom broadcast driver factory.
  ///
  /// ```dart
  /// BroadcastManager.extend(
  ///   'pusher',
  ///   (config) => PusherBroadcastDriver(config),
  /// );
  /// ```
  static void extend(
    String name,
    BroadcastDriver Function(Map<String, dynamic> config) factory,
  ) {
    _customDrivers[name] = factory;
  }

  /// Reset all custom drivers (for testing).
  static void resetDrivers() {
    _customDrivers.clear();
  }

  /// Get the broadcast driver for the given [name], or the default connection.
  ///
  /// Calling without arguments returns (and caches) the default connection
  /// defined by `broadcasting.default` in config. Passing an explicit [name]
  /// resolves that named connection without affecting the cache.
  ///
  /// ```dart
  /// final driver = BroadcastManager().connection();          // default
  /// final reverb = BroadcastManager().connection('reverb'); // named
  /// ```
  BroadcastDriver connection([String? name]) {
    if (_cachedConnection != null && name == null) {
      return _cachedConnection!;
    }

    final connectionName =
        name ?? Config.get<String>('broadcasting.default', 'null')!;
    final resolved = _resolveConnection(connectionName);

    if (name == null) {
      _cachedConnection = resolved;
    }

    return resolved;
  }

  /// Resolve a connection by name from config.
  BroadcastDriver _resolveConnection(String name) {
    final connections =
        Config.get<Map<String, dynamic>>('broadcasting.connections') ?? {};
    final connectionConfig = connections[name] as Map<String, dynamic>? ?? {};
    final driverName = connectionConfig['driver'] as String? ?? 'null';

    if (_customDrivers.containsKey(driverName)) {
      return _customDrivers[driverName]!(connectionConfig);
    }

    switch (driverName) {
      case 'reverb':
        return ReverbBroadcastDriver(connectionConfig);
      case 'null':
      default:
        return _createNullDriver();
    }
  }

  /// Create a [NullBroadcastDriver] instance.
  BroadcastDriver _createNullDriver() => NullBroadcastDriver();
}
