import '../logging/contracts/logger_driver.dart';
import '../logging/log_manager.dart';

/// A single captured log entry.
typedef FakeLogEntry = ({String level, String message, dynamic context});

/// A fake [LogManager] for testing.
///
/// Captures all log calls in memory instead of writing to console.
/// Provides assertion helpers for verifying expected log activity.
///
/// ```dart
/// final fake = Log.fake();
///
/// Log.error('Payment failed');
///
/// fake.assertLoggedError('Payment failed');
/// fake.assertLoggedCount(1);
/// ```
class FakeLogManager extends LogManager {
  final _FakeLoggerDriver _driver = _FakeLoggerDriver();

  /// All captured log entries in chronological order.
  List<FakeLogEntry> get entries => List.unmodifiable(_driver._entries);

  @override
  LoggerDriver driver([String? channel]) => _driver;

  // ---------------------------------------------------------------------------
  // Assertions
  // ---------------------------------------------------------------------------

  /// Assert that at least one entry matches both [level] and [message].
  ///
  /// Throws [AssertionError] if no matching entry is found.
  void assertLogged(String level, String message) {
    final matched = _driver._entries.any(
      (e) => e.level == level && e.message == message,
    );

    if (!matched) {
      throw AssertionError(
        'Expected a log entry at level "$level" with message "$message" '
        'but none was found.',
      );
    }
  }

  /// Assert that at least one error-level entry matches [message].
  ///
  /// Shorthand for `assertLogged('error', message)`.
  void assertLoggedError(String message) => assertLogged('error', message);

  /// Assert that no entries exist, or no entries exist at [level].
  ///
  /// If [level] is null, asserts the log is completely empty.
  /// If [level] is provided, asserts no entries exist at that level.
  ///
  /// Throws [AssertionError] on failure.
  void assertNothingLogged([String? level]) {
    if (level == null) {
      if (_driver._entries.isNotEmpty) {
        throw AssertionError(
          'Expected no log entries but ${_driver._entries.length} were recorded.',
        );
      }
    } else {
      final atLevel = _driver._entries.where((e) => e.level == level).toList();
      if (atLevel.isNotEmpty) {
        throw AssertionError(
          'Expected no log entries at level "$level" but '
          '${atLevel.length} were recorded.',
        );
      }
    }
  }

  /// Assert that exactly [expected] entries were recorded in total.
  ///
  /// Throws [AssertionError] if the count does not match.
  void assertLoggedCount(int expected) {
    final actual = _driver._entries.length;
    if (actual != expected) {
      throw AssertionError(
        'Expected $expected log entries but $actual were recorded.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Reset
  // ---------------------------------------------------------------------------

  /// Clear all captured entries.
  void reset() => _driver._entries.clear();
}

// ---------------------------------------------------------------------------
// Internal fake driver — captures entries, no console output
// ---------------------------------------------------------------------------

class _FakeLoggerDriver extends LoggerDriver {
  final List<FakeLogEntry> _entries = [];

  @override
  void log(String level, String message, [dynamic context]) {
    _entries.add((level: level, message: message, context: context));
  }
}
