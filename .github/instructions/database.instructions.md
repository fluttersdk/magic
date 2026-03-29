---
name: 'Database Conventions'
description: 'Database domain -- Eloquent ORM, QueryBuilder, migrations, seeders'
applyTo: 'lib/src/database/**/*.dart'
---

# Database Domain (Eloquent ORM)

- `Model` is abstract — subclass with `table`, `resource` overrides. Add `HasTimestamps`, `InteractsWithPersistence` mixins as needed
- Typed accessors: `String get name => getAttribute('name');` / `set name(String val) => setAttribute('name', val);`
- Shorthand alias: `set('key', value)` calls `setAttribute()` internally
- Mass assignment: use `fillable` (whitelist) OR `guarded` (blacklist `['*']` default), never both
- Casts map: `'datetime'` → Carbon, `'json'` → Map, `'bool'` → bool, `'int'` → int, `'double'` → double
- Relations: `Map<String, Model Function()> get relations => {'user': User.new}` — auto-cast from API responses
- `exists` flag: set `true` after `fromMap()` for persisted models, controls insert vs update
- `useLocal` / `useRemote` toggles: `useLocal` = SQLite persistence, `useRemote` = API persistence. Both can be true
- QueryBuilder: fluent chaining — `.table('users').where('active', true).orderBy('name').get()`
- QueryBuilder CRUD: `.insert(data)`, `.update(data)`, `.delete()`. Returns `Map<String, dynamic>` or `List<Map>`
- Migrations: extend base Migration, implement `up()` / `down()` with `Schema` facade calls
- Seeders: extend Seeder, implement `run()`. Use Factory for bulk test data
- Connectors: platform-specific — `NativeConnector` (mobile), `WebConnector` (in-memory SQLite for web)
- `DatabaseServiceProvider` auto-registers. Config key: `database.default` for driver name
- `dirty` tracking: `isDirty`, `getDirty()`, `getOriginal()` — compares `_attributes` vs `_original`
- Hidden/visible: `hidden` excludes from `toMap()`, `visible` restricts to whitelist. Hidden takes priority
