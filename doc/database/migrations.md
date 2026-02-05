# Migrations

- [Introduction](#introduction)
- [Generating Migrations](#generating-migrations)
- [Migration Structure](#migration-structure)
- [Running Migrations](#running-migrations)
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
magic make:migration create_users_table
magic make:migration CreateUsersTable    # PascalCase also works
magic make:migration add_avatar_to_users
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
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

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

```dart
// Drop if exists (safe)
Schema.dropIfExists('temporary_data');

// Drop (throws if not exists)
Schema.drop('old_table');

// Rename table
Schema.rename('posts', 'articles');
```

<a name="checking-schema"></a>
## Checking Schema

```dart
// Check if table exists
if (await Schema.hasTable('users')) {
  // Table exists
}

// Check if column exists
if (await Schema.hasColumn('users', 'avatar_url')) {
  // Column exists
}

// Get all column names
final columns = await Schema.getColumns('users');
for (final col in columns) {
  print(col); // 'id', 'name', etc.
}
```

> [!TIP]
> Always write both `up()` and `down()` methods to allow rolling back migrations during development.
