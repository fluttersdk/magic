# Database: Getting Started

- [Introduction](#introduction)
- [Configuration](#configuration)
- [Running Raw Queries](#running-raw-queries)
    - [Select Queries](#select-queries)
    - [Insert Statements](#insert-statements)
    - [Update & Delete](#update--delete)
- [Query Builder](#query-builder)
- [Transactions](#transactions)
- [Web Platform Setup](#web-platform-setup)

<a name="introduction"></a>
## Introduction

Magic provides a simple, elegant abstraction layer for working with SQLite databases. Using the `DB` facade, you can build queries using a fluent syntax that feels natural to Laravel developers.

The database layer is designed with **schema-awareness** in mind: when inserting or updating data, any columns that don't exist in your database are automatically filtered out, preventing crashes from unexpected fields.

<a name="configuration"></a>
## Configuration

### Enabling Database Support

Add `DatabaseServiceProvider` to your providers in `config/app.dart`:

```dart
'providers': [
  (app) => DatabaseServiceProvider(app),
  // ... other providers
],
```

### Database Configuration

Create `lib/config/database.dart`:

```dart
Map<String, dynamic> get databaseConfig => {
  'database': {
    'default': 'sqlite',
    'connections': {
      'sqlite': {
        'driver': 'sqlite',
        'database': 'magic_app.db',
        'prefix': '',
      },
    },
  },
};
```

<a name="running-raw-queries"></a>
## Running Raw Queries

<a name="select-queries"></a>
### Select Queries

```dart
// Simple select
final users = DB.select('SELECT * FROM users');

// With parameters (prevents SQL injection)
final adults = DB.select(
  'SELECT * FROM users WHERE age > ?',
  [18],
);


```

<a name="insert-statements"></a>
### Insert Statements

```dart
final id = DB.insert(
  'INSERT INTO users (name, email) VALUES (?, ?)',
  ['John Doe', 'john@example.com'],
);

print('Inserted user with ID: $id');
```

<a name="update--delete"></a>
### Update & Delete

```dart
// Update
final affected = DB.update(
  'UPDATE users SET name = ? WHERE id = ?',
  ['Jane Doe', userId],
);

// Delete
final deleted = DB.delete(
  'DELETE FROM users WHERE id = ?',
  [userId],
);
```

### General Statements

```dart
// DDL statements
DB.statement('DROP TABLE IF EXISTS temp_data');
DB.statement('CREATE INDEX idx_email ON users(email)');
```

<a name="query-builder"></a>
## Query Builder

Magic provides a fluent query builder for common operations:

```dart
// Select all
final users = await DB.table('users').get();

// With conditions
final activeUsers = await DB.table('users')
    .where('is_active', true)
    .get();

// Select specific columns
final names = await DB.table('users')
    .select(['id', 'name'])
    .get();

// Insert
await DB.table('users').insert({
  'name': 'John',
  'email': 'john@example.com',
});

// Update
await DB.table('users')
    .where('id', userId)
    .update({'name': 'Updated Name'});

// Delete
await DB.table('users')
    .where('id', userId)
    .delete();
```

### Where Clauses

```dart
// Basic where
DB.table('users').where('status', 'active');

// With operator
DB.table('users').where('age', '>=', 18);

// Multiple conditions
DB.table('users')
    .where('status', 'active')
    .where('age', '>=', 18);


```

### Ordering & Limiting

```dart
final users = await DB.table('users')
    .orderBy('created_at', 'desc')
    .limit(10)
    .offset(20)
    .get();
```

<a name="transactions"></a>
## Transactions

Use transactions to ensure multiple operations succeed or fail together:

```dart
await DB.transaction(() async {
  await DB.table('users').insert({'name': 'John'});
  await DB.table('profiles').insert({
    'user_id': 1,
    'bio': 'Hello world',
  });
});
```

If any operation throws an exception, the entire transaction is rolled back.

### Manual Transaction Control

```dart
DB.beginTransaction();

try {
  await DB.table('accounts').update({'balance': newBalance});
  await DB.table('transactions').insert({...});
  DB.commit();
} catch (e) {
  DB.rollback();
  rethrow;
}
```

<a name="web-platform-setup"></a>
## Web Platform Setup

For web platform support, you must download `sqlite3.wasm` from the [sqlite3 package releases](https://github.com/simolus3/sqlite3.dart/releases) and place it in your project's `web/` folder.

```
web/
├── index.html
├── sqlite3.wasm  ← Required for web
└── ...
```

> [!WARNING]
> The web platform uses an in-memory SQLite database. Data is not persisted between page reloads unless you implement custom persistence.
