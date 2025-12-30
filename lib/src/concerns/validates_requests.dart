import '../http/magic_controller.dart';
import '../network/magic_response.dart';
import '../validation/contracts/rule.dart';
import '../validation/exceptions/validation_exception.dart';
import '../validation/validator.dart';

/// Interface for checking and clearing validation errors.
///
/// Used by MagicStatefulViewState to auto-clear errors when a new view
/// initializes, preventing cross-page error leakage.
abstract class HasValidationErrors {
  /// Clear all validation errors.
  void clearErrors();
}

/// The ValidatesRequests Mixin.
///
/// Provides Laravel-style validation capabilities for controllers.
///
/// > **Note:** The recommended approach for form validation is to use
/// > `FormValidator.rules()` in Views with `WFormInput`. This mixin is
/// > useful for API-level validation or when you need controller-side
/// > validation for other purposes.
///
/// ## Recommended Pattern (View-side validation)
///
/// ```dart
/// // In View - use FormValidator.rules() with WFormInput
/// WFormInput(
///   controller: _email,
///   validator: FormValidator.rules([Required(), Email()], field: 'email'),
/// )
///
/// // In Controller - receive clean, typed data
/// Future<void> attemptLogin({
///   required String email,
///   required String password,
/// }) async {
///   // No validation needed - data is pre-validated
///   await Auth.attempt(email, password);
/// }
/// ```
///
/// ## Alternative: Controller-side validation
///
/// For cases where you need controller-side validation:
///
/// ```dart
/// class AuthController extends MagicController with ValidatesRequests {
///   void login(Map<String, dynamic> requestData) {
///     try {
///       final data = validate(requestData, {
///         'email': [Required(), Email()],
///         'password': [Required(), Min(8)],
///       });
///       // Use validated data...
///     } on ValidationException catch (_) {
///       // Errors in validationErrors, UI auto-rebuilds
///     }
///   }
/// }
/// ```
///
/// ## Server-Side Validation Errors
///
/// Populate errors from API 422 responses:
///
/// ```dart
/// final response = await Http.post('/register', data: data);
/// if (response.isValidationError) {
///   setErrorsFromResponse(response);
///   return;
/// }
/// ```
///
/// ## Error Display in View
///
/// ```dart
/// WInput(
///   states: controller.hasError('email') ? {'error'} : {},
///   className: 'border error:border-red-500',
/// ),
/// if (controller.hasError('email'))
///   WText(controller.getError('email')!, className: 'text-red-500 text-xs'),
/// ```
mixin ValidatesRequests on MagicController implements HasValidationErrors {
  /// Current validation errors keyed by field name.
  ///
  /// Automatically populated when `validate()` catches a [ValidationException]
  /// or when `setErrorsFromResponse()` is called with a 422 response.
  Map<String, String> validationErrors = {};

  /// Validate the given data against the rules.
  ///
  /// Returns the validated data (only fields with rules) if validation passes.
  /// Throws [ValidationException] and populates [validationErrors] if it fails.
  ///
  /// The UI will automatically rebuild because this calls [notifyListeners].
  ///
  /// ```dart
  /// try {
  ///   final data = validate({
  ///     'email': email.text,
  ///     'password': password.text,
  ///   }, {
  ///     'email': [Required(), Email()],
  ///     'password': [Required(), Min(8)],
  ///   });
  ///   // Use data...
  /// } on ValidationException catch (_) {
  ///   // UI already has errors via validationErrors
  /// }
  /// ```
  Map<String, dynamic> validate(
    Map<String, dynamic> data,
    Map<String, List<Rule>> rules,
  ) {
    // Clear previous errors and notify UI
    validationErrors = {};
    notifyListeners();

    final validator = Validator.make(data, rules);

    try {
      return validator.validate();
    } on ValidationException catch (e) {
      // Populate errors and notify UI
      validationErrors = Map.from(e.errors);
      notifyListeners();
      rethrow;
    }
  }

  /// Set validation errors from an API response.
  ///
  /// Use this to show server-side validation errors (422 responses)
  /// under form fields, just like Laravel's `$errors` bag in Blade.
  ///
  /// ```dart
  /// final response = await Http.post('/register', data: formData);
  /// if (response.isValidationError) {
  ///   setErrorsFromResponse(response);
  ///   return;
  /// }
  /// ```
  ///
  /// In your view, use `hasError()` and `getError()`:
  /// ```dart
  /// if (controller.hasError('email'))
  ///   WText(controller.getError('email')!, className: 'text-red-500'),
  /// ```
  void setErrorsFromResponse(MagicResponse response) {
    validationErrors = {};
    for (final entry in response.errors.entries) {
      if (entry.value.isNotEmpty) {
        validationErrors[entry.key] = entry.value.first;
      }
    }
    notifyListeners();
  }

  /// Handle API error response automatically.
  ///
  /// This helper encapsulates the common error handling pattern:
  /// - For 422 validation errors: Sets field-level errors and resets to empty state
  /// - For other errors (500, etc): Sets generic error state
  ///
  /// Returns `true` if an error was handled (response was not successful),
  /// allowing you to use early returns in your controller methods.
  ///
  /// ## Usage
  ///
  /// ```dart
  /// Future<void> register({...}) async {
  ///   setLoading();
  ///   clearErrors();
  ///
  ///   final response = await Http.post('/register', data: {...});
  ///
  ///   if (response.successful) {
  ///     setSuccess(true);
  ///     MagicRoute.to('/dashboard');
  ///     return;
  ///   }
  ///
  ///   // Handles both 422 and other errors automatically
  ///   handleApiError(response);
  /// }
  /// ```
  ///
  /// **With custom fallback message:**
  /// ```dart
  /// handleApiError(response, fallback: 'Registration failed');
  /// ```
  ///
  /// **With early return pattern:**
  /// ```dart
  /// if (!response.successful) {
  ///   handleApiError(response);
  ///   return; // Stop execution
  /// }
  /// ```
  void handleApiError(MagicResponse response, {String? fallback}) {
    if (response.isValidationError) {
      // Set field-level validation errors from API response
      setErrorsFromResponse(response);
      // Set the errorMessage if exists else set empty.
      final errorMessage = response.errorMessage;
      if (this is MagicStateMixin) {
        if (errorMessage != null) {
          (this as MagicStateMixin).setError(errorMessage);
        } else {
          (this as MagicStateMixin).setEmpty();
        }
      }
    } else {
      // Other errors (500, network, etc) - show generic message
      final errorMessage =
          response.firstError ?? fallback ?? 'An error occurred';
      if (this is MagicStateMixin) {
        (this as MagicStateMixin).setError(errorMessage);
      }
    }
  }

  /// Check if a field has a validation error.
  ///
  /// ```dart
  /// if (controller.hasError('email')) {
  ///   // Show error UI
  /// }
  /// ```
  bool hasError(String field) => validationErrors.containsKey(field);

  /// Get the validation error message for a field.
  ///
  /// Returns `null` if the field has no error.
  ///
  /// ```dart
  /// final errorMessage = controller.getError('email');
  /// if (errorMessage != null) {
  ///   print(errorMessage); // "The email must be a valid email address."
  /// }
  /// ```
  String? getError(String field) => validationErrors[field];

  /// Get the first validation error message.
  ///
  /// Useful for showing a single error message at the top of a form.
  String? get firstError =>
      validationErrors.isNotEmpty ? validationErrors.values.first : null;

  /// Check if there are any validation errors.
  bool get hasErrors => validationErrors.isNotEmpty;

  /// Clear all validation errors.
  ///
  /// Call this when the user starts editing to clear stale errors.
  @override
  void clearErrors() {
    if (validationErrors.isNotEmpty) {
      validationErrors = {};
      notifyListeners();
    }
  }

  /// Clear a specific field's validation error.
  ///
  /// Call this when the user starts typing in a field to provide
  /// instant feedback that the error is being addressed.
  ///
  /// ```dart
  /// WFormInput(
  ///   onChanged: (_) => controller.clearFieldError('email'),
  ///   validator: rules([Required(), Email()], field: 'email'),
  /// )
  /// ```
  void clearFieldError(String field) {
    if (validationErrors.containsKey(field)) {
      validationErrors.remove(field);
      notifyListeners();
    }
  }
}
