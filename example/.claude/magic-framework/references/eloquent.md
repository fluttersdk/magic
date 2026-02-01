# Eloquent ORM Reference

## Model Base

```dart
abstract class Model {
  String get table;              // Table name (required)
  String get resource;           // API resource name
  String get primaryKey => 'id';
  bool get incrementing => true;
  bool get useLocal => false;    // Local SQLite persistence
  bool get useRemote => true;    // Remote API persistence

  List<String> get fillable => [];
  List<String> get guarded => ['*'];
  Map<String, String> get casts => {};
  Map<String, Model Function()> get relations => {};
  List<String> get hidden => [];
  List<String> get visible => [];
  List<String> get appends => [];
}
```

### Mixins
- **HasTimestamps**: Auto `created_at`/`updated_at` as Carbon. Methods: `createdAt`, `updatedAt`, `touch()`
- **InteractsWithPersistence**: Active Record. Static: `findById<T>()`, `allModels<T>()`. Instance: `save()`, `delete()`, `refresh()`
- **Authenticatable**: `authIdentifier`, `authIdentifierName`, `authPassword`

### Attribute Methods
- `getAttribute(key)` / `setAttribute(key, value)` — with casting
- `get<T>(key, {defaultValue})` / `set(key, value)` — typed
- `fill(Map attributes)` — mass assign (respects fillable)
- `isDirty([attribute])` / `getDirty()` / `syncOriginal()`

### Cast Types
`datetime` → Carbon, `json` → Map, `bool` → bool, `int` → int, `double` → double

### Serialization
- `toMap()` / `toJson()` — respects hidden/visible/appends
- Handles nested models and Carbon dates

## QueryBuilder

```dart
DB.table('users')
  .select(['name', 'email'])
  .where('active', true)
  .where('age', '>=', 18)
  .whereNull('deleted_at')
  .whereNotNull('email')
  .orderBy('created_at', 'desc')
  .limit(10)
  .offset(20)
  .get();                    // List<Map>
```

### Retrieval
- `get()` → List<Map>
- `first()` → Map?
- `value<T>(column)` → T?
- `pluck<T>(column)` → List<T>
- `count()` → int
- `exists()` → bool

### Mutations
- `insert(Map data)` → int (ID)
- `insertAll(List<Map> records)` → void
- `update(Map data)` → int (affected rows)
- `delete()` → int (affected rows)
- `truncate()` → void

## Blueprint (Schema)

### Column Types
- `id([name])` — auto-increment PK
- `string(name, [length])` — TEXT
- `text(name)` — TEXT (long)
- `integer(name)` / `bigInteger(name)` — INTEGER
- `boolean(name)` — INTEGER (0/1)
- `real(name)` — REAL/FLOAT
- `blob(name)` — BLOB
- `timestamps()` — created_at + updated_at

### Modifiers
- `.nullable()` / `.unique()` / `.defaultValue(value)`

### Table Modifications
- `dropColumn(name)` (SQLite 3.35+)
- `renameColumn(from, to)` (SQLite 3.25+)

## Migrations

Naming: `m_YYYY_MM_DD_HHMMSS_{verb}_{table}_table.dart`

```dart
class CreateUsersTable extends Migration {
  @override
  void up() {
    Schema.create('users', (table) {
      table.id();
      table.string('name');
      table.timestamps();
    });
  }

  @override
  void down() {
    Schema.dropIfExists('users');
  }
}

// Run
await Migrator().run([CreateUsersTable()]);
```

## Factories

```dart
class UserFactory extends Factory<User> {
  @override
  User make() => User()..fill({
    'name': faker.person.name(),
    'email': faker.internet.email(),
  });

  UserFactory admin() => state((u) => u..set('role', 'admin'));
}

// Usage
await UserFactory().count(10).create();
await UserFactory().admin().create();
```

## Seeders

```dart
class DatabaseSeeder extends Seeder {
  @override
  Future<void> run() async {
    await UserFactory().count(50).create();
  }
}

// Run
await Magic.seed([DatabaseSeeder()]);
```
