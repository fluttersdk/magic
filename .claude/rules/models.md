---
globs: ["lib/src/database/eloquent/**", "example/lib/models/**"]
---

# Eloquent Model Conventions

- Extend `Model`, override `table` (singular table name) and `fillable`
- Use `HasTimestamps` mixin for created_at/updated_at
- Use `InteractsWithPersistence` for save/delete operations
- Define `casts` getter for type casting (e.g., `{'is_active': 'bool'}`)
- Use factories for test data generation: `{Model}Factory`
- Models track dirty attributes — use `setAttribute()`, not direct map access
- Implement `Authenticatable` contract for auth-compatible models
