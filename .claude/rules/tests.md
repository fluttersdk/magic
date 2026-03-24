---
path: "test/**/*.dart"
---

# Testing Domain

- `setUp()`: always `MagicApp.reset()` + `Magic.flush()` — clears IoC container and facade caches between tests
- Mock via contract inheritance, never code generation (no mockito). Implement the abstract class directly
- Test structure mirrors `lib/src/` exactly: `test/auth/`, `test/database/`, `test/http/`, etc.
- Controller tests: `Magic.put<T>(controller)` to inject, then verify state transitions and `rxStatus` changes
- Model tests: verify `getAttribute()`/`setAttribute()`, `fillable`/`guarded` mass assignment, `casts`, `toMap()`/`fromMap()`
- Middleware tests: instantiate `MagicMiddleware` subclass, call `handle(next)` with mock `next` callback, assert next was/wasn't called
- ServiceProvider tests: create `MagicApp.instance`, register provider, verify bindings with `app.make<T>('key')`
- Validation tests: `Validator.make(data, rules)`, assert `fails()`/`passes()`, check `errors()` map
- UI tests: `testWidgets()`, pump widget tree with `MaterialApp` wrapper. `Magic.put()` controllers in setUp
- Event tests: register listener factory, dispatch event, verify listener `handle()` was called
- Integration tests in `test/integration/` — test full lifecycle flows (init → use → teardown)
- Use `group()` for logical grouping by feature/scenario. `test()` for pure logic, `testWidgets()` for widgets
- Always `await` for: `tester.pumpWidget()`, `tester.tap()`, `tester.pump()`, `tester.pumpAndSettle()`
