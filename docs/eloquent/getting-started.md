# Eloquent: Getting Started

- [Introduction](#introduction)
- [Generating Models](#generating-models)
- [Defining Models](#defining-models)
    - [Table Names](#table-names)
    - [Primary Keys](#primary-keys)
    - [Fillable Attributes](#fillable-attributes)
- [Attribute Casting](#attribute-casting)
- [Retrieving Models](#retrieving-models)
- [Inserting & Updating](#inserting--updating)
- [Deleting Models](#deleting-models)
- [Hybrid Persistence](#hybrid-persistence)

<a name="introduction"></a>
## Introduction

Magic's Eloquent ORM provides a beautiful, simple Active Record implementation for working with your database. Each database table has a corresponding "Model" which is used to interact with that table. Models allow you to query for data, insert new records, and update existing ones.

Unlike traditional ORMs, Magic's Eloquent supports **Hybrid Persistence**. Your models can persist to a local SQLite database, a remote REST API, or both—giving you offline-first capabilities out of the box.

<a name="generating-models"></a>
## Generating Models

To generate a new model, use the `make:model` Magic CLI command:

```bash
magic make:model Post
```

### Available Options

| Option | Shortcut | Description |
|--------|----------|-------------|
| `--migration` | `-m` | Create a database migration |
| `--seeder` | `-s` | Create a database seeder |
| `--factory` | `-f` | Create a model factory |
| `--controller` | `-c` | Create a controller |
| `--policy` | `-p` | Create a policy |
| `--all` | `-a` | Create all related files |

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
- `lib/resources/views/product/` (index, show, create, edit)

<a name="defining-models"></a>
## Defining Models

Models typically live in the `lib/app/models` directory:

```dart
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

class User extends Model with HasTimestamps, InteractsWithPersistence {
  @override
  String get table => 'users';

  @override
  String get resource => 'users';

  @override
  List<String> get fillable => ['name', 'email', 'avatar'];

  @override
  Map<String, String> get casts => {
    'email_verified_at': 'datetime',
    'is_active': 'bool',
    'settings': 'json',
  };

  // Typed accessors
  String? get name => getAttribute('name') as String?;
  set name(String? value) => setAttribute('name', value);

  String? get email => getAttribute('email') as String?;
  Carbon? get emailVerifiedAt => getAttribute('email_verified_at') as Carbon?;
  bool get isActive => getAttribute('is_active') as bool? ?? false;

  // Static helpers (required for type-safe queries)
  static Future<User?> find(dynamic id) =>
      InteractsWithPersistence.findById<User>(id, User.new);

  static Future<List<User>> all() =>
      InteractsWithPersistence.allModels<User>(User.new);
}
```

<a name="table-names"></a>
### Table Names

The `table` property specifies which database table corresponds to your model:

```dart
@override
String get table => 'users';
```

<a name="primary-keys"></a>
### Primary Keys

By default, Eloquent assumes your primary key is `id`. You may override this:

```dart
@override
String get primaryKey => 'user_id';

@override
bool get incrementing => false; // For UUID keys
```

<a name="fillable-attributes"></a>
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

<a name="attribute-casting"></a>
## Attribute Casting

The `casts` property converts attributes to common data types:

```dart
@override
Map<String, String> get casts => {
  'created_at': 'datetime',   // Returns Carbon
  'updated_at': 'datetime',
  'is_active': 'bool',        // Returns bool
  'settings': 'json',         // Returns Map
  'age': 'int',               // Returns int
  'price': 'double',          // Returns double
};
```

### Available Cast Types

| Cast | Returns |
|------|---------|
| `datetime` | `Carbon` (Magic's date/time wrapper) |
| `bool` | `bool` |
| `int` | `int` |
| `double` | `double` |
| `json` | `Map<String, dynamic>` or `List` |

### Accessing Cast Attributes

```dart
final user = await User.find(1);

Carbon? createdAt = user.createdAt;       // Carbon instance
bool isActive = user.isActive;             // bool
Map<String, dynamic> settings = user.settings; // Map
```

<a name="retrieving-models"></a>
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

### Refreshing Models

Reload a model's attributes from the database:

```dart
await user.refresh();
```

<a name="inserting--updating"></a>
## Inserting & Updating

### Inserting Models

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

### Updating Models

To update an existing model, retrieve it, modify attributes, and call `save()`:

```dart
final user = await User.find(1);

if (user != null) {
  user.name = 'Updated Name';
  await user.save();
}
```

### Dirty Checking

Track which attributes have changed:

```dart
final user = await User.find(1);

print(user.isDirty());       // false

user.name = 'New Name';

print(user.isDirty());       // true
print(user.isDirty('name')); // true
print(user.getDirty());      // {'name': 'New Name'}
```

<a name="deleting-models"></a>
## Deleting Models

```dart
final user = await User.find(1);

if (user != null) {
  await user.delete();
  print(user.exists); // false
}
```

<a name="hybrid-persistence"></a>
## Hybrid Persistence

Magic's unique feature is hybrid persistence—syncing between local SQLite and remote REST API.

### Configuration

Control where your model persists:

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

### API Resource Endpoint

The `resource` property maps to your REST API:

```dart
@override
String get resource => 'users';

// Maps to:
// GET    /users        -> all()
// GET    /users/{id}   -> find(id)
// POST   /users        -> save() (insert)
// PUT    /users/{id}   -> save() (update)
// DELETE /users/{id}   -> delete()
```

### How Hybrid Mode Works

When using hybrid mode:

1. **Read operations** check local database first, then sync from API
2. **Write operations** persist to both local and remote
3. **Offline support** is automatic—writes queue until online

> [!TIP]
> Use hybrid mode for offline-first apps that sync to a backend API.
