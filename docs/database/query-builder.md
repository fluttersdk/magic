# Query Builder

## Introduction

Magic's database query builder provides a convenient, fluent interface to creating and running database queries. It can be used to perform most database operations in your application.

## Retrieving Results

### Retrieving All Rows

Use the `table` method on the `DB` facade to begin a query. The `get` method returns all results:

```dart
final users = await DB.table('users').get();

for (final user in users) {
  print(user['name']);
}
```

### Retrieving A Single Row

If you just need a single row, use the `first` method:

```dart
final user = await DB.table('users').where('id', 1).first();

if (user != null) {
  print(user['email']);
}
```

### Retrieving A Single Column Value

Use the `value` method to retrieve a single column's value:

```dart
final email = await DB.table('users')
    .where('id', 1)
    .value<String>('email');
```

### Retrieving A List Of Column Values

The `pluck` method retrieves all values for a single column:

```dart
final emails = await DB.table('users').pluck<String>('email');
// ['john@example.com', 'jane@example.com', ...]
```

## Selects

### Specifying A Select Clause

You may specify which columns to retrieve:

```dart
final users = await DB.table('users')
    .select(['name', 'email'])
    .get();
```

## Where Clauses

### Simple Where Clauses

You may use the `where` method to add conditions to your query:

```dart
final users = await DB.table('users')
    .where('status', 'active')
    .get();
```

You may also pass an operator:

```dart
final users = await DB.table('users')
    .where('age', '>=', 18)
    .get();
```

### Multiple Where Clauses

You may chain multiple `where` calls. They are combined using `AND`:

```dart
final users = await DB.table('users')
    .where('status', 'active')
    .where('role', 'admin')
    .get();
```

### Where Null / Where Not Null

```dart
// Users without a deleted_at timestamp
final activeUsers = await DB.table('users')
    .whereNull('deleted_at')
    .get();

// Users with an email set
final verified = await DB.table('users')
    .whereNotNull('email')
    .get();
```

## Ordering, Limiting & Offsetting

### Ordering

You may use the `orderBy` method to sort results:

```dart
final users = await DB.table('users')
    .orderBy('created_at', 'desc')
    .get();
```

### Limit & Offset

You may use `limit` and `offset` for pagination:

```dart
final users = await DB.table('users')
    .limit(10)
    .offset(20)  // Skip first 20 records
    .get();
```

## Aggregates

### Count

```dart
final count = await DB.table('users')
    .where('is_active', true)
    .count();
```

### Exists

```dart
if (await DB.table('users').where('email', email).exists()) {
  throw Exception('Email already in use');
}
```

## Inserts

### Basic Insert

The `insert` method returns the last insert ID:

```dart
final id = await DB.table('users').insert({
  'name': 'John Doe',
  'email': 'john@example.com',
  'created_at': Carbon.now().toIso8601String(),
});
```

### Schema-Aware Inserts

Unknown columns are automatically filtered out, preventing errors:

```dart
await DB.table('users').insert({
  'name': 'John',
  'email': 'john@example.com',
  'unknown_field': 'this will be filtered out',
});
```

### Insert Multiple Records

```dart
await DB.table('users').insertAll([
  {'name': 'John', 'email': 'john@example.com'},
  {'name': 'Jane', 'email': 'jane@example.com'},
]);
```

## Updates

The `update` method returns the number of affected rows:

```dart
final affected = await DB.table('users')
    .where('id', 1)
    .update({'name': 'Updated Name'});
```

## Deletes

```dart
final deleted = await DB.table('users')
    .where('id', 1)
    .delete();
```

### Truncate

To delete all rows from a table:

```dart
await DB.table('logs').truncate();
```
