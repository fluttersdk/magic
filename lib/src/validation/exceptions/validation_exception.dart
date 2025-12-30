/// The Validation Exception.
///
/// Thrown when validation fails, containing all field errors in a single map.
/// This allows the UI to display errors for all fields at once.
///
/// ## Usage
///
/// ```dart
/// try {
///   validator.validate();
/// } on ValidationException catch (e) {
///   print(e.errors); // {'email': 'The email field is required.'}
/// }
/// ```
///
/// ## Error Map Structure
///
/// Each key in the `errors` map is a field name, and the value is the
/// first error message for that field.
class ValidationException implements Exception {
  /// The validation errors keyed by field name.
  ///
  /// Example:
  /// ```dart
  /// {
  ///   'email': 'The email field is required.',
  ///   'password': 'The password must be at least 8 characters.',
  /// }
  /// ```
  final Map<String, String> errors;

  /// Create a new validation exception.
  ///
  /// [errors] A map of field names to their error messages.
  ValidationException(this.errors);

  @override
  String toString() {
    if (errors.isEmpty) {
      return 'ValidationException: No errors';
    }

    final messages =
        errors.entries.map((e) => '  ${e.key}: ${e.value}').join('\n');

    return 'ValidationException:\n$messages';
  }
}
