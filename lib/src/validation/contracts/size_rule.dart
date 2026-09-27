import '../rules/integer.dart';
import '../rules/numeric.dart';
import 'rule.dart';

/// A rule that compares a value's size: a number's value, a string's length,
/// or a list's item count.
///
/// Mirrors Laravel's `getSize`: a string is read as a NUMBER only when the
/// same attribute also carries a numeric rule ([Numeric], [Integer]), and as
/// a LENGTH otherwise. Form input is always a string, so the rule list has to
/// decide: `[Numeric(), Max(100)]` refuses `"500"`, while `[Between(8, 64)]`
/// on a password accepts `"12345678"`. A rule cannot see its siblings, so
/// `Validator` and `FormValidator` pass the answer in through [passesSized];
/// [passes] alone sizes a string by its length.
abstract class SizeRule extends Rule {
  /// Creates a size rule.
  SizeRule();

  /// Whether [rules] make an attribute numeric, so its strings are sized by
  /// value.
  static bool numericIn(Iterable<Rule> rules) {
    return rules.any((Rule rule) => rule is Numeric || rule is Integer);
  }

  @override
  bool passes(String attribute, dynamic value, Map<String, dynamic> data) {
    return passesSized(attribute, value, data, numeric: false);
  }

  /// Determine if the rule passes, sizing a numeric string by value when
  /// [numeric] is true.
  bool passesSized(
    String attribute,
    dynamic value,
    Map<String, dynamic> data, {
    required bool numeric,
  });

  /// The size of [value] and the message type it was measured as (`numeric`,
  /// `string` or `list`), or `null` for a value no size rule can measure.
  (num, String)? sizeOf(dynamic value, {required bool numeric}) {
    if (value is num) return (value, 'numeric');

    if (value is String) {
      final num? parsed = numeric ? num.tryParse(value) : null;
      if (parsed != null) return (parsed, 'numeric');

      return (value.length, 'string');
    }

    if (value is List) return (value.length, 'list');

    return null;
  }
}
