import '../contracts/rule.dart';

/// The Email Rule.
///
/// Validates that the field is a valid email address format.
///
/// ## Usage
///
/// ```dart
/// validate(data, {
///   'email': [Required(), Email()],
/// });
/// ```
///
/// ## Validation Pattern
///
/// Uses a standard email regex that validates:
/// - Local part (before @)
/// - @ symbol
/// - Domain part with at least one dot
class Email extends Rule {
  /// Standard email validation regex.
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    caseSensitive: false,
  );

  @override
  bool passes(String attribute, dynamic value, Map<String, dynamic> data) {
    if (value == null) return true; // Let Required handle null
    if (value is! String) return false;
    if (value.isEmpty) return true; // Let Required handle empty

    return _emailRegex.hasMatch(value);
  }

  @override
  String message() => 'validation.email';
}
