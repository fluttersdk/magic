# Database: Getting Started

## Introduction

Magic provides a simple, elegant abstraction layer for working with SQLite databases. Using the `DB` facade, you may build queries using a fluent syntax that feels natural to Laravel developers.

The database layer is designed with **schema-awareness** in mind: when inserting or updating data, any columns that don't exist in your database are automatically filtered out, preventing crashes from unexpected fields.

## Enabling Database Support

By default, the database service provider is **not enabled**. You can enable it using the Magic CLI:

```bash
magic init:database
```

This command will:
- Create `config/database.dart` with default settings
- Add `DatabaseServiceProvider` to your providers
- Set up the migrations directory

### Manual Setup

Alternatively, add the provider manually to your `config/app.dart`:

```dart
'providers': [
  (app) => DatabaseServiceProvider(app),
],
```

## Configuration

Your database configuration is located in `lib/config/database.dart`:

```dart
final databaseConfig = {
  'database': {
    'default': 'sqlite',
    'connections': {
      'sqlite': {
        'driver': 'sqlite',
        'database': 'magic_app.db',
        'prefix': '',
      }
    }
  }
};
```

## Web Platform Setup

For web support, you must download `sqlite3.wasm` from the [sqlite3 package releases](https://github.com/simolus3/sqlite3.dart/releases) and place it in your project's `web/` folder.

## Running Raw SQL Queries

### Select Queries

```dart
final results = DB.select(
  'SELECT * FROM users WHERE age > ?',
  [18],
);
```

### Insert Statements

```dart
final id = DB.insert(
  'INSERT INTO users (name, email) VALUES (?, ?)',
  ['John', 'john@example.com'],
);
```

### General Statements

```dart
DB.statement('DROP TABLE IF EXISTS temp_data');
```

## Database Transactions

You may use the `transaction` method to run operations within a transaction. If an exception is thrown, it's automatically rolled back:

```dart
await DB.transaction(() async {
  await DB.table('users').insert({'name': 'John'});
  await DB.table('profiles').insert({'user_id': 1, 'bio': 'Hello'});
});
```

### Manual Transaction Control

```dart
DB.beginTransaction();
try {
  await DB.table('users').insert({...});
  await DB.table('profiles').insert({...});
  DB.commit();
} catch (e) {
  DB.rollback();
  rethrow;
}
```
