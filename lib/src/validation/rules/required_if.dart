import '../contracts/rule.dart';

/// The RequiredIf Rule.
///
/// Validates that the field is present (by [Required]'s definition) when
/// another field equals a given value. Mirrors Laravel's
/// `required_if:other,value` rule, restricted to a single comparison value.
///
/// Unlike most rules in this package, it does not let [Required] handle
/// `null` on its own: whether `null` fails is exactly the condition this
/// rule decides.
///
/// ## Usage
///
/// ```dart
/// validate(data, {
///   'vatId': [RequiredIf('type', 'company')],
/// });
/// ```
class RequiredIf extends Rule {
  /// The other field whose value gates this field's presence.
  final String otherField;

  /// The value [otherField] must equal for this field to become required.
  final Object expectedValue;

  /// Create a RequiredIf rule.
  ///
  /// [otherField] The field to read. [expectedValue] The value it must equal.
  RequiredIf(this.otherField, this.expectedValue);

  @override
  bool passes(String attribute, dynamic value, Map<String, dynamic> data) {
    if (data[otherField] != expectedValue) return true;

    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is List) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    if (value is bool) return value;

    return true;
  }

  @override
  String message() => 'validation.required_if';

  @override
  Map<String, dynamic> params() => {
    'other': otherField,
    'value': expectedValue,
  };
}
