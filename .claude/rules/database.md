---
paths: "lib/src/database/eloquent/**/*.dart"
---

# Database Domain (Eloquent ORM)

- `Model` is abstract: subclass with `table`, `resource` overrides. Add `HasTimestamps`, `InteractsWithPersistence` mixins as needed
- Typed accessors: `String get name => getAttribute('name');` / `set name(String val) => setAttribute('name', val);`
- Shorthand alias: `set('key', value)` calls `setAttribute()` internally
- Mass assignment: use `fillable` (whitelist) OR `guarded` (blacklist `['*']` default), never both
- Casts map: `'datetime'` → Carbon, `'json'` → Map, `'bool'` → bool, `'int'` → int, `'double'` → double
- Relations: `Map<String, Model Function()> get relations => {'user': User.new}`, auto-cast from API responses
- `exists` flag: set `true` after `fromMap()` for persisted models, controls insert vs update
- `useLocal` / `useRemote` toggles: `useRemote` = API persistence (default); `useLocal` = local persistence through the `LocalModelStore` contract (`'local_model_store'`), bound by `magic_local_storage`. Nothing bound throws a `StateError`
- `dirty` tracking: `isDirty`, `getDirty()`, `getOriginal()`, comparing `_attributes` vs `_original`
- Hidden/visible: `hidden` excludes from `toMap()`, `visible` restricts to whitelist. Hidden takes priority
