import '../support/carbon.dart';

/// Global helper to get current date/time.
///
/// ```dart
/// final now = carbonNow();
/// ```
Carbon carbonNow([String? timezone]) => Carbon.now(timezone);

/// Global helper to get today's date at start of day.
///
/// ```dart
/// final today = carbonToday();
/// ```
Carbon carbonToday() => Carbon.now().startOfDay();

/// Global helper to parse a date.
///
/// ```dart
/// final date = carbonParse('2024-01-15');
/// ```
Carbon carbonParse(dynamic value) {
  if (value is Carbon) return value;
  if (value is DateTime) return Carbon.fromDateTime(value);
  if (value is String) return Carbon.parse(value);
  throw ArgumentError('Cannot parse $value to Carbon');
}
