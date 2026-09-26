import '../contracts/rule.dart';

/// The Nullable Rule.
///
/// A marker rule: it always passes. It exists so a rule list can document
/// that a `null` is acceptable for a field, the way `nullable` reads in a
/// Laravel rule string.
///
/// Every rule in this package already treats `null` as "let [Required]
/// handle it" (see [Min], [Numeric], [Between], and the rest), so the skip a
/// `nullable` entry describes in Laravel is already each sibling rule's own
/// default behaviour here. That per-rule check is the rule-level flag this
/// package uses instead of a [Validator]-level skip: no change to
/// `validator.dart` was needed or made.
///
/// ## Usage
///
/// ```dart
/// validate(data, {
///   'score': [Nullable(), Numeric()],
/// });
/// ```
class Nullable extends Rule {
  /// Creates a [Nullable] rule. Const, because it carries no state.
  const Nullable();

  @override
  bool passes(String attribute, dynamic value, Map<String, dynamic> data) =>
      true;

  @override
  String message() => 'validation.nullable';
}
