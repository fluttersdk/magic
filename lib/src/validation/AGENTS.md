# VALIDATION SYSTEM

Rules-based validator with Flutter FormField integration and Laravel 422 error mapping.

## STRUCTURE

```
validation/
├── validator.dart           # Core validation engine
├── form_validator.dart      # Flutter FormField integration
├── contracts/
│   └── rule.dart           # Rule interface
├── exceptions/
│   └── validation_exception.dart
└── rules/                   # Built-in rules: required, email, min, max, confirmed, same, accepted
```

## VALIDATOR

```dart
final validator = Validator.make(
    {'email': 'test', 'name': ''},
    {'email': ['required', 'email'], 'name': ['required', 'min:2']},
);
if (validator.fails()) {
    print(validator.errors()); // {'email': 'The email must be a valid email', 'name': 'The name is required'}
}
```

| Method | Returns | Notes |
|--------|---------|-------|
| `Validator.make(data, rules)` | `Validator` | Factory constructor |
| `fails()` / `passes()` | `bool` | Inverse pair |
| `validate()` | `void` | Throws `ValidationException` on failure |
| `errors()` | `Map<String, String>` | First failure per field only |

## FORM VALIDATOR

`FormValidator` bridges `Validator` and Flutter's `FormField.validator` callback.

```dart
FormValidator.make(rules: ['required', 'email'])
// Returns: String? Function(String?) -- plug directly into TextFormField.validator
```

Use inside `MagicForm` for automatic state wiring and server error overlay.

## RULES

| Rule | Syntax | Notes |
|------|--------|-------|
| `required` | `'required'` | Rejects null, empty string |
| `email` | `'email'` | RFC-compliant format check |
| `min` / `max` | `'min:2'` | Length (string) or value (num) |
| `confirmed` | `'confirmed'` | Matches `{field}_confirmation` sibling key |
| `same` | `'same:other'` | Matches another field value |
| `accepted` | `'accepted'` | Must be `true`, `1`, `'yes'`, or `'on'` |

Custom rules: implement `Rule` contract from `contracts/rule.dart` (`validate(field, value, data)` signature).

## ATTRIBUTE HUMANIZATION

`_humanizeAttribute` runs on every field name before injecting into messages:
1. Looks up `attributes.{field}` in `Lang` -- override for translated labels.
2. Falls back to replacing `_` with spaces: `first_name` -> "first name".

## I18N INTEGRATION

Messages are translation keys resolved via `Lang.get()`. Placeholders: `:attribute`, `:min`, `:max`.
Key pattern: `validation.required`, `validation.email`, `validation.min.string`.
Override in `assets/lang/{locale}/validation.json`.

## SERVER ERROR MAPPING

`ValidatesRequests` mixin (in `concerns/validates_requests.dart`) parses Laravel 422 responses:

```dart
setErrorFromResponse(response); // Maps res.errors fields onto setError() calls
```

`MagicFormData.setServerErrors(Map<String, List<String>>)` overlays server messages
onto form fields inline -- first message per field wins.

## GOTCHAS

- `errors()` returns only the first failure per field, not all.
- `nullable` must appear before other rules or it has no effect.
- `confirmed` requires `{field}_confirmation` as a sibling key in `data`.
- `validate()` throws `ValidationException` -- catch or let `MagicController` handle.
- Custom rules receive raw values -- never assume type, cast defensively.
