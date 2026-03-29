---
name: 'Validation Conventions'
description: 'Validation domain -- rules, validator, form integration'
applyTo: 'lib/src/validation/**/*.dart'
---

# Validation Domain

- `Validator.make(Map<String, dynamic> data, Map<String, List<Rule>> rules)` — factory constructor, returns Validator
- `Rule` abstract contract: `bool passes(String attribute, dynamic value)` + `String message()` — implement both
- Built-in rules: `Required`, `Email`, `Min(int)`, `Max(int)`, `Confirmed`, `Numeric`, `StringRule` — no `In()` rule exists
- `validator.fails()` runs validation once (cached). Returns `true` if any rule failed
- `validator.passes()` — inverse of `fails()`
- `validator.errors()` — returns `Map<String, String>` of field → error message (first failure per field)
- `validator.validate()` — throws `ValidationException` if fails. Use for fail-fast flows
- `ValidationException` has `.errors` map and `.message` getter
- Message resolution: `rule.message()` → check `Lang.has(key)` → `Lang.get(key, params)` → fallback raw string
- `:attribute` placeholder in messages replaced with humanized field name (snake_case → Title Case)
- Custom rules: implement `Rule` contract. One rule class per validation concern
- Rules receive full data map context — enables cross-field validation (e.g., `Confirmed` checks `password_confirmation`)
- `FormValidator` wraps Validator for Flutter Form integration — used internally by `MagicForm`
- Rule files live in `rules/` subdirectory, contracts in `contracts/`, exceptions in `exceptions/`
