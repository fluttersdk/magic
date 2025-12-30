import '../contracts/rule.dart';

/// The Accepted Rule.
///
/// Validates that the field was "accepted" - useful for terms of service,
/// agreement checkboxes, and similar boolean confirmations.
///
/// ## Usage
///
/// ```dart
/// validate({
///   'terms': true,
///   'newsletter': 'yes',
/// }, {
///   'terms': [Accepted()],
/// });
/// ```
///
/// ## Accepted Values
///
/// The following values are considered "accepted":
/// - `true` (boolean)
/// - `1` (int)
/// - `"1"` (string)
/// - `"yes"` (case-insensitive)
/// - `"on"` (case-insensitive)
/// - `"true"` (case-insensitive)
class Accepted extends Rule {
  /// Values considered as "accepted".
  static const List<dynamic> _acceptedValues = [
    true,
    1,
    '1',
    'yes',
    'on',
    'true',
  ];

  @override
  bool passes(String attribute, dynamic value, Map<String, dynamic> data) {
    if (value == null) return false;

    // Handle string comparison case-insensitively
    if (value is String) {
      return _acceptedValues.contains(value.toLowerCase());
    }

    return _acceptedValues.contains(value);
  }

  @override
  String message() => 'validation.accepted';
}
