---
globs: ["test/**"]
---

# Testing Conventions

- Mirror source structure: `lib/src/auth/` → `test/auth/`
- Reset state in `setUp()`: `MagicApp.reset()` and `Magic.flush()`
- Use `setUpAll()` for expensive one-time setup (translator, DB)
- Mock by implementing contracts/abstract classes — no codegen mocking
- Use `flutter_test` package, not `package:test` directly
- Use Faker library for generating test data in factories
- Integration tests in `test/integration/`
