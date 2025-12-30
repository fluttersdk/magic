import '../contracts/rule.dart';

/// The Max Rule.
///
/// Validates that a string has at most a maximum number of characters,
/// or that a numeric value is at most a maximum value.
///
/// ## Usage
///
/// ```dart
/// validate(data, {
///   'username': [Required(), Max(20)],
///   'quantity': [Required(), Max(100)],
/// });
/// ```
///
/// ## Type Handling
///
/// - **String**: Checks character length
/// - **num** (int/double): Checks numeric value
/// - **List**: Checks item count
class Max extends Rule {
  /// The maximum value/length.
  final num max;

  /// The detected type of the value (string, numeric, list).
  String _type = 'string';

  /// Create a Max rule.
  ///
  /// [max] The maximum length for strings or maximum value for numbers.
  Max(this.max);

  @override
  bool passes(String attribute, dynamic value, Map<String, dynamic> data) {
    if (value == null) return true; // Let Required handle null

    if (value is String) {
      _type = 'string';
      if (value.isEmpty) return true; // Let Required handle empty
      return value.length <= max;
    }

    if (value is num) {
      _type = 'numeric';
      return value <= max;
    }

    if (value is List) {
      _type = 'list';
      return value.length <= max;
    }

    return false;
  }

  @override
  String message() => 'validation.max.$_type';

  @override
  Map<String, dynamic> params() => {'max': max};
}
