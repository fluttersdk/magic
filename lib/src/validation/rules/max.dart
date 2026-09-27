import '../contracts/size_rule.dart';

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
/// - **String**: Checks character length, or its numeric value when the
///   attribute also carries `Numeric` or `Integer` (see [SizeRule])
/// - **num** (int/double): Checks numeric value
/// - **List**: Checks item count
class Max extends SizeRule {
  /// The maximum value/length.
  final num max;

  /// The detected type of the value (string, numeric, list).
  String _type = 'string';

  /// Create a Max rule.
  ///
  /// [max] The maximum length for strings or maximum value for numbers.
  Max(this.max);

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
    return sized.$1 <= max;
  }

  @override
  String message() => 'validation.max.$_type';

  @override
  Map<String, dynamic> params() => {'max': max};
}
