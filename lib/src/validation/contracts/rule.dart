/// The Rule Contract.
///
/// This is the foundation of Magic's validation system. Every validation rule
/// must implement this contract, giving you a clean and predictable API whether
/// you're using built-in rules or creating your own.
///
/// ## Creating a Custom Rule
///
/// ```dart
/// class Uppercase extends Rule {
///   @override
///   bool passes(String attribute, dynamic value, Map<String, dynamic> data) {
///     if (value is! String) return false;
///     return value == value.toUpperCase();
///   }
///
///   @override
///   String message() => 'validation.uppercase';
///   // Or a raw message: 'The :attribute must be uppercase.'
/// }
/// ```
///
/// ## Message Resolution
///
/// The `message()` method can return either:
/// - A translation key (e.g., `'validation.required'`) - resolved via `Lang.get()`
/// - A raw string (e.g., `'This field is required.'`) - used as-is
///
/// ## Parameters
///
/// Override `params()` to provide replacement values for your message:
///
/// ```dart
/// class Min extends Rule {
///   final int min;
///   Min(this.min);
///
///   @override
///   Map<String, dynamic> params() => {'min': min};
/// }
/// // Message: "The :attribute must be at least :min characters."
/// // Result:  "The name must be at least 3 characters."
/// ```
abstract class Rule {
  /// Determine if the validation rule passes.
  ///
  /// - [attribute] The name of the field being validated (e.g., 'email')
  /// - [value] The value of the field
  /// - [data] All data being validated (useful for rules like `confirmed`)
  ///
  /// Returns `true` if validation passes, `false` otherwise.
  bool passes(String attribute, dynamic value, Map<String, dynamic> data);

  /// Get the validation error message.
  ///
  /// Return a translation key (e.g., `'validation.required'`) or a raw string.
  /// The `:attribute` placeholder will be replaced with the field name.
  String message();

  /// Get the replacement parameters for the message.
  ///
  /// These will be passed to `Lang.get()` for translation replacement.
  /// The `:attribute` key is automatically added by the Validator.
  Map<String, dynamic> params() => {};
}
