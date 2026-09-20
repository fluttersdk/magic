# Migrations

Migrations are version-controlled schema definitions that let you create, modify, and inspect your SQLite tables using the `Schema` facade.

- [Introduction](#introduction)
- [Generating Migrations](#generating-migrations)
- [Migration Structure](#migration-structure)
- [Running Migrations](#running-migrations)
    - [The run is atomic](#the-run-is-atomic)
    - [`up()` and `down()` are synchronous](#up-and-down-are-synchronous)
- [Creating Tables](#creating-tables)
    - [Available Column Types](#available-column-types)
    - [Column Modifiers](#column-modifiers)
- [Modifying Tables](#modifying-tables)
- [Dropping Tables](#dropping-tables)
- [Checking Schema](#checking-schema)

<a name="introduction"></a>
## Introduction

Migrations are like version control for your database, allowing your team to define and share the application's database schema definition. If you have ever had to tell a teammate to manually add a column to their local database schema, you've faced the problem that database migrations solve.

<a name="generating-migrations"></a>
## Generating Migrations

Use the `make:migration` command to generate a migration:

```bash
dart run magic:artisan make:migration create_users_table
dart run magic:artisan make:migration CreateUsersTable    # PascalCase also works
dart run magic:artisan make:migration add_avatar_to_users
```

This creates a file in `lib/database/migrations/` with:
- Timestamp-prefixed filename (e.g., `m_2024_01_15_120000_create_users_table.dart`)
- Migration class with `up` and `down` methods
- Proper imports

> [!NOTE]
> Migrations starting with `create_` and ending with `_table` automatically use a special stub with `Schema.create()` boilerplate.

<a name="migration-structure"></a>
## Migration Structure

A migration class contains two methods: `up` and `down`. The `up` method adds new tables, columns, or indexes, while the `down` method should reverse the operations:

```dart
import 'package:magic/magic.dart';

class CreateUsersTable extends Migration {
  @override
  String get name => '2024_01_15_120000_create_users_table';

  @override
  void up() {
    Schema.create('users', (Blueprint table) {
      table.id();
      table.string('name');
      table.string('email').unique();
      table.string('password');
      table.boolean('is_active').defaultValue(true);
      table.timestamps();
    });
  }

  @override
  void down() {
    Schema.dropIfExists('users');
  }
}
```

### Migration Naming Convention

Use timestamp prefixes for proper ordering: `YYYY_MM_DD_HHMMSS_description`

- `2024_01_15_120000_create_users_table`
- `2024_01_15_120001_add_avatar_to_users`
- `2024_01_15_120002_rename_name_to_full_name`

<a name="running-migrations"></a>
## Running Migrations

Run your migrations in `main.dart` or a service provider:

```dart
void main() async {
  await Magic.init(...);
  
  // Run migrations
  final migrations = await Migrator().run([
    CreateUsersTable(),
    CreatePostsTable(),
    CreateCommentsTable(),
  ]);

  if (migrations.isNotEmpty) {
    Log.info('Ran ${migrations.length} migration(s)');
  }
  
  runApp(MagicApplication(...));
}
```

The `Migrator` keeps track of which migrations have already run, so calling `run()` multiple times is safe.

<a name="the-run-is-atomic"></a>
### The run is atomic

Every pending migration in one `run()` is applied inside a single transaction. If any of them throws, all of them are rolled back and the ledger records none, so the next launch retries the whole run from a clean schema rather than meeting half-applied work it cannot recognise.

That matters most when migrations run before your UI exists. A host that migrates inside `Magic.init` and then calls `runApp` has nowhere to report a failure from, and a migration that was half-applied and unrecorded would fail identically on every later launch with no way out but deleting the database.

It is a `SAVEPOINT` rather than a `BEGIN`, which is what lets it nest inside a transaction you opened yourself. Either shape works:

```dart
await Migrator().run([...]);                          // the migrator's savepoint alone
await DB.transaction(() => Migrator().run([...]));    // nested in yours
```

**A migration must not manage its own transaction.** `DB.beginTransaction`, `DB.commit` and `DB.rollback` are a supported pattern elsewhere and are not available inside `up()`: the run is already one unit. A `commit()` there closes the migrator's savepoint, which used to mean every later migration ran unprotected and the run reported a failure after fully succeeding. `run()` detects it now and throws naming the migration.

The tracking table is created before the savepoint, so a run that owns its own transaction and fails still leaves somewhere to record the retry. A host that wrapped the call in its own transaction and rolls back takes the table with it, which is harmless: every entry point creates it again.

<a name="up-and-down-are-synchronous"></a>
### `up()` and `down()` are synchronous

Writing `void up() async` compiles and is a silent defect: `run()` cannot await a `void`, so an async body is recorded complete the moment it reaches its first suspension.

The synchronous half of the schema API is what a migration uses: `Schema.create`, `Schema.table`, `Schema.drop`, `Schema.dropIfExists`, `Schema.rename`, plus `DB.statement` and `DB.select`.

The introspection helpers all answer futures and must not be called from a migration: `Schema.hasTable`, `Schema.hasColumn`, `Schema.getColumns`, and `DatabaseManager().getColumns` / `hasColumn`. To sense a schema synchronously, read the pragma directly:

```dart
final bool present = DB.select('PRAGMA table_info(users)')
    .any((Map<String, dynamic> row) => row['name'] == 'avatar');
```

A migration with no honest rollback should throw `UnsupportedError` from `down()` rather than doing nothing, or `rollback()` will delete the ledger row for a migration that is still applied.

<a name="creating-tables"></a>
## Creating Tables

Use `Schema.create()` to define a new table:

```dart
Schema.create('posts', (Blueprint table) {
  table.id();
  table.string('title');
  table.text('content').nullable();
  table.integer('user_id');
  table.boolean('is_published').defaultValue(false);
  table.timestamps();
});
```

<a name="available-column-types"></a>
### Available Column Types

| Method | SQLite Type | Description |
|--------|-------------|-------------|
| `id()` | INTEGER PRIMARY KEY | Auto-incrementing ID |
| `string(name)` | TEXT | String/varchar column |
| `text(name)` | TEXT | Long text content |
| `integer(name)` | INTEGER | Integer column |
| `bigInteger(name)` | INTEGER | Same as integer in SQLite |
| `boolean(name)` | INTEGER | 0 or 1 |
| `real(name)` | REAL | Floating point |
| `blob(name)` | BLOB | Binary data |
| `timestamps()` | TEXT × 2 | created_at & updated_at |

<a name="column-modifiers"></a>
### Column Modifiers

```dart
table.string('email').unique();          // Unique constraint
table.string('bio').nullable();          // Allow NULL
table.integer('status').defaultValue(0); // Default value
table.boolean('active').defaultValue(true);
```

<a name="modifying-tables"></a>
## Modifying Tables

Use `Schema.table()` to modify an existing table:

```dart
Schema.table('users', (Blueprint table) {
  // Add new columns
  table.string('avatar_url').nullable();
  table.string('phone').nullable();
  
  // Rename a column
  table.renameColumn('name', 'full_name');
  
  // Drop a column
  table.dropColumn('legacy_field');
});
```

> [!NOTE]
> Column dropping requires SQLite 3.35.0+ (2021). Column renaming requires SQLite 3.25.0+ (2018).

### Modifying Column Types

SQLite does not support directly modifying column types. Use the add-copy-drop pattern:

```dart
@override
void up() {
  // 1. Add new column
  Schema.table('users', (table) {
    table.string('name_new').nullable();
  });
  
  // 2. Copy data
  DB.statement('UPDATE users SET name_new = name');
  
  // 3. Drop old, rename new
  Schema.table('users', (table) {
    table.dropColumn('name');
    table.renameColumn('name_new', 'name');
  });
}
```

<a name="dropping-tables"></a>
## Dropping Tables

Use `Schema.dropIfExists()` to drop a table only when it exists (safe for `down()` methods), or `Schema.drop()` to drop unconditionally (throws if the table is absent). Use `Schema.rename()` to rename a table in place.

```dart
// Drop if exists (safe for down() methods)
Schema.dropIfExists('temporary_data');

// Drop unconditionally (throws if the table does not exist)
Schema.drop('old_table');

// Rename a table
Schema.rename('posts', 'articles');
```

<a name="checking-schema"></a>
## Checking Schema

The `Schema` facade provides three introspection helpers. `Schema.hasTable()` returns `true` when the named table exists. `Schema.hasColumn()` returns `true` when a specific column is present on the table. `Schema.getColumns()` returns the full list of column names for a table.

```dart
// Check if a table exists
if (await Schema.hasTable('users')) {
  // Safe to query users
}

// Check if a specific column exists
if (await Schema.hasColumn('users', 'avatar_url')) {
  // Column exists, safe to read it
}

// Get all column names for a table
final columns = await Schema.getColumns('users');
// ['id', 'name', 'email', 'created_at', 'updated_at']
```

> [!TIP]
> Always write both `up()` and `down()` methods to allow rolling back migrations during development.
