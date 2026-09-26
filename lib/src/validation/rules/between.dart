import '../contracts/rule.dart';

/// The Between Rule.
///
/// Validates that a string's length, a numeric value, or a list's item
/// count falls within an inclusive `[min, max]` range. Mirrors Laravel's
/// `between:min,max` rule, and [Min]/[Max]'s type split.
///
/// ## Usage
///
/// ```dart
/// validate(data, {
///   'password': [Required(), Between(8, 64)],
/// });
/// ```
class Between extends Rule {
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
  bool passes(String attribute, dynamic value, Map<String, dynamic> data) {
    if (value == null) return true; // Let Required handle null

    if (value is String) {
      _type = 'string';
      if (value.isEmpty) return true; // Let Required handle empty
      return value.length >= min && value.length <= max;
    }

    if (value is num) {
      _type = 'numeric';
      return value >= min && value <= max;
    }

    if (value is List) {
      _type = 'list';
      return value.length >= min && value.length <= max;
    }

    return false;
  }

  @override
  String message() => 'validation.between.$_type';

  @override
  Map<String, dynamic> params() => {'min': min, 'max': max};
}
