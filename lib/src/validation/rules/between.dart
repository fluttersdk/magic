import '../contracts/size_rule.dart';

/// The Between Rule.
///
/// Validates that a string's length, a numeric value, or a list's item
/// count falls within an inclusive `[min, max]` range. Mirrors Laravel's
/// `between:min,max` rule, and [Min]/[Max]'s type split: a string is sized
/// by its value only beside `Numeric` or `Integer` (see [SizeRule]).
///
/// ## Usage
///
/// ```dart
/// validate(data, {
///   'password': [Required(), Between(8, 64)],
/// });
/// ```
class Between extends SizeRule {
  /// The inclusive lower bound.
  final num min;

  /// The inclusive upper bound.
  final num max;

  /// The detected type of the value (string, numeric, list).
  String _type = 'string';

  /// Create a Between rule.
  ///
  /// [min] The inclusive lower bound. [max] The inclusive upper bound.
  Between(this.min, this.max);

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
    return sized.$1 >= min && sized.$1 <= max;
  }

  @override
  String message() => 'validation.between.$_type';

  @override
  Map<String, dynamic> params() => {'min': min, 'max': max};
}
