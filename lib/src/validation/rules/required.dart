import '../contracts/rule.dart';

/// The Required Rule.
///
/// Validates that the field is present and not empty. Works with strings,
/// lists, maps, and any other value type.
///
/// ## Usage
///
/// ```dart
/// validate(data, {
///   'name': [Required()],
///   'email': [Required()],
/// });
/// ```
///
/// ## Failure Conditions
///
/// This rule fails when the value is:
/// - `null`
/// - An empty string (`''`) or whitespace-only string
/// - An empty List (`[]`)
/// - An empty Map (`{}`)
/// - A boolean `false` (useful for checkboxes like "I agree to terms")
class Required extends Rule {
  @override
  bool passes(String attribute, dynamic value, Map<String, dynamic> data) {
    if (value == null) return false;

    if (value is String) {
      return value.trim().isNotEmpty;
    }

    if (value is List) {
      return value.isNotEmpty;
    }

    if (value is Map) {
      return value.isNotEmpty;
    }

    // For bool, false is considered "not provided" (like unchecked checkbox)
    if (value is bool) {
      return value;
    }

    return true;
  }

  @override
  String message() => 'validation.required';
}
