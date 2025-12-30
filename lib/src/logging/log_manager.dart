import '../facades/config.dart';
import 'contracts/logger_driver.dart';
import 'drivers/console_logger_driver.dart';
import 'drivers/stack_logger_driver.dart';

/// The Log Manager.
///
/// Resolves the configured logging channel and returns the appropriate driver.
class LogManager {
  LoggerDriver? _cachedDriver;

  /// Get the default logger driver based on configuration.
  LoggerDriver driver([String? channel]) {
    if (_cachedDriver != null && channel == null) {
      return _cachedDriver!;
    }

    final channelName =
        channel ?? Config.get<String>('logging.default', 'console')!;
    final resolved = _resolveChannel(channelName);

    if (channel == null) {
      _cachedDriver = resolved;
    }

    return resolved;
  }

  /// Resolve a channel by name.
  LoggerDriver _resolveChannel(String name) {
    final channels = Config.get<Map<String, dynamic>>('logging.channels') ?? {};
    final channelConfig = channels[name] as Map<String, dynamic>? ?? {};
    final driverName = channelConfig['driver'] ?? 'console';

    switch (driverName) {
      case 'stack':
        return _createStackDriver(channelConfig);
      case 'console':
      default:
        return _createConsoleDriver(channelConfig);
    }
  }

  /// Create a console driver.
  LoggerDriver _createConsoleDriver(Map<String, dynamic> config) {
    return ConsoleLoggerDriver(
      minLevel: config['level'] ?? 'debug',
    );
  }

  /// Create a stack driver.
  LoggerDriver _createStackDriver(Map<String, dynamic> config) {
    final channelNames = (config['channels'] as List?)?.cast<String>() ?? [];
    final drivers = channelNames.map((name) => _resolveChannel(name)).toList();
    return StackLoggerDriver(drivers);
  }
}
