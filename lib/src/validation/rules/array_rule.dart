import '../contracts/rule.dart';

/// The ArrayRule Rule.
///
/// Validates that the field is a [List]. Mirrors Laravel's `array` rule;
/// named `ArrayRule` because `Array` is not a Dart keyword but reads poorly
/// next to `List`, the type it actually checks.
///
/// ## Usage
///
/// ```dart
/// validate(data, {
///   'tags': [Required(), ArrayRule()],
/// });
/// ```
class ArrayRule extends Rule {
  /// Creates an [ArrayRule]. Const, because it carries no state.
  const ArrayRule();

  @override
  bool passes(String attribute, dynamic value, Map<String, dynamic> data) {
    if (value == null) return true; // Let Required handle null

    return value is List;
  }

  @override
  String message() => 'validation.array';
}
