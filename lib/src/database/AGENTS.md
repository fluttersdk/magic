# DATABASE & ELOQUENT ORM

Laravel-inspired ORM with hybrid API + SQLite persistence for the Magic Framework.

## STRUCTURE

```
database/
├── connectors/          # Platform SQLite (IO/Web)
├── eloquent/
│   ├── concerns/
│   │   ├── has_timestamps.dart
│   │   └── interacts_with_persistence.dart
│   └── model.dart
├── events/              # Model lifecycle events
├── migrations/
│   ├── migration.dart
│   └── migrator.dart
├── query/
│   └── query_builder.dart
├── schema/
│   └── blueprint.dart
├── seeding/
│   ├── factory.dart
│   └── seeder.dart
├── database_manager.dart
└── database_service_provider.dart
```

## MODEL SYSTEM

**Attributes:** stored in `_attributes` (current) and `_original` (snapshot at load). Dirty tracking = diff between them.

| Method | Purpose |
|--------|---------|
| `get<T>(key)` | Typed attribute read — ALWAYS use this, never `getAttribute()` |
| `set(key, val)` | Write to `_attributes` |
| `isDirty([key])` | True if `_attributes[key] != _original[key]` |
| `getDirty()` | Map of changed attributes only |
| `syncOriginal()` | Resets `_original` to current `_attributes` (called after save/load) |

**Casting** — declare in `casts` getter:

| Cast key | Dart type | Notes |
|----------|-----------|-------|
| `datetime` | `Carbon` | ISO 8601 string ↔ Carbon |
| `json` | `Map<String, dynamic>` | JSON string ↔ Map |
| `bool` | `bool` | int 0/1 or string `"true"` |
| `int` | `int` | Safe parse |
| `double` | `double` | Safe parse |

**Relations** — declare in `relations` factory map; resolved on demand, not eager-loaded:
```dart
@override
Map<String, Function> get relations => {
    'tags': () => hasMany(Tag.new, foreignKey: 'item_id'),
};
```

**Model definition:**
```dart
class Item extends Model with HasTimestamps, InteractsWithPersistence {
  @override String get table    => 'items';
  @override String get resource => 'items';
  @override List<String> get fillable => ['name', 'status'];
  @override Map<String, String> get casts => {'created_at': 'datetime'};

  int?    get id     => get<int>('id');
  String? get name   => get<String>('name');
  set name(String? v) => set('name', v);

  static Future<Item?> find(int id) =>
      InteractsWithPersistence.findById<Item>(id, Item.new);
  static Future<List<Item>> all() =>
      InteractsWithPersistence.allModels<Item>(Item.new);
}
```

## HYBRID PERSISTENCE

**save()** — create or update:
1. `id == null` → POST `/{resource}`, get server response, set `id` + `syncOriginal()`
2. `id != null` → PUT `/{resource}/{id}`, update local SQLite row
3. Both paths write final state to local SQLite via `DatabaseManager`

**find(id):**
1. Query local SQLite → if hit, hydrate model + `syncOriginal()`, return
2. Miss → GET `/{resource}/{id}` from API → insert into local SQLite → return hydrated model

**delete():** DELETE `/{resource}/{id}` → remove local SQLite row.

**allModels():** Queries local SQLite; caller responsible for prior API sync.

## QUERY BUILDER

`DB.table('items')` returns a `QueryBuilder`. Schema-aware: auto-strips columns not in actual table schema before `insert`/`update`.

**Chaining API:**

| Method | Notes |
|--------|-------|
| `.where(col, [op], val)` | Default op `=` |
| `.whereNull(col)` | WHERE col IS NULL |
| `.orderBy(col, [dir])` | dir: `asc` \| `desc` |
| `.limit(n)` / `.offset(n)` | Pagination |
| `.get()` | `Future<List<Map>>` |
| `.first()` | `Future<Map?>` |
| `.value<T>(col)` | Single scalar |
| `.pluck<T>(col)` | `Future<List<T>>` |
| `.count()` | `Future<int>` |
| `.exists()` | `Future<bool>` |
| `.insert(Map)` | Returns inserted id |
| `.update(Map)` | Returns affected rows |
| `.delete()` | Returns affected rows |
| `.truncate()` | Deletes all rows, no return |

## MIGRATIONS

```dart
class CreateItemsTable extends Migration {
  @override
  Future<void> up() async {
    await Schema.create('items', (Blueprint table) {
      table.id();
      table.string('name');
      table.string('status').nullable();
      table.timestamps();
    });
  }

  @override
  Future<void> down() async => Schema.dropIfExists('items');
}
```

**Blueprint methods:** `id()`, `string(col)`, `integer(col)`, `boolean(col)`, `text(col)`, `timestamps()`, `.nullable()`, `.defaultValue(v)`.

## FACTORIES & SEEDERS

```dart
class ItemFactory extends Factory<Item> {
  @override
  Map<String, dynamic> definition() => {'name': faker.food.dish()};
}

class ItemSeeder extends Seeder {
  @override
  Future<void> run() async => ItemFactory().count(10).create();
}
```

Run via `DatabaseManager.seed([ItemSeeder()])` in boot phase.

## GOTCHAS

- `get<T>()` returns `null` for missing keys — never throws; guard with `!` only when certain.
- Schema-aware filtering runs on every `insert`/`update` — columns not in SQLite schema are silently dropped.
- `syncOriginal()` must be called after manual hydration or dirty tracking breaks.
- Web uses in-memory SQLite (drift); mobile uses file-based — migrations run on both.
- `relations` map is lazy — access via `getRelation('tags')`, not direct map lookup.
- `HasTimestamps` auto-sets `created_at` / `updated_at` as ISO 8601 strings on save.
- Migration filenames: `m_YYYY_MM_DD_HHMMSS_{verb}_{table}_table.dart`.
