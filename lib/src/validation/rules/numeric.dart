import '../contracts/rule.dart';

/// The Numeric Rule.
///
/// Validates that the field is a `num` or a numeric string. Mirrors
/// Laravel's `numeric` rule (`is_numeric`).
///
/// ## Usage
///
/// ```dart
/// validate(data, {
///   'price': [Required(), Numeric()],
/// });
/// ```
class Numeric extends Rule {
  /// Creates a [Numeric] rule. Const, because it carries no state.
  const Numeric();

  @override
  bool passes(String attribute, dynamic value, Map<String, dynamic> data) {
    if (value == null) return true; // Let Required handle null
    if (value is num) return true;

    if (value is String) {
      if (value.isEmpty) return true; // Let Required handle empty
      return num.tryParse(value) != null;
    }

    return false;
  }

  @override
  String message() => 'validation.numeric';
}
