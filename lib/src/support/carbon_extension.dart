import 'carbon.dart';

/// Extension to convert DateTime to Carbon.
extension ToCarbon on DateTime {
  /// Convert this DateTime to a Carbon instance.
  ///
  /// ```dart
  /// final date = DateTime.now().toCarbon();
  /// print(date.diffForHumans());
  /// ```
  Carbon toCarbon() => Carbon.fromDateTime(this);

  /// Whether this moment falls on the same calendar day as [other].
  ///
  /// ```dart
  /// DateTime(2024, 6, 20, 9).isSameDayAs(DateTime(2024, 6, 20, 23)); // true
  /// ```
  bool isSameDayAs(DateTime other) => month == other.month && day == other.day;
}
