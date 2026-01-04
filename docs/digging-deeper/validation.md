# Validation

- [Introduction](#introduction)
- [Quick Start](#quick-start)
- [Defining Validation Rules](#defining-validation-rules)
- [Available Rules](#available-rules)
- [Server-Side Validation](#server-side-validation)
- [Custom Rules](#custom-rules)
- [Error Styling](#error-styling)
- [Localization](#localization)

<a name="introduction"></a>
## Introduction

Magic provides a powerful validation system that integrates seamlessly with Flutter forms. Define your validation rules in the View using the `rules()` helper, and your Controller receives only clean, pre-validated data.

### Key Features

| Feature | Description |
|---------|-------------|
| **MagicForm Widget** | Automatic form state management and error handling |
| **rules() Helper** | Concise rule definition with auto-injected controller |
| **Server-Side Errors** | Automatic display of API 422 validation errors |
| **Error Styling** | Wind UI's `error:` state prefix for styling |
| **Localization** | Error messages resolved via `trans()` helper |

<a name="quick-start"></a>
## Quick Start

Use `MagicFormData` for Laravel-style form handling:

```dart
class RegisterView extends MagicStatefulView<AuthController> {
  const RegisterView({super.key});
  
  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends MagicStatefulViewState<AuthController, RegisterView> {
  // Define form fields - types inferred from initial values
  late final form = MagicFormData({
    'name': '',
    'email': '',
    'password': '',
    'password_confirmation': '',
    'accept_terms': false,
  }, controller: controller);

  @override
  void onClose() => form.dispose();

  @override
  Widget build(BuildContext context) {
    return MagicForm(
      formData: form,
      child: WDiv(
        className: 'flex flex-col gap-4',
        children: [
          WFormInput(
            controller: form['name'],
            label: trans('attributes.name'),
            validator: rules([Required(), Min(2)], field: 'name'),
          ),
          WFormInput(
            controller: form['email'],
            label: trans('attributes.email'),
            type: InputType.email,
            validator: rules([Required(), Email()], field: 'email'),
          ),
          WFormInput(
            controller: form['password'],
            label: trans('attributes.password'),
            type: InputType.password,
            validator: rules([Required(), Min(8)], field: 'password'),
          ),
          WFormInput(
            controller: form['password_confirmation'],
            label: trans('attributes.password_confirmation'),
            type: InputType.password,
            validator: rules([
              Required(),
              Same('password', valueGetter: () => form['password'].text),
            ], field: 'password_confirmation'),
          ),
          WFormCheckbox(
            value: form.value<bool>('accept_terms'),
            onChanged: (v) => form.setValue('accept_terms', v),
            label: WText(trans('auth.accept_terms')),
            validator: rules([Accepted()], field: 'accept_terms'),
          ),
          WButton(
            isLoading: controller.isLoading,
            onTap: () {
              final data = form.validated();
              if (data.isNotEmpty) {
                controller.register(data);
              }
            },
            className: 'w-full bg-primary p-4 rounded-lg',
            child: WText(trans('auth.register'), className: 'text-white text-center'),
          ),
        ],
      ),
    );
  }
}
```

<a name="defining-validation-rules"></a>
## Defining Validation Rules

### The rules() Helper

The `rules()` helper is available in all `MagicStatefulViewState` subclasses:

```dart
// Full syntax
validator: FormValidator.rules([Required()], field: 'email', controller: controller)

// Shorthand (controller auto-injected)
validator: rules([Required(), Email()], field: 'email')
```

### Multiple Rules

Combine multiple rules in an array:

```dart
validator: rules([
  Required(),
  Email(),
  Max(255),
], field: 'email')
```

Rules are evaluated in order. If any rule fails, validation stops and the error is displayed.

<a name="available-rules"></a>
## Available Rules

| Rule | Description | Example |
|------|-------------|---------|
| `Required()` | Field must not be empty | `[Required()]` |
| `Email()` | Valid email format | `[Email()]` |
| `Min(n)` | Minimum length/value | `[Min(8)]` |
| `Max(n)` | Maximum length/value | `[Max(255)]` |
| `Confirmed()` | Must match `{field}_confirmation` | `[Confirmed()]` |
| `Same('field')` | Must match another field | `[Same('password', valueGetter: ...)]` |
| `Accepted()` | Must be true/1/"yes"/"on" | `[Accepted()]` |

### Same Rule with ValueGetter

For password confirmation, use the `valueGetter` parameter:

```dart
WFormInput(
  controller: form['password_confirmation'],
  validator: rules([
    Required(),
    Same('password', valueGetter: () => form['password'].text),
  ], field: 'password_confirmation'),
)
```

<a name="server-side-validation"></a>
## Server-Side Validation

Magic automatically handles Laravel-style 422 validation errors from your API.

### Controller Setup

Add the `ValidatesRequests` mixin to your controller:

```dart
class AuthController extends MagicController 
    with MagicStateMixin<bool>, ValidatesRequests {
  
  Future<void> register(Map<String, dynamic> data) async {
    setLoading();
    clearErrors();  // Clear previous validation errors
    
    final response = await Http.post('/register', data: data);
    
    if (response.successful) {
      setSuccess(true);
      MagicRoute.to('/dashboard');
    } else {
      // Automatically populates field errors from 422 response
      handleApiError(response, fallback: 'Registration failed');
    }
  }
}
```

### handleApiError Method

The `handleApiError()` method handles different error types:

| Error Type | Behavior |
|------------|----------|
| 422 Validation | Sets field-level errors, form shows errors |
| 401 Unauthorized | Shows unauthorized message |
| 500+ Server Error | Shows fallback error message |

### ValidatesRequests Methods

| Method | Description |
|--------|-------------|
| `handleApiError(response)` | Handle any API error automatically |
| `setErrorsFromResponse(response)` | Populate errors from 422 response |
| `hasError('field')` | Check if a field has an error |
| `getError('field')` | Get error message for a field |
| `hasErrors` | Check if any errors exist |
| `clearErrors()` | Clear all validation errors |

### Displaying Server Errors

Server-side errors appear automatically under form fields. For manual display:

```dart
if (controller.hasError('email'))
  WText(controller.getError('email')!, className: 'text-red-500 text-sm'),
```

<a name="custom-rules"></a>
## Custom Rules

Create custom rules by extending `Rule`:

```dart
class StrongPassword extends Rule {
  @override
  bool passes(String attribute, dynamic value, Map<String, dynamic> data) {
    if (value is! String || value.isEmpty) return true;
    
    final hasUppercase = value.contains(RegExp(r'[A-Z]'));
    final hasLowercase = value.contains(RegExp(r'[a-z]'));
    final hasNumber = value.contains(RegExp(r'[0-9]'));
    final hasSpecial = value.contains(RegExp(r'[!@#$%^&*]'));
    
    return hasUppercase && hasLowercase && hasNumber && hasSpecial;
  }

  @override
  String message() => trans('validation.strong_password');
}

// Usage
validator: rules([Required(), StrongPassword()], field: 'password')
```

<a name="error-styling"></a>
## Error Styling

Wind UI's `WFormInput` automatically adds the `error` state when validation fails:

```dart
WFormInput(
  controller: form['email'],
  className: '''
    p-3 border border-gray-300 rounded-lg
    focus:ring-2 focus:ring-blue-500
    error:border-red-500 error:ring-red-200
  ''',
  validator: rules([Required(), Email()], field: 'email'),
)
```

The `error:` prefix applies styles when the field has validation errors.

<a name="localization"></a>
## Localization

### Validation Messages

Define validation messages in your language files:

```json
{
  "validation": {
    "required": "The :attribute field is required.",
    "email": "The :attribute must be a valid email address.",
    "min": {
      "string": "The :attribute must be at least :min characters."
    },
    "confirmed": "The :attribute confirmation does not match.",
    "accepted": "The :attribute must be accepted.",
    "strong_password": "The :attribute must contain uppercase, lowercase, number, and special character."
  }
}
```

### Attribute Names

Define user-friendly field names:

```json
{
  "attributes": {
    "email": "email address",
    "password": "password",
    "password_confirmation": "password confirmation",
    "accept_terms": "terms and conditions"
  }
}
```

The `:attribute` placeholder is replaced with the localized field name.
