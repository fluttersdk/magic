import '../contracts/rule.dart';

/// The Boolean Rule.
///
/// Validates that the field is a boolean or one of the loose forms a form
/// submits a checkbox as. Mirrors Laravel's `boolean` rule.
///
/// ## Usage
///
/// ```dart
/// validate(data, {
///   'acceptedTerms': [Required(), Boolean()],
/// });
/// ```
class Boolean extends Rule {
  /// Creates a [Boolean] rule. Const, because it carries no state.
  const Boolean();

  /// The exact set Laravel's `boolean` rule accepts.
  static const List<Object> _acceptable = [true, false, 0, 1, '0', '1'];

  @override
  bool passes(String attribute, dynamic value, Map<String, dynamic> data) {
    if (value == null) return true; // Let Required handle null

    return _acceptable.contains(value);
  }

  @override
  String message() => 'validation.boolean';
}
