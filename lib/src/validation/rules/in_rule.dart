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
  /// The allowed values.
  final List<T> values;

  In(this.values);

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

/// Validates that the value matches an entry from an enum list.
///
/// Accepts either the enum instance itself or a wire string. By default the
/// wire string is compared to `Enum.name`. Supply a [wire] mapper to customize
/// the wire representation (e.g. snake_case), or [caseInsensitive] to ignore
/// case.
///
/// ```dart
/// enum Severity { low, medium, high }
///
/// Validator.make({'severity': 'high'}, {
///   'severity': [InList(Severity.values)],
/// });
/// ```
class InList<T extends Enum> extends Rule {
  /// The allowed enum values.
  final List<T> values;

  /// Whether string comparison ignores case.
  final bool caseInsensitive;

  /// Optional mapper to translate an enum to its wire representation.
  final String Function(T value)? wire;

  InList(this.values, {this.caseInsensitive = false, this.wire});

  @override
  bool passes(String attribute, dynamic value, Map<String, dynamic> data) {
    if (value == null) return true;
    if (value is T) return values.contains(value);
    if (value is! String) return false;

    final needle = caseInsensitive ? value.toLowerCase() : value;
    for (final candidate in values) {
      var wireValue = wire?.call(candidate) ?? candidate.name;
      if (caseInsensitive) wireValue = wireValue.toLowerCase();
      if (wireValue == needle) return true;
    }
    return false;
  }

  @override
  String message() => 'validation.in';

  @override
  Map<String, dynamic> params() => {
    'values': values.map((v) => wire?.call(v) ?? v.name).join(', '),
  };
}
