# Eloquent: Getting Started

## Introduction

Magic's Eloquent ORM provides a beautiful, simple Active Record implementation for working with your database. Each database table has a corresponding "Model" which is used to interact with that table. Models allow you to query for data, insert new records, and update existing ones.

Unlike traditional ORMs, Magic's Eloquent supports **Hybrid Persistence**. Your models can persist to a local SQLite database, a remote REST API, or both—giving you offline-first capabilities out of the box.

## Generating Models

You may use the `make:model` command to generate a new model:

```bash
magic make:model Post
magic make:model User --migration      # Also create migration
magic make:model Todo --all            # Create everything
```

### Available Options

| Option | Shortcut | Description |
|--------|----------|-------------|
| `--migration` | `-m` | Create a database migration |
| `--seed` | `-s` | Create a database seeder |
| `--factory` | `-f` | Create a model factory |
| `--controller` | `-c` | Create a controller |
| `--resource` | `-r` | Create a resource controller with views |
| `--all` | `-a` | Create migration, seeder, factory, policy, and resource controller |

**Output:** Creates `lib/app/models/<name>.dart`

### The `--all` Flag

The `-a` flag is the most convenient way to scaffold a complete feature:

```bash
magic make:model Product --all
```

This single command creates:
- `lib/app/models/product.dart`
- `lib/database/migrations/m_<timestamp>_create_products_table.dart`
- `lib/database/seeders/product_seeder.dart`
- `lib/database/factories/product_factory.dart`
- `lib/app/policies/product_policy.dart`
- `lib/app/controllers/product_controller.dart`
- `lib/resources/views/product/index_view.dart`
- `lib/resources/views/product/show_view.dart`
- `lib/resources/views/product/create_view.dart`
- `lib/resources/views/product/edit_view.dart`

### Generating Typed Accessors

After defining your model's `fillable` and `casts`, use `make:model-types` to generate typed getters and setters:

```bash
magic make:model-types Order
```

This parses your model and generates typed accessors based on the `fillable` list and `casts` map, replacing the Typed Accessors section in your model file.

## Defining Models

Models typically live in the `lib/app/models` directory:

```dart
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

class User extends Model with HasTimestamps, InteractsWithPersistence {
  @override
  String get table => 'users';

  @override
  String get resource => 'users';
}
```

### Table Names

The `table` property specifies which database table corresponds to your model:

```dart
@override
String get table => 'users';
```

### API Resources

The `resource` property specifies the REST API endpoint for remote operations:

```dart
@override
String get resource => 'users'; // Maps to /users, /users/{id}
```

### Primary Keys

By default, Eloquent assumes your primary key is `id`. You may override this:

```dart
@override
String get primaryKey => 'user_id';

@override
bool get incrementing => false; // For UUID keys
```

### Hybrid Persistence

Control where your model persists data:

```dart
// Local database only (offline mode)
@override
bool get useLocal => true;
@override
bool get useRemote => false;

// Remote API only (online mode)
@override
bool get useLocal => false;
@override
bool get useRemote => true;

// Both (hybrid mode - default)
@override
bool get useLocal => true;
@override
bool get useRemote => true;
```

## Retrieving Models

### Retrieving All Models

```dart
final users = await User.all();

for (final user in users) {
  print(user.name);
}
```

### Retrieving A Single Model

```dart
final user = await User.find(1);

if (user != null) {
  print(user.name);
}
```

> **Note**  
> When using hybrid mode, `find()` checks the local database first. If not found, it queries the remote API and syncs locally.

## Inserting & Updating Models

### Inserts

To create a new record, instantiate a model, set attributes, and call `save()`:

```dart
final user = User()
  ..fill({
    'name': 'John Doe',
    'email': 'john@example.com',
  });

await user.save();

print(user.id); // The new auto-generated ID
```

### Updates

To update an existing model, retrieve it, modify attributes, and call `save()`:

```dart
final user = await User.find(1);

if (user != null) {
  user.name = 'Updated Name';
  await user.save();
}
```

## Mass Assignment

### Fillable Attributes

Define which attributes can be mass-assigned:

```dart
@override
List<String> get fillable => ['name', 'email', 'avatar'];
```

Only these attributes will be set when using `fill()`:

```dart
user.fill({
  'name': 'John',
  'email': 'john@example.com',
  'is_admin': true, // Ignored - not in fillable
});
```

### Guarded Attributes

Alternatively, use `guarded` to block specific attributes:

```dart
@override
List<String> get guarded => ['is_admin', 'password'];
```

## Deleting Models

```dart
final user = await User.find(1);

if (user != null) {
  await user.delete();
  print(user.exists); // false
}
```

## Refreshing Models

Reload a model's attributes from the database:

```dart
await user.refresh();
```

## Dirty Checking

Track which attributes have changed since retrieval:

```dart
final user = await User.find(1);

print(user.isDirty());       // false

user.name = 'New Name';

print(user.isDirty());       // true
print(user.isDirty('name')); // true
print(user.getDirty());      // {'name': 'New Name'}
```
