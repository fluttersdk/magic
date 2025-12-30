/// The Logger Driver interface.
///
/// All logging drivers must implement this interface to ensure consistent
/// behavior across different logging backends. Supports all RFC 5424 levels.
abstract class LoggerDriver {
  /// Log a message at a given level.
  ///
  /// [level] is one of: emergency, alert, critical, error, warning, notice, info, debug.
  /// [message] is the log message.
  /// [context] is optional additional data (Map, List, or any object).
  void log(String level, String message, [dynamic context]);

  /// System is unusable.
  void emergency(String message, [dynamic context]) =>
      log('emergency', message, context);

  /// Action must be taken immediately.
  void alert(String message, [dynamic context]) =>
      log('alert', message, context);

  /// Critical conditions.
  void critical(String message, [dynamic context]) =>
      log('critical', message, context);

  /// Runtime errors that do not require immediate action.
  void error(String message, [dynamic context]) =>
      log('error', message, context);

  /// Exceptional occurrences that are not errors.
  void warning(String message, [dynamic context]) =>
      log('warning', message, context);

  /// Normal but significant events.
  void notice(String message, [dynamic context]) =>
      log('notice', message, context);

  /// Interesting events.
  void info(String message, [dynamic context]) => log('info', message, context);

  /// Detailed debug information.
  void debug(String message, [dynamic context]) =>
      log('debug', message, context);
}
