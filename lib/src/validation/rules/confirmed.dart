import '../contracts/rule.dart';

/// The Confirmed Rule.
///
/// Validates that the field has a matching `{field}_confirmation` field.
/// This is the Laravel convention for password confirmation, email confirmation, etc.
///
/// ## Usage
///
/// ```dart
/// validate({
///   'password': 'secret123',
///   'password_confirmation': 'secret123',
/// }, {
///   'password': [Required(), Min(8), Confirmed()],
/// });
/// ```
///
/// ## How It Works
///
/// For a field named `password`, this rule looks for `password_confirmation`
/// in the data and ensures both values match exactly.
class Confirmed extends Rule {
  @override
  bool passes(String attribute, dynamic value, Map<String, dynamic> data) {
    if (value == null) return true; // Let Required handle null

    final confirmationKey = '${attribute}_confirmation';
    final confirmationValue = data[confirmationKey];

    return value == confirmationValue;
  }

  @override
  String message() => 'validation.confirmed';
}
