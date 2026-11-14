# Eloquent: Getting Started

Eloquent is Magic's active-record ORM: define models as Dart classes, run queries with a fluent builder, and persist to a remote REST backend, or to local storage with the `magic_local_storage` plugin, using the same model interface.

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
- [Local Storage](#local-storage)

<a name="introduction"></a>
## Introduction

Magic's Eloquent ORM provides a beautiful, simple Active Record implementation for working with your data. Each model maps to a REST resource and, optionally, to a local table. Models allow you to query for data, insert new records, and update existing ones.

Models are API-first: they persist to a remote REST API by default. Magic's Eloquent also supports **Hybrid Persistence**, where a model persists to local storage, a remote REST API, or both. The local leg ships in the `magic_local_storage` plugin (see [Local Storage](#local-storage)).

<a name="generating-models"></a>
## Generating Models

To generate a new model, use the `make:model` Magic CLI command:

```bash
dart run magic:dowel make:model Post
```

### Available Options

| Option | Shortcut | Description |
|--------|----------|-------------|
| `--migration` | `-m` | Create a database migration (needs `magic_local_storage`) |
| `--seeder` | `-s` | Create a database seeder (needs `magic_local_storage`) |
| `--factory` | `-f` | Create a model factory (needs `magic_local_storage`) |
| `--controller` | `-c` | Create a controller |
| `--policy` | `-p` | Create a policy |
| `--all` | `-a` | Create all related files |

### The `--all` Flag

The `-a` flag is the most convenient way to scaffold a complete feature:

```bash
dart run magic:dowel make:model Product --all
```

This single command creates:
- `lib/app/models/product.dart`
- the migration, seeder and factory (when `magic_local_storage` is installed; otherwise a hint is printed)
- `lib/app/policies/product_policy.dart`
- `lib/app/controllers/product_controller.dart`
- `lib/resources/views/product/` (index, show, create, edit)

<a name="defining-models"></a>
## Defining Models

Models typically live in the `lib/app/models` directory:

```dart
import 'package:magic/magic.dart';

class User extends Model with HasTimestamps, InteractsWithPersistence {
  @override
  String get table => 'users';

  @override
  String get resource => 'users';

  @override
  List<String> get fillable => ['name', 'email', 'avatar'];

  @override
  Map<String, String> get casts => const {
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

The `table` property specifies which local table corresponds to your model when `useLocal` is on:

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

Pass `strict: true` to turn silent drops into a `MassAssignmentException`. Useful when filling from validated request payloads, where an unknown key signals a client/schema mismatch you want to surface loudly:

```dart
user.fill(validated, strict: true); // throws if validated contains a non-fillable key
```

<a name="attribute-casting"></a>
## Attribute Casting

The `casts` property converts attributes to common data types. Return a `const` literal: `getAttribute` reads `casts` on every call, so a non-const map literal allocates on every attribute read.

```dart
@override
Map<String, String> get casts => const {
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

Reload a model's attributes from its persistence layer:

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

### Validation Errors

`save()` returns a `bool`, which tells you *that* a remote save failed but not *why*. When the backend answers with Laravel's validation shape (`{"message": ..., "errors": {"field": ["message"]}}`, typically a 422), the per-field messages are captured on the model so a form can render them under the matching fields:

```dart
final monitor = Monitor()..fill({'name': '', 'url': 'not-a-url'});

if (!await monitor.save()) {
  monitor.validationErrors;              // {'name': ['The name field is required.'], ...}
  monitor.validationError('name');       // 'The name field is required.' (first message)
}
```

`validationErrors` is cleared at the start of every remote save, so it stays empty after a save that succeeded or returned no field errors. An empty map plus a `false` return means "not a field failure", and that covers two different things: the backend refused (a 500, a 403) or the client got no readable answer at all. `lastRemoteResponse` tells them apart. It holds the response the latest remote `save()` or `delete()` received, with the driver's `statusCode` 0 when the client got no readable answer, and is `null` before any remote write, when the driver threw, and after a `delete()` on a model that does not exist:

```dart
if (!await monitor.save()) {
  final int? status = monitor.lastRemoteResponse?.statusCode;
  // 0: no readable answer, so not the form's fault; 500: the server failed.
}
```

In an action, hand it to `ActionRequestFailed.refusalOf(action, model.validationErrors, model.lastRemoteResponse)` so the refusal carries it; see [Actions](../basics/actions.md).

The map is deeply unmodifiable, and it tracks the remote leg rather than the return value. A [hybrid](#hybrid-persistence) model whose remote save 422s while its local write succeeds returns `true` and still carries the errors, so check the map even after a successful save when local persistence is on.

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

Hybrid persistence lets one model sync between local storage and a remote REST API.

### Configuration

Control where your model persists:

```dart
// Local storage only (offline mode, needs magic_local_storage)
@override
bool get useLocal => true;
@override
bool get useRemote => false;

// Remote API only (online mode, the default)
@override
bool get useLocal => false;
@override
bool get useRemote => true;

// Both (hybrid mode, needs magic_local_storage)
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

1. **Read operations** check local storage first, then sync from API
2. **Write operations** persist to both local and remote

> [!TIP]
> Use hybrid mode for offline-first apps that sync to a backend API.

<a name="local-storage"></a>
## Local Storage

`useLocal` defaults to `false`, so a model talks to your REST API unless you opt in. The local leg is provided by the `magic_local_storage` plugin (SQLite database, query builder, migrations, seeders, factories and sync). Core only ships the `LocalModelStore` contract (container key `'local_model_store'`): a model with `useLocal => true` throws a `StateError` naming `magic_local_storage` when nothing is bound. Install it with `flutter pub add magic_local_storage`, then `dart run magic:dowel plugin:install magic_local_storage`.
