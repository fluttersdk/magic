# Eloquent: Mutators & Casting

## Introduction

Accessors, mutators, and attribute casting allow you to transform Eloquent attribute values when you retrieve or set them on model instances.

## Attribute Casting

The `casts` property converts attributes to common data types automatically:

```dart
@override
Map<String, String> get casts => {
  'born_at': 'datetime',    // Converts to Carbon
  'settings': 'json',       // Converts to Map
  'is_active': 'bool',      // Converts to bool
  'score': 'int',           // Converts to int
  'rating': 'double',       // Converts to double
};
```

### Date Casting

Attributes cast as `datetime` are converted to Carbon objects, providing Laravel-style date manipulation:

```dart
final user = await User.find(1);

print(user.bornAt.diffForHumans());    // "24 years ago"
print(user.bornAt.year);               // 2000
print(user.bornAt.format('MMMM do, yyyy')); // "January 15th, 2000"
```

### JSON Casting

Attributes cast as `json` are automatically decoded to Maps:

```dart
print(user.settings['theme']);        // "dark"
print(user.settings['notifications']); // true
```

## Typed Accessors

For type safety and IDE autocompletion, define getters and setters:

```dart
class User extends Model with HasTimestamps, InteractsWithPersistence {
  // ...

  String? get name => getAttribute('name') as String?;
  set name(String? value) => setAttribute('name', value);

  String? get email => getAttribute('email') as String?;
  set email(String? value) => setAttribute('email', value);

  Carbon? get bornAt => getAttribute('born_at') as Carbon?;
  set bornAt(dynamic value) => setAttribute('born_at', value);
}
```

## Convenient Accessors

If you don't want to define typed getters/setters for every field, use the `get()` and `set()` methods:

### Getting Values

```dart
// Basic usage
final name = user.get<String>('name');

// With default value
final name = user.get<String>('name', defaultValue: 'Unknown');

// Datetime fields (returns Carbon)
final bornAt = user.get<Carbon>('born_at');
print(bornAt?.fromNow()); // "24 years ago"

// JSON fields (returns Map)
final settings = user.get<Map<String, dynamic>>('settings', defaultValue: {});
```

### Setting Values

```dart
user.set('name', 'John Doe');
user.set('born_at', Carbon.now());
user.set('settings', {'theme': 'dark', 'notifications': true});
```

### Checking Existence

```dart
if (user.has('email')) {
  sendEmail(user.get<String>('email')!);
}
```

## Timestamps

### Using Timestamps

The `HasTimestamps` mixin automatically manages `created_at` and `updated_at` columns:

```dart
class User extends Model with HasTimestamps, InteractsWithPersistence {
  // ...
}

// Timestamps are set automatically
final user = User()..fill({'name': 'John'});
await user.save();

print(user.createdAt?.diffForHumans()); // "a few seconds ago"
print(user.updatedAt?.diffForHumans()); // "a few seconds ago"
```

### Disabling Timestamps

```dart
@override
bool get timestamps => false;
```

### Custom Column Names

```dart
@override
String get createdAtColumn => 'date_created';

@override
String get updatedAtColumn => 'date_modified';
```

### Touching Timestamps

Manually update the `updated_at` timestamp:

```dart
user.touch();
await user.save();
```

## Relationship Casting

When working with APIs that return nested objects (like a Post with its User), you can define relationships for automatic casting:

### Defining Relations

```dart
class Post extends Model with HasTimestamps, InteractsWithPersistence {
  @override String get table => 'posts';
  @override String get resource => 'posts';
  
  @override
  Map<String, Model Function()> get relations => {
    'user': User.new,          // Single related model
    'comments': Comment.new,   // List of related models
  };

  // Typed accessors for relations
  User? get user => getRelation<User>('user');
  List<Comment> get comments => getRelations<Comment>('comments');
}
```

### Single Relation

Use `getRelation<T>()` for a single nested model:

```dart
// API returns: {"id": 1, "title": "Hello", "user": {"id": 5, "name": "John"}}
final post = await Post.find(1);
print(post?.user?.name);  // "John"
```

### List Relations

Use `getRelations<T>()` for a list of nested models:

```dart
// API returns: {"id": 1, "comments": [{"id": 1, "body": "Nice!"}, ...]}
final post = await Post.find(1);
for (final comment in post?.comments ?? []) {
  print(comment.body);
}
```

> **Note**  
> Relations are automatically cached after the first access. Subsequent calls return the cached models.

