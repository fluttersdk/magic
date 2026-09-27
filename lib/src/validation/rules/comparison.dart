import '../contracts/size_rule.dart';

/// The Gt Rule.
///
/// Validates that the field's size is strictly greater than [other]. Mirrors
/// Laravel's `gt:value` rule, restricted to a literal comparison value
/// rather than another field's name.
class Gt extends SizeRule {
  /// The threshold the field's size must exceed.
  final num other;

  /// The detected type of the value (numeric, string, list).
  String _type = 'numeric';

  /// Create a Gt rule. [other] is the threshold the field must exceed.
  Gt(this.other);

  @override
  bool passesSized(
    String attribute,
    dynamic value,
    Map<String, dynamic> data, {
    required bool numeric,
  }) {
    if (value == null) return true; // Let Required handle null
    if (value is String && value.isEmpty) {
      return true; // Let Required handle empty
    }

    final sized = sizeOf(value, numeric: numeric);
    if (sized == null) return false;

    _type = sized.$2;
    return sized.$1 > other;
  }

  @override
  String message() => 'validation.gt.$_type';

  @override
  Map<String, dynamic> params() => {'value': other};
}

/// The Gte Rule.
///
/// Validates that the field's size is greater than or equal to [other].
/// Mirrors Laravel's `gte:value` rule.
class Gte extends SizeRule {
  /// The threshold the field's size must reach or exceed.
  final num other;

  /// The detected type of the value (numeric, string, list).
  String _type = 'numeric';

  /// Create a Gte rule. [other] is the threshold the field must reach.
  Gte(this.other);

  @override
  bool passesSized(
    String attribute,
    dynamic value,
    Map<String, dynamic> data, {
    required bool numeric,
  }) {
    if (value == null) return true; // Let Required handle null
    if (value is String && value.isEmpty) {
      return true; // Let Required handle empty
    }

    final sized = sizeOf(value, numeric: numeric);
    if (sized == null) return false;

    _type = sized.$2;
    return sized.$1 >= other;
  }

  @override
  String message() => 'validation.gte.$_type';

  @override
  Map<String, dynamic> params() => {'value': other};
}

/// The Lt Rule.
///
/// Validates that the field's size is strictly less than [other]. Mirrors
/// Laravel's `lt:value` rule.
class Lt extends SizeRule {
  /// The threshold the field's size must stay under.
  final num other;

  /// The detected type of the value (numeric, string, list).
  String _type = 'numeric';

  /// Create a Lt rule. [other] is the threshold the field must stay under.
  Lt(this.other);

  @override
  bool passesSized(
    String attribute,
    dynamic value,
    Map<String, dynamic> data, {
    required bool numeric,
  }) {
    if (value == null) return true; // Let Required handle null
    if (value is String && value.isEmpty) {
      return true; // Let Required handle empty
    }

    final sized = sizeOf(value, numeric: numeric);
    if (sized == null) return false;

    _type = sized.$2;
    return sized.$1 < other;
  }

  @override
  String message() => 'validation.lt.$_type';

  @override
  Map<String, dynamic> params() => {'value': other};
}

/// The Lte Rule.
///
/// Validates that the field's size is less than or equal to [other]. Mirrors
/// Laravel's `lte:value` rule.
class Lte extends SizeRule {
  /// The threshold the field's size must not exceed.
  final num other;

  /// The detected type of the value (numeric, string, list).
  String _type = 'numeric';

  /// Create a Lte rule. [other] is the threshold the field must not exceed.
  Lte(this.other);

  @override
  bool passesSized(
    String attribute,
    dynamic value,
    Map<String, dynamic> data, {
    required bool numeric,
  }) {
    if (value == null) return true; // Let Required handle null
    if (value is String && value.isEmpty) {
      return true; // Let Required handle empty
    }

    final sized = sizeOf(value, numeric: numeric);
    if (sized == null) return false;

    _type = sized.$2;
    return sized.$1 <= other;
  }

  @override
  String message() => 'validation.lte.$_type';

  @override
  Map<String, dynamic> params() => {'value': other};
}
