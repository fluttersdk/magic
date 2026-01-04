import '../concerns/validates_requests.dart';
import '../facades/lang.dart';
import '../http/magic_controller.dart';
import '../validation/contracts/rule.dart';

/// Form Validation Helper.
///
/// Bridges Magic validation rules with Flutter's native Form widgets.
/// Use `FormValidator.rules()` to create validators for `WFormInput`,
/// `TextFormField`, or any `FormField` widget.
///
/// ## Recommended Usage with WFormInput
///
/// ```dart
/// final _formKey = GlobalKey<FormState>();
/// final _email = TextEditingController();
///
/// Form(
///   key: _formKey,
///   child: Column(
///     children: [
///       WFormInput(
///         controller: _email,
///         type: InputType.email,
///         label: 'Email',
///         className: 'p-3 border rounded-lg error:border-red-500',
///         validator: FormValidator.rules(
///           [Required(), Email()],
///           field: 'email',
///         ),
///       ),
///       FilledButton(
///         onPressed: () {
///           if (_formKey.currentState!.validate()) {
///             // Form valid! Send clean data to controller
///             controller.attemptLogin(email: _email.text.trim());
///           }
///         },
///         child: Text('Submit'),
///       ),
///     ],
///   ),
/// )
/// ```
///
/// ## With Password Confirmation
///
/// ```dart
/// final _password = TextEditingController();
/// final _passwordConfirm = TextEditingController();
///
/// WFormInput(
///   controller: _passwordConfirm,
///   type: InputType.password,
///   label: 'Confirm Password',
///   validator: FormValidator.rules(
///     [Required(), Same('password')],
///     field: 'password confirmation',
///     extraData: {'password': _password.text},
///   ),
/// )
/// ```
class FormValidator {
  /// Create a FormFieldValidator from Magic rules.
  ///
  /// Returns a validator function compatible with `WFormInput`, `TextFormField`,
  /// `WFormCheckbox`, or any `FormField<T>` widget.
  ///
  /// [rules] - List of validation rules to apply (e.g., `[Required(), Email()]`)
  /// [field] - Field name for error messages (e.g., 'email' → "The email is required")
  /// [extraData] - Additional data for rules like `Same()` or `Confirmed()`
  /// [controller] - Optional controller to check for server-side validation errors
  ///
  /// ## With TextFormField / WFormInput
  ///
  /// ```dart
  /// WFormInput(
  ///   controller: _email,
  ///   validator: FormValidator.rules(
  ///     [Required(), Email()],
  ///     field: 'email',
  ///     controller: controller, // Check for server errors
  ///   ),
  /// )
  /// ```
  ///
  /// ## With WFormCheckbox (bool type)
  ///
  /// ```dart
  /// WFormCheckbox(
  ///   value: _acceptTerms,
  ///   onChanged: (v) => setState(() => _acceptTerms = v),
  ///   validator: FormValidator.rules<bool>(
  ///     [Required()],
  ///     field: 'terms',
  ///   ),
  /// )
  /// ```
  static String? Function(T?) rules<T>(
    List<Rule> rules, {
    String field = 'field',
    Map<String, dynamic>? extraData,
    MagicController? controller,
  }) {
    return (T? value) {
      // 1. Check server-side errors if controller is provided
      if (controller != null && controller is ValidatesRequests) {
        final validator = controller;
        if (validator.hasError(field)) {
          return validator.getError(field);
        }
      }

      // 2. Build data map with just this field
      final data = <String, dynamic>{
        field: value,
        ...?extraData,
      };

      // 3. Run each client-side rule
      for (final rule in rules) {
        if (!rule.passes(field, value, data)) {
          return _resolveMessage(rule, field);
        }
      }

      return null; // Validation passed
    };
  }

  /// Resolve error message from rule.
  static String _resolveMessage(Rule rule, String attribute) {
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
  /// If not found, humanizes the string.
  static String _humanizeAttribute(String attribute) {
    if (Lang.has('attributes.$attribute')) {
      return Lang.get('attributes.$attribute');
    }

    return attribute
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)?.toLowerCase()}',
        )
        .replaceAll('_', ' ')
        .toLowerCase();
  }
}
