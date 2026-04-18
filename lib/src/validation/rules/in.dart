import '../contracts/rule.dart';

/// Validates that the value is contained in a given whitelist.
///
/// Mirrors Laravel's `in:foo,bar,baz` rule. Null values pass so you can combine
/// with [Required] to enforce presence separately.
///
/// ```dart
/// Validator.make({'visibility': 'public'}, {
///   'visibility': [In<String>(['public', 'private'])],
/// });
/// ```
class In<T> extends Rule {
  /// The allowed values (immutable snapshot of the caller-provided list).
  final List<T> values;

  In(List<T> values) : values = List.unmodifiable(values);

  @override
  bool passes(String attribute, dynamic value, Map<String, dynamic> data) {
    if (value == null) return true;
    if (value is! T) return false;
    return values.contains(value);
  }

  @override
  String message() => 'validation.in';

  @override
  Map<String, dynamic> params() => {'values': values.join(', ')};
}
