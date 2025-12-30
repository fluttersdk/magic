import 'package:logger/logger.dart' as lgr;

import '../contracts/logger_driver.dart';

/// The Console Logger Driver.
///
/// Uses the `logger` package to print pretty logs to the console.
/// Respects the configured minimum log level.
class ConsoleLoggerDriver extends LoggerDriver {
  final lgr.Logger _logger;
  final String minLevel;

  /// Log level priority (RFC 5424).
  static const Map<String, int> _levels = {
    'emergency': 0,
    'alert': 1,
    'critical': 2,
    'error': 3,
    'warning': 4,
    'notice': 5,
    'info': 6,
    'debug': 7,
  };

  /// Create a new console logger driver.
  ///
  /// [minLevel] is the minimum level to log (default: 'debug').
  ConsoleLoggerDriver({this.minLevel = 'debug'})
      : _logger = lgr.Logger(
          printer: lgr.PrettyPrinter(
            methodCount: 0,
            errorMethodCount: 5,
            lineLength: 80,
            colors: true,
            printEmojis: true,
          ),
        );

  @override
  void log(String level, String message, [dynamic context]) {
    // Check if this level should be logged
    final levelPriority = _levels[level] ?? 7;
    final minPriority = _levels[minLevel] ?? 7;

    if (levelPriority > minPriority) return;

    final logMessage = context != null ? '$message\n$context' : message;

    switch (level) {
      case 'emergency':
      case 'alert':
      case 'critical':
        _logger.f(logMessage);
        break;
      case 'error':
        _logger.e(logMessage);
        break;
      case 'warning':
        _logger.w(logMessage);
        break;
      case 'notice':
      case 'info':
        _logger.i(logMessage);
        break;
      case 'debug':
      default:
        _logger.d(logMessage);
        break;
    }
  }
}
