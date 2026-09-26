import '../contracts/rule.dart';

/// The Uuid Rule.
///
/// Validates that the field is an RFC 4122 UUID, any version, matched
/// case-insensitively. Mirrors `Str::isUuid()` with no version argument in
/// Laravel, which is the same unversioned shape check.
///
/// ## Usage
///
/// ```dart
/// validate(data, {
///   'teamId': [Required(), Uuid()],
/// });
/// ```
class Uuid extends Rule {
  /// Creates a [Uuid] rule. Const, because it carries no state.
  const Uuid();

  /// The unversioned UUID shape: 8-4-4-4-12 hex digits, either case.
  static final RegExp _pattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @override
  bool passes(String attribute, dynamic value, Map<String, dynamic> data) {
    if (value == null) return true; // Let Required handle null
    if (value is! String) return false;
    if (value.isEmpty) return true; // Let Required handle empty

    return _pattern.hasMatch(value);
  }

  @override
  String message() => 'validation.uuid';
}
