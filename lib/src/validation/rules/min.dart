import '../contracts/size_rule.dart';

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
/// - **String**: Checks character length, or its numeric value when the
///   attribute also carries `Numeric` or `Integer` (see [SizeRule])
/// - **num** (int/double): Checks numeric value
/// - **List**: Checks item count
class Min extends SizeRule {
  /// The minimum value/length.
  final num min;

  /// The detected type of the value (string, numeric, list).
  String _type = 'string';

  /// Create a Min rule.
  ///
  /// [min] The minimum length for strings or minimum value for numbers.
  Min(this.min);

  @override
  bool passesSized(
    String attribute,
    dynamic value,
    Map<String, dynamic> data, {
    required bool numeric,
  }) {
    if (value == null) return true; // Let Required handle null
    if (value is String && value.isEmpty) {
      return true; // Let Required handle empty
    }

    final sized = sizeOf(value, numeric: numeric);
    if (sized == null) return false;

    _type = sized.$2;
    return sized.$1 >= min;
  }

  @override
  String message() => 'validation.min.$_type';

  @override
  Map<String, dynamic> params() => {'min': min};
}
