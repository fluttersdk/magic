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
}
