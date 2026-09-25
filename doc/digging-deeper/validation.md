# Validation

Magic provides a client-side validation system that integrates with Flutter forms, resolves error messages through the Lang facade, and extends to async rules for uniqueness or remote existence checks.

- [Introduction](#introduction)
- [Quick Start](#quick-start)
- [Defining Validation Rules](#defining-validation-rules)
- [Available Rules](#available-rules)
    - [The Url Rule](#the-url-rule)
    - [Custom Messages](#custom-messages)
- [Form Requests](#form-request)
- [Validating a Form Request Through a Controller](#validate-request)
- [Server-Side Validation](#server-side-validation)
- [Async Validation](#async-rules)
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
| `Url()` | Valid http(s) address with a host | `[Url()]`, `[Url(schemes: ['https'])]` |
| `Min(n)` | Minimum length/value | `[Min(8)]` |
| `Max(n)` | Maximum length/value | `[Max(255)]` |
| `Confirmed()` | Must match `{field}_confirmation` | `[Confirmed()]` |
| `Same('field')` | Must match another field | `[Same('password', valueGetter: ...)]` |
| `Accepted()` | Must be true/1/"yes"/"on" | `[Accepted()]` |
| `In<T>(values)` | Value must appear in whitelist | `[In<String>(['public', 'private'])]` |
| `InList<T extends Enum>(values)` | Value must match an enum (name or instance) | `[InList(Severity.values)]` |

<a name="the-url-rule"></a>
### The Url Rule

`Url()` accepts an address a request could actually be built from: a scheme from its allowlist and a non-empty host.

```dart
'website': [Required(), Url()],                    // http or https
'webhook': [Required(), Url(schemes: ['https'])],  // https only
'socket':  [Url(schemes: ['ws', 'wss'])],
```

It is not an RFC 3986 parser and does not try to be. It reaches no network, resolves no host and takes no view on whether the path exists, because a rule answering a form field synchronously cannot know any of that.

**The scheme allowlist is the part that matters.** `Uri.parse` accepts `javascript:alert(1)` and `file:///etc/passwd` without complaint; both have a scheme and parse cleanly. Nothing but the allowlist keeps them out of a field whose value becomes a request or a link. Narrow it to `['https']` for anything carrying a credential.

Whitespace is rejected before parsing, because `Uri` does not treat it as an error: `Uri.tryParse('http://exa mple.com')` succeeds and percent-encodes the space into the host as `exa%20mple.com`, which no DNS lookup can resolve. Laravel's `url` rejects it too.

<a name="custom-messages"></a>
### Custom Messages

A rule's message comes from its own catalogue key, which is generic by design: `validation.required` is `The :attribute field is required.` for every field in the app. When one screen wants its own wording, pass `messages`, keyed by rule name:

```dart
WFormInput(
  validator: FormValidator.rules(
    [Required(), Url()],
    field: 'address',
    messages: {
      'required': 'provider.error.address_required',
      'url': 'provider.error.address_scheme',
    },
  ),
)
```

This is Laravel's third `Validator::make` argument. Without it, a screen wanting specific copy had to abandon the rules and hand-roll a closure, which is exactly what the rules exist to prevent.

The value is a **key**, not a finished sentence. An override taking a sentence would make every consumer using it monolingual. A key with no sentence renders as itself, which is `trans`'s own contract, and the rule's parameters still reach it, so `:attribute` and `:schemes` work in an override too.

The map key is `Rule.name`, derived from the rule's message key (`validation.required` gives `required`) rather than from `runtimeType`, which is not a dependable identifier in a release build: dart2js minifies class names, and Flutter's own `objectRuntimeType` declines to call `toString` on a runtime type outside asserts.

### Whitelist Rules (`In` / `InList`)

`In<T>` validates against a primitive whitelist. The generic `T` is the element type, so type mismatches fail explicitly rather than silently coercing:

```dart
'visibility': [In<String>(['public', 'private'])],
'priority':   [In<int>([1, 2, 3, 5, 8])],
```

`InList<T extends Enum>` is the enum-aware variant. By default it compares against `Enum.name` and also accepts the enum instance itself. Use `caseInsensitive: true` for loose matching, or `wire:` to map enums onto a custom wire representation (snake_case, kebab-case, or bespoke codes):

```dart
enum Severity { low, medium, high, critical }

InList(Severity.values);                          // matches 'low', 'medium', ...
InList(Severity.values, caseInsensitive: true);   // also 'HIGH', 'Critical'

enum ThresholdDirection { highBad, lowBad }

InList<ThresholdDirection>(
  ThresholdDirection.values,
  wire: (d) => switch (d) {
    ThresholdDirection.highBad => 'high_bad',
    ThresholdDirection.lowBad  => 'low_bad',
  },
);
```

Both rules pass on `null` so you pair them with `Required()` when presence matters. The failure message resolves `validation.in` with a comma-joined `:values` placeholder (`"The severity must be one of low, medium, high, critical."`).

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

<a name="form-request"></a>
## Form Requests

A `FormRequest` collapses "authorize, normalize, validate" into a single class so controllers stop hand-rolling that ceremony. Subclass `FormRequest`, implement `rules()`, optionally override `authorize()` and `prepared()`, then call `.validate(rawInput)`:

```dart
class StoreMonitorRequest extends FormRequest {
  StoreMonitorRequest(this.actor);

  final User actor;

  @override
  bool authorize() => actor.can('monitor.create');

  @override
  Map<String, dynamic> prepared(Map<String, dynamic> data) => {
    ...data,
    'slug': slugify(data['name'] as String? ?? ''),
  };

  @override
  Map<String, List<Rule>> rules() => {
    'name': [Required(), Max(120)],
    'slug': [Required()],
  };
}

// In the controller:
try {
  final payload = StoreMonitorRequest(Auth.user()!).validate(form.data);
  await Http.post('/monitors', data: payload);
} on AuthorizationException {
  Magic.toast.error('You do not have permission to create monitors.');
} on ValidationException catch (e) {
  setFieldErrors(e.errors); // ValidatesRequests mixin
}
```

- `authorize()` runs first and throws `AuthorizationException` on `false`.
- `prepared()` normalizes the payload before rules see it (trim, slugify, merge defaults).
- `validate()` returns the prepared payload filtered to the keys declared in `rules()` — same contract as `Validator.validate`.

Pairs cleanly with `Model.fill(payload, strict: true)` so mass-assignment catches schema drift at the boundary.

<a name="validate-request"></a>
## Validating a Form Request Through a Controller

`FormRequest.validate()` filters its return value to the keys declared in `rules()` and never touches a controller's error bag, so calling it directly skips clearing stale errors before a resubmit, populating per-field errors on failure, and repainting the form. A controller with the `ValidatesRequests` mixin calls `validateRequest` instead, which runs the same authorize/prepare sequence but routes through the mixin's own error bag and returns the FULL prepared map, not the rule-filtered one, so a write can still send fields the backend needs but no rule constrains:

```dart
class MonitorController extends MagicController with ValidatesRequests {
  Future<void> store(Map<String, dynamic> data) async {
    try {
      final payload = validateRequest(StoreMonitorRequest(Auth.user()!), data);
      await Http.post('/monitors', data: payload);
    } on AuthorizationException {
      Magic.error('Error', 'You do not have permission to create monitors.');
    } on ValidationException catch (e) {
      // validationErrors is already populated; UI has already rebuilt.
    }
  }
}
```

`validateRequest` throws `AuthorizationException` when `FormRequest.authorize()` returns `false`, before any field is touched, and runs only synchronous rules (an `AsyncRule` in the request's `rules()` is skipped). Use `validateRequestAsync` when a rule needs to `await`; it has the same contract, validated through `Validator.validateAsync()` so an `AsyncRule` actually runs:

```dart
final payload = await validateRequestAsync(SlugUniqueRequest(), data);
```

### CollapsesIndexedErrorKeys

A backend that validates a list field returns one wire key per element (`items.0.name`, `items.1.name`), but a form with a single error slot per field, not per element, has nowhere to put a per-index message. `ValidatesRequests.errorFieldFor` keeps a wire key as-is by default, which is what an existing controller already depends on; mix in `CollapsesIndexedErrorKeys` on top to collapse an indexed key down to its field name instead:

```dart
class ItemsController extends MagicController
    with ValidatesRequests, CollapsesIndexedErrorKeys {}

// A 422 response carrying {"errors": {"items.0.name": ["The items.0.name field is required."]}}
// populates controller.validationErrors as {"name": "The items.0.name field is required."}
```

Two wire keys that collapse onto the same field (two failing elements of the same list) keep the FIRST message; the later one is dropped rather than overwriting it. A key addressing a distinct sub-key rather than a list element (`credentials.token`) is left whole, since a form with a separate error slot per sub-key needs each one kept.

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

<a name="async-rules"></a>
## Async Validation

Some validations cannot decide locally: uniqueness, remote existence, captcha checks. Extend `AsyncRule` instead of `Rule` and implement `passesAsync`. Run the validator with `validateAsync()` to await async rules; sync failures short-circuit per field so no network call is made for a field that already has a sync error.

### The AsyncRule Contract

`AsyncRule` is an abstract class that extends `Rule`. Implement `passesAsync` for the async check. The synchronous `passes` method always returns `true` so the rule is invisible to `Validator.validate()` (sync-only flows); the real outcome comes from `validateAsync()`.

```dart
class Exists extends AsyncRule {
  Exists(this.endpoint);

  final String endpoint;

  @override
  Future<bool> passesAsync(
    String attribute,
    dynamic value,
    Map<String, dynamic> data,
  ) async {
    if (value == null) return true;
    final response = await Http.get(
      endpoint,
      query: {attribute: value.toString()},
    );
    return response.successful;
  }

  @override
  String message() => 'validation.exists';
}
```

Use `validateAsync()` whenever the rule set contains async rules:

```dart
final validator = Validator.make(data, {
  'slug': [Required(), Unique('/validate/unique', field: 'slug')],
});

try {
  final validated = await validator.validateAsync();
} on ValidationException catch (e) {
  setFieldErrors(e.errors);
}
```

### The Unique Rule

`Unique(endpoint, field: ...)` issues a `GET` to the endpoint with `?{field}={value}` and treats `{"unique": true}` (or `{"available": true}`) as a pass. Network errors are logged and pass so a flaky connection never blocks the form; the server remains the source of truth on submit.

```dart
// Default HTTP resolver (GET with query param)
Unique('/validate/unique', field: 'slug');

// Custom resolver (e.g. POST to a different shape)
Unique('/validate/unique', field: 'slug').via((endpoint, field, value) async {
  final response = await Http.post(endpoint, data: {field: value});
  return response.data['unique'] == true;
});
```

### Debounce

`Unique` debounces rapid-fire calls with a default window of 400 ms. Only the last call within the window reaches the resolver; earlier calls resolve to `true` as stale and never record errors. Pass `debounce: Duration.zero` to disable debouncing entirely.

```dart
// Custom debounce window
Unique('/validate/unique', field: 'email', debounce: Duration(milliseconds: 600));

// No debounce
Unique('/validate/unique', field: 'email', debounce: Duration.zero);
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
