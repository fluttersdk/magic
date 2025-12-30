import '../facades/lang.dart';
import 'contracts/rule.dart';
import 'exceptions/validation_exception.dart';

/// The Validator Class.
///
/// The heart of Magic's validation system. Runs rules against data and
/// provides a clean API for validation in controllers.
///
/// ## Usage
///
/// ```dart
/// final validator = Validator.make({
///   'email': 'user@example.com',
///   'password': 'secret',
/// }, {
///   'email': [Required(), Email()],
///   'password': [Required(), Min(8)],
/// });
///
/// if (validator.fails()) {
///   print(validator.errors());
/// }
///
/// // Or throw on failure:
/// validator.validate(); // Throws ValidationException if fails
/// ```
///
/// ## Message Resolution
///
/// When a rule fails, the Validator resolves the message:
/// 1. Calls `rule.message()` to get the key/raw message
/// 2. If `Lang.has(key)`, uses `Lang.get(key, params)` for translation
/// 3. Otherwise uses the message as a raw string
/// 4. Replaces `:attribute` with the humanized field name
class Validator {
  /// The data being validated.
  final Map<String, dynamic> _data;

  /// The validation rules.
  final Map<String, List<Rule>> _rules;

  /// The error messages after validation.
  final Map<String, String> _errors = {};

  /// Whether validation has been run.
  bool _hasRun = false;

  /// Create a new Validator instance.
  ///
  /// Prefer using [Validator.make] for a more fluent API.
  Validator._(this._data, this._rules);

  /// Create a new Validator instance.
  ///
  /// ```dart
  /// final validator = Validator.make(data, rules);
  /// ```
  static Validator make(
    Map<String, dynamic> data,
    Map<String, List<Rule>> rules,
  ) {
    return Validator._(data, rules);
  }

  /// Run the validation and check if it failed.
  ///
  /// Returns `true` if any rule failed, `false` if all passed.
  ///
  /// ```dart
  /// if (validator.fails()) {
  ///   print('Validation failed: ${validator.errors()}');
  /// }
  /// ```
  bool fails() {
    if (!_hasRun) {
      _runValidation();
    }
    return _errors.isNotEmpty;
  }

  /// Run the validation and check if it passed.
  ///
  /// Returns `true` if all rules passed.
  bool passes() => !fails();

  /// Get all validation errors.
  ///
  /// Returns a map of field names to their first error message.
  Map<String, String> errors() {
    if (!_hasRun) {
      _runValidation();
    }
    return Map.unmodifiable(_errors);
  }

  /// Run validation and throw if it fails.
  ///
  /// Returns the validated data (only fields with rules) if validation passes.
  /// Throws [ValidationException] if validation fails.
  ///
  /// ```dart
  /// try {
  ///   final validated = validator.validate();
  ///   // Use validated data...
  /// } on ValidationException catch (e) {
  ///   print(e.errors);
  /// }
  /// ```
  Map<String, dynamic> validate() {
    if (fails()) {
      throw ValidationException(_errors);
    }

    // Return only the validated fields (Laravel behavior)
    final validated = <String, dynamic>{};
    for (final key in _rules.keys) {
      if (_data.containsKey(key)) {
        validated[key] = _data[key];
      }
    }
    return validated;
  }

  /// Run all validation rules.
  void _runValidation() {
    _hasRun = true;
    _errors.clear();

    for (final entry in _rules.entries) {
      final attribute = entry.key;
      final rules = entry.value;
      final value = _data[attribute];

      for (final rule in rules) {
        if (!rule.passes(attribute, value, _data)) {
          // Only record first error per field (Laravel behavior)
          if (!_errors.containsKey(attribute)) {
            _errors[attribute] = _resolveMessage(rule, attribute);
          }
          break; // Stop on first failure for this field
        }
      }
    }
  }

  /// Resolve the error message for a failed rule.
  String _resolveMessage(Rule rule, String attribute) {
    final messageKey = rule.message();

    // Build params with :attribute replacement
    final params = <String, dynamic>{
      'attribute': _humanizeAttribute(attribute),
      ...rule.params(),
    };

    // Check if it's a translation key
    if (Lang.has(messageKey)) {
      return Lang.get(messageKey, params);
    }

    // Otherwise use as raw message with manual replacement
    var message = messageKey;
    for (final entry in params.entries) {
      message = message.replaceAll(':${entry.key}', entry.value.toString());
    }
    return message;
  }

  /// Convert attribute name to human-readable form.
  ///
  /// Checks for translation key `attributes.{attribute}` first.
  /// If not found, humanizes the string (e.g., `email_address` -> `email address`).
  String _humanizeAttribute(String attribute) {
    if (Lang.has('attributes.$attribute')) {
      return Lang.get('attributes.$attribute');
    }

    // Replace underscores and camelCase with spaces
    return attribute
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)?.toLowerCase()}',
        )
        .replaceAll('_', ' ')
        .toLowerCase();
  }
}
