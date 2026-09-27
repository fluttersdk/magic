import '../contracts/rule.dart';

/// The Integer Rule.
///
/// Validates that the field is an integer, an integer-looking string, or a
/// double with no fractional part. Mirrors Laravel's `integer` rule
/// (`FILTER_VALIDATE_INT`), which passes a float like `5.0` because PHP casts
/// it to the string `"5"` before filtering; a Dart `double` gets the same
/// answer here by checking it against its own truncated value instead.
///
/// ## Usage
///
/// ```dart
/// validate(data, {
///   'quantity': [Required(), Integer()],
/// });
/// ```
class Integer extends Rule {
  /// Creates an [Integer] rule. Const, because it carries no state.
  const Integer();

  @override
  bool passes(String attribute, dynamic value, Map<String, dynamic> data) {
    if (value == null) return true; // Let Required handle null
    if (value is int) return true;
    if (value is double) return value == value.truncateToDouble();

    if (value is String) {
      if (value.isEmpty) return true; // Let Required handle empty
      return int.tryParse(value) != null;
    }

    return false;
  }

  @override
  String message() => 'validation.integer';
}
