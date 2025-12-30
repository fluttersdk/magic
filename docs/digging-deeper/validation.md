# Validation

## Introduction

Magic provides a powerful validation system that integrates seamlessly with Flutter's native `Form` widget. Define your validation rules in the View using `FormValidator.rules()`, and your Controller receives only clean, pre-validated data.

### Key Features

1. **MagicForm Widget**: Automatic server-side error handling with `autovalidateMode`
2. **rules() Helper**: Auto-injected controller for server validation errors
3. **View-Side Validation**: Rules defined in View with `WFormInput` and `FormValidator.rules()`
4. **Native Form Integration**: Works with Flutter's `Form` widget and `Form.validate()`
5. **Server-Side Errors**: Automatic display of API 422 validation errors under form fields
6. **Error Styling**: Automatic `error:` state for Wind CSS-like error styling
7. **Localization**: Error messages resolved via `Lang` for easy translation

### Quick Start with MagicFormData

Use `MagicFormData` for a cleaner, Laravel-style form handling experience:

```dart
class LoginView extends MagicStatefulView<LoginController> {
  // Define form data - types are inferred from initial values
  // String -> TextController, bool -> ValueNotifier
  late final form = MagicFormData({
    'email': '',
    'password': '',
    'remember': false,
  }, controller: controller);

  @override
  void onClose() => form.dispose();

  @override
  Widget build(BuildContext context) {
    return MagicForm(
      formData: form, // Automatically links validation
      child: Column(
        children: [
          WFormInput(
            controller: form['email'],
            label: 'Email',
            validator: rules([Required(), Email()], field: 'email'),
          ),
          WFormInput(
            controller: form['password'],
            label: 'Password',
            type: InputType.password,
            validator: rules([Required(), Min(8)], field: 'password'),
          ),
          WFormCheckbox(
            value: form.value<bool>('remember'),
            onChanged: (v) => form.setValue('remember', v),
            label: Text('Remember Me'),
          ),
          WButton(
            onTap: () {
              // Validates form and returns data map if valid
              final data = form.validated();
              if (data.isNotEmpty) {
                controller.login(data);
              }
            },
            child: Text('Sign In'),
          ),
        ],
      ),
    );
  }
}
```

### What MagicForm Provides

| Feature | Description |
|---------|-------------|
| `formKey` | Form key for validation access |
| `controller` | Controller with `ValidatesRequests` mixin |
| Auto `autovalidateMode` | Automatically shows errors when `controller.hasErrors` |

### What rules() Provides

The `rules()` helper is available in all `MagicStatefulViewState` subclasses:

```dart
// Instead of:
validator: FormValidator.rules([Required()], field: 'email', controller: controller)

// Simply use:
validator: rules([Required()], field: 'email')
```

## Server-Side Validation Errors

Display API 422 validation errors under form fields automatically.

### Controller Setup

Add `ValidatesRequests` mixin to your controller:

```dart
class AuthController extends MagicController 
    with MagicStateMixin<bool>, ValidatesRequests {
  
  Future<void> register({required String email, ...}) async {
    setLoading();
    clearErrors(); // Clear previous errors
    
    final response = await Http.post('/register', data: {...});
    
    if (response.successful) {
      setSuccess(true);
      MagicRoute.to('/dashboard');
    } else {
      // Handle 422 validation and other errors automatically
      handleApiError(response, fallback: 'Registration failed');
    }
  }
}
```

### handleApiError Method

The `handleApiError()` method encapsulates the common error handling pattern:

| Error Type | Behavior |
|------------|----------|
| 422 Validation | Sets field-level errors, resets to empty state |
| Other (500, etc) | Sets generic error state with message |

```dart
// Simple usage
handleApiError(response);

// With custom fallback message
handleApiError(response, fallback: 'Failed to save');
```

### MagicResponse Helpers

| Property | Type | Description |
|----------|------|-------------|
| `isValidationError` | `bool` | Check if status is 422 |
| `errors` | `Map<String, List<String>>` | Field errors map |
| `errorsList` | `List<String>` | All errors flattened |
| `firstError` | `String?` | First error message |

### ValidatesRequests Mixin

| Method | Description |
|--------|-------------|
| `setErrorsFromResponse(response)` | Populate errors from API |
| `hasError('field')` | Check if field has error |
| `getError('field')` | Get error message |
| `hasErrors` | Check if any errors exist |
| `clearErrors()` | Clear all errors |

## Available Rules

| Rule | Description | Usage |
|------|-------------|-------|
| `Required()` | Field must not be empty | `[Required()]` |
| `Email()` | Valid email format | `[Email()]` |
| `Min(n)` | Minimum length/value/count | `[Min(8)]` |
| `Max(n)` | Maximum length/value/count | `[Max(255)]` |
| `Confirmed()` | Must match `{field}_confirmation` | `[Confirmed()]` |
| `Same('other')` | Must match another field | `[Same('email')]` |
| `Accepted()` | Must be true/1/"yes"/"on" | `[Accepted()]` |

## Custom Rules

Create custom rules by extending `Rule`:

```dart
class StrongPassword extends Rule {
  @override
  bool passes(String attribute, dynamic value, Map<String, dynamic> data) {
    if (value is! String || value.isEmpty) return true;
    
    return value.contains(RegExp(r'[A-Z]')) &&
           value.contains(RegExp(r'[a-z]')) &&
           value.contains(RegExp(r'[0-9]')) &&
           value.contains(RegExp(r'[!@#$%^&*]'));
  }

  @override
  String message() => 'The :attribute must contain uppercase, lowercase, number, and special character.';
}
```

## Error Styling

WFormInput automatically adds the `error` state when validation fails:

```dart
WFormInput(
  className: '''
    p-3 border border-gray-300 rounded-lg
    focus:ring-2 focus:ring-blue-500
    error:border-red-500 error:ring-red-200
  ''',
  validator: rules([Required(), Email()], field: 'email'),
)
```

## Localization

Add an `attributes` section for user-friendly field names:

```json
{
  "attributes": {
    "email": "email address",
    "password_confirmation": "password confirmation"
  }
}
```

