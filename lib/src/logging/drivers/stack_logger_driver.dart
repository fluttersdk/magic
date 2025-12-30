import '../contracts/logger_driver.dart';

/// The Stack Logger Driver.
///
/// Sends logs to multiple channels simultaneously. This allows logging
/// to both the console and a remote server (or file) at once.
class StackLoggerDriver extends LoggerDriver {
  final List<LoggerDriver> _channels;

  /// Create a new stack driver with the given channels.
  StackLoggerDriver(this._channels);

  @override
  void log(String level, String message, [dynamic context]) {
    for (final channel in _channels) {
      channel.log(level, message, context);
    }
  }
}
