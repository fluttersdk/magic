import '../contracts/rule.dart';

/// The Date Rule.
///
/// Validates that the field is a [DateTime] or a string [DateTime.tryParse]
/// accepts. Mirrors the intent of Laravel's `date` rule, scoped to what Dart
/// can parse without PHP's `strtotime` grammar.
///
/// ## Usage
///
/// ```dart
/// validate(data, {
///   'startsAt': [Required(), Date()],
/// });
/// ```
class Date extends Rule {
  /// Creates a [Date] rule. Const, because it carries no state.
  const Date();

  @override
  bool passes(String attribute, dynamic value, Map<String, dynamic> data) {
    if (value == null) return true; // Let Required handle null
    if (value is DateTime) return true;

    if (value is String) {
      if (value.isEmpty) return true; // Let Required handle empty
      return DateTime.tryParse(value) != null;
    }

    return false;
  }

  @override
  String message() => 'validation.date';
}
