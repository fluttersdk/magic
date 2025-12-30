import '../foundation/magic.dart';
import '../logging/log_manager.dart';

/// The Log Facade.
///
/// Provides static access to the logging system. Supports all RFC 5424 levels.
///
/// ```dart
/// Log.info('User logged in', {'id': userId});
/// Log.error('Payment failed', {'error': e.toString()});
/// ```
class Log {
  static LogManager get _manager => Magic.make<LogManager>('log');

  /// Log a message at a given level.
  static void log(String level, String message, [dynamic context]) =>
      _manager.driver().log(level, message, context);

  /// System is unusable.
  static void emergency(String message, [dynamic context]) =>
      _manager.driver().emergency(message, context);

  /// Action must be taken immediately.
  static void alert(String message, [dynamic context]) =>
      _manager.driver().alert(message, context);

  /// Critical conditions.
  static void critical(String message, [dynamic context]) =>
      _manager.driver().critical(message, context);

  /// Runtime errors that do not require immediate action.
  static void error(String message, [dynamic context]) =>
      _manager.driver().error(message, context);

  /// Exceptional occurrences that are not errors.
  static void warning(String message, [dynamic context]) =>
      _manager.driver().warning(message, context);

  /// Normal but significant events.
  static void notice(String message, [dynamic context]) =>
      _manager.driver().notice(message, context);

  /// Interesting events.
  static void info(String message, [dynamic context]) =>
      _manager.driver().info(message, context);

  /// Detailed debug information.
  static void debug(String message, [dynamic context]) =>
      _manager.driver().debug(message, context);

  /// Get a specific channel.
  ///
  /// ```dart
  /// Log.channel('slack').error('Server down!');
  /// ```
  static LogManager channel(String name) => _manager;
}
