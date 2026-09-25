import '../http/magic_controller.dart';
import '../network/magic_response.dart';
import '../validation/contracts/rule.dart';
import '../validation/exceptions/authorization_exception.dart';
import '../validation/exceptions/validation_exception.dart';
import '../validation/form_request.dart';
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
    refreshUI();

    final validator = Validator.make(data, rules);

    try {
      return validator.validate();
    } on ValidationException catch (e) {
      // Populate errors and notify UI
      validationErrors = Map.from(e.errors);
      refreshUI();
      rethrow;
    }
  }

  /// Run a [FormRequest] through this mixin's error bag instead of
  /// `FormRequest.validate()`.
  ///
  /// `FormRequest.validate()` filters its return value to the keys declared
  /// in [FormRequest.rules] and never touches [validationErrors], so a
  /// controller calling it directly would neither clear stale errors before
  /// a resubmit, populate per-field errors on failure, nor repaint the form.
  /// [validateRequest] runs the same authorize/prepare sequence but hands the
  /// prepared payload to this mixin's own [validate], which clears,
  /// populates and repaints exactly as a controller-authored rule map would,
  /// and then returns the FULL prepared map (not the rule-filtered one), so a
  /// write path can still send along fields the backend needs but no rule
  /// constrains.
  ///
  /// Throws [AuthorizationException] when [FormRequest.authorize] returns
  /// `false`, before any field is touched. Otherwise a `ValidationException`
  /// propagates after populating [validationErrors].
  ///
  /// Runs only synchronous [Rule]s: any [AsyncRule] in [request]'s rules is
  /// skipped (see [Validator.validate]). Use [validateRequestAsync] when a
  /// rule needs to await.
  Map<String, dynamic> validateRequest(
    FormRequest request,
    Map<String, dynamic> data,
  ) {
    if (!request.authorize()) {
      throw const AuthorizationException();
    }

    final prepared = request.prepared(data);
    validate(prepared, request.rules());

    return prepared;
  }

  /// Same contract as [validateRequest], but validates through
  /// [Validator.validateAsync] so any [AsyncRule] in [request]'s rules
  /// actually runs.
  ///
  /// Throws [AuthorizationException] when [FormRequest.authorize] returns
  /// `false`. Otherwise clears [validationErrors], validates
  /// [FormRequest.prepared]'s output against [FormRequest.rules], and either
  /// returns the full prepared map or populates [validationErrors] and
  /// rethrows `ValidationException`, mirroring [validate]'s own try/catch.
  Future<Map<String, dynamic>> validateRequestAsync(
    FormRequest request,
    Map<String, dynamic> data,
  ) async {
    if (!request.authorize()) {
      throw const AuthorizationException();
    }

    final prepared = request.prepared(data);

    // Clear previous errors and notify UI
    validationErrors = {};
    refreshUI();

    final validator = Validator.make(prepared, request.rules());

    try {
      await validator.validateAsync();
    } on ValidationException catch (e) {
      // Populate errors and notify UI
      validationErrors = Map.from(e.errors);
      refreshUI();
      rethrow;
    }

    return prepared;
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
    setErrorsFromMap(response.errors);
  }

  /// Map a raw wire validation key to the form field it should report on.
  ///
  /// Identity by default, so [setErrorsFromMap] and [setErrorsFromResponse]
  /// keep raw dot-notation keys (e.g. `items.0.name`) as-is; changing that
  /// default would change behaviour for every existing app that mixes in
  /// [ValidatesRequests]. Mix in [CollapsesIndexedErrorKeys] on top when a
  /// form cannot address a specific list element and needs a numeric index
  /// collapsed onto its parent field instead.
  String errorFieldFor(String wireKey) => wireKey;

  /// Set validation errors from a raw wire error map, keyed by [errorFieldFor].
  ///
  /// Clears any previous errors, then for each entry maps its key through
  /// [errorFieldFor] and keeps the FIRST message reported for that field: two
  /// wire keys that collapse onto the same field (e.g. two failing elements
  /// of the same list) do not overwrite each other. An entry with an empty
  /// message list is skipped. Always calls [refreshUI], including when
  /// [errors] is empty, so the UI repaints and clears stale errors.
  void setErrorsFromMap(Map<String, List<String>> errors) {
    validationErrors = {};
    for (final entry in errors.entries) {
      if (entry.value.isEmpty) continue;
      final field = errorFieldFor(entry.key);
      validationErrors.putIfAbsent(field, () => entry.value.first);
    }
    refreshUI();
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
      refreshUI();
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
      refreshUI();
    }
  }
}

/// Opt-in [ValidatesRequests.errorFieldFor] override that collapses an
/// indexed wire validation key onto the form field it should report on.
///
/// A backend that validates a list field (`items.0.name`, `items.1.name`)
/// returns one wire key per element, but a form with a single error slot per
/// field (not per element) has nowhere to put a per-index message. Mix this
/// in on top of [ValidatesRequests] to collapse such keys down to their
/// field name (`items.0.name` -> `name`). It is opt-in rather than the
/// default because [ValidatesRequests.errorFieldFor] keeping raw keys is a
/// behaviour existing controllers already depend on.
mixin CollapsesIndexedErrorKeys on ValidatesRequests {
  @override
  String errorFieldFor(String wireKey) => _collapseIndexedKey(wireKey);

  /// Collapses [wireKey] the same way [errorFieldFor] does, for a controller
  /// that cannot mix in [CollapsesIndexedErrorKeys] (e.g. it already extends
  /// a different base) but still needs the collapse.
  static String collapse(String wireKey) => _collapseIndexedKey(wireKey);
}

/// Collapses a wire validation key onto the form field it should report on.
///
/// 1. Drop a trailing element index (`ok_values.0` -> `ok_values`); a single
///    remaining segment is already the answer.
/// 2. What is left addresses a distinct SUB-KEY, not a list element, when its
///    second segment is not itself numeric: `credentials.token` stays whole
///    because a form with a separate error slot per sub-key
///    (`credentials.url`, `credentials.secret`, ...) needs each one kept.
/// 3. A second segment that IS numeric marks a collection wrapper
///    (`items.<row>.<field>...`), so the key collapses onto its last
///    remaining segment, the one field the form actually renders, rather
///    than the wrapper name a plain `.split('.').first` would give.
String _collapseIndexedKey(String key) {
  final segments = key.split('.');

  int end = segments.length;
  while (end > 1 && _isNumericSegment(segments[end - 1])) {
    end--;
  }
  final trimmed = segments.sublist(0, end);

  if (trimmed.length == 1) {
    return trimmed.first;
  }

  if (_isNumericSegment(trimmed[1])) {
    return trimmed.last;
  }

  return trimmed.join('.');
}

/// Whether [segment] is a non-empty run of ASCII digits, i.e. a list index
/// rather than a field name.
bool _isNumericSegment(String segment) {
  return segment.isNotEmpty && int.tryParse(segment) != null;
}
