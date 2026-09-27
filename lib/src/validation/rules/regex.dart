import '../contracts/rule.dart';

/// The Regex Rule.
///
/// Validates that the field matches a Dart [RegExp] pattern. Mirrors
/// Laravel's `regex:pattern` rule, but takes a plain Dart pattern with no
/// PCRE delimiters or flags, since Dart's [RegExp] has no delimiter syntax.
///
/// ## Usage
///
/// ```dart
/// validate(data, {
///   'sku': [Required(), Regex(r'^[A-Z]{3}-\d{4}$')],
/// });
/// ```
class Regex extends Rule {
  /// The Dart regular expression pattern, without delimiters.
  final String pattern;

  /// The compiled pattern.
  late final RegExp _regExp = RegExp(pattern);

  /// Create a Regex rule. [pattern] is a plain Dart [RegExp] pattern.
  Regex(this.pattern);

  @override
  bool passes(String attribute, dynamic value, Map<String, dynamic> data) {
    if (value == null) return true; // Let Required handle null
    if (value is! String && value is! num) return false;

    final String stringValue = value.toString();
    if (stringValue.isEmpty) return true; // Let Required handle empty

    return _regExp.hasMatch(stringValue);
  }

  @override
  String message() => 'validation.regex';
}
