import '../contracts/rule.dart';

/// The Same Rule.
///
/// Validates that the field matches another specified field.
/// Unlike `Confirmed`, you explicitly specify which field to match.
///
/// ## Usage with valueGetter (Recommended for Flutter Forms)
///
/// ```dart
/// TextFormField(
///   controller: _passwordConfirm,
///   validator: FormValidator.rules([
///     Required(),
///     Same('password', valueGetter: () => _password.text),
///   ], field: 'password confirmation'),
/// )
/// ```
///
/// ## Usage with extraData (Legacy)
///
/// ```dart
/// validator: FormValidator.rules(
///   [Required(), Same('password')],
///   field: 'password confirmation',
///   extraData: {'password': _password.text}, // ⚠️ Captured at build time
/// )
/// ```
///
/// ## Difference from Confirmed
///
/// - `Confirmed`: Automatically looks for `{field}_confirmation`
/// - `Same`: You specify the exact field name to compare
class Same extends Rule {
  /// The other field to compare against.
  final String other;

  /// Optional getter function to retrieve the current value at validation time.
  ///
  /// When provided, this takes precedence over `data[other]`.
  /// This is useful for Flutter forms where the value changes after build.
  final String Function()? valueGetter;

  /// Create a Same rule.
  ///
  /// [other] The name of the field that this field must match.
  /// [valueGetter] Optional function to get the current value at validation time.
  Same(this.other, {this.valueGetter});

  @override
  bool passes(String attribute, dynamic value, Map<String, dynamic> data) {
    if (value == null) return true; // Let Required handle null

    // Use valueGetter if provided, otherwise fall back to data map
    final otherValue = valueGetter != null ? valueGetter!() : data[other];
    return value == otherValue;
  }

  @override
  String message() => 'validation.same';

  @override
  Map<String, dynamic> params() => {'other': other};
}
