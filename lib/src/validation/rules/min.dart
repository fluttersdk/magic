import '../contracts/rule.dart';

/// The Min Rule.
///
/// Validates that a string has at least a minimum number of characters,
/// or that a numeric value is at least a minimum value.
///
/// ## Usage
///
/// ```dart
/// validate(data, {
///   'password': [Required(), Min(8)],
///   'age': [Required(), Min(18)],
/// });
/// ```
///
/// ## Type Handling
///
/// - **String**: Checks character length
/// - **num** (int/double): Checks numeric value
/// - **List**: Checks item count
class Min extends Rule {
  /// The minimum value/length.
  final num min;

  /// The detected type of the value (string, numeric, list).
  String _type = 'string';

  /// Create a Min rule.
  ///
  /// [min] The minimum length for strings or minimum value for numbers.
  Min(this.min);

  @override
  bool passes(String attribute, dynamic value, Map<String, dynamic> data) {
    if (value == null) return true; // Let Required handle null

    if (value is String) {
      _type = 'string';
      if (value.isEmpty) return true; // Let Required handle empty
      return value.length >= min;
    }

    if (value is num) {
      _type = 'numeric';
      return value >= min;
    }

    if (value is List) {
      _type = 'list';
      return value.length >= min;
    }

    return false;
  }

  @override
  String message() => 'validation.min.$_type';

  @override
  Map<String, dynamic> params() => {'min': min};
}
