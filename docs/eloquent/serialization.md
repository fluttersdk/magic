# Eloquent: Serialization

## Introduction

When building APIs or storing data, you will often need to convert your models to arrays or JSON. Eloquent includes convenient methods for making these conversions, as well as controlling which attributes are included in the serialized representation.

## Serializing To Maps & JSON

### toMap

To convert a model and its attributes to a Map, use the `toMap` method:

```dart
final user = await User.find(1);
final map = user.toMap();

// {'id': 1, 'name': 'John', 'email': 'john@test.com', ...}
```

### toJson

To convert a model to a JSON string, use the `toJson` method:

```dart
final json = user.toJson();

// '{"id":1,"name":"John","email":"john@test.com"}'
```

## Flutter-Familiar Factory Methods

For developers coming from standard Flutter patterns, you may define static `fromMap` and `fromJson` methods:

```dart
class User extends Model with HasTimestamps, InteractsWithPersistence {
  // ... other configuration ...

  /// Create from Map.
  static User fromMap(Map<String, dynamic> map) {
    return User()
      ..setRawAttributes(map, sync: true)
      ..exists = map.containsKey('id');
  }

  /// Create from JSON string.
  static User fromJson(String json) {
    return User.fromMap(jsonDecode(json));
  }
}
```

### Usage Examples

```dart
// From API response
final response = await Http.get('/users/1');
final user = User.fromMap(response.data);

// To API request
await Http.post('/users', data: user.toMap());

// JSON serialization
final json = user.toJson();
final restored = User.fromJson(json);
```

## Model Events

Eloquent models dispatch events at various points in their lifecycle:

| Event | Description |
|-------|-------------|
| `ModelSaving` | Before a model is saved (insert or update) |
| `ModelSaved` | After a model is saved |
| `ModelCreating` | Before a new model is inserted |
| `ModelCreated` | After a new model is inserted |
| `ModelUpdating` | Before an existing model is updated |
| `ModelUpdated` | After an existing model is updated |
| `ModelDeleted` | After a model is deleted |

Listen to these events using the Event facade:

```dart
Event.listen<ModelCreated>((event) {
  Log.info('Model created: ${event.model.runtimeType}');
});
```

## Complete Model Example

```dart
import 'dart:convert';
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

class Post extends Model with HasTimestamps, InteractsWithPersistence {
  @override
  String get table => 'posts';

  @override
  String get resource => 'posts';

  @override
  List<String> get fillable => ['title', 'body', 'published_at'];

  @override
  Map<String, String> get casts => {
    'published_at': 'datetime',
    'metadata': 'json',
  };

  // Typed Accessors
  String? get title => getAttribute('title') as String?;
  set title(String? value) => setAttribute('title', value);

  String? get body => getAttribute('body') as String?;
  set body(String? value) => setAttribute('body', value);

  Carbon? get publishedAt => getAttribute('published_at') as Carbon?;
  set publishedAt(dynamic value) => setAttribute('published_at', value);

  // Static Helpers
  static Future<Post?> find(dynamic id) =>
      InteractsWithPersistence.findById<Post>(id, Post.new);

  static Future<List<Post>> all() =>
      InteractsWithPersistence.allModels<Post>(Post.new);

  // Flutter-Familiar Factory
  static Post fromMap(Map<String, dynamic> map) {
    return Post()
      ..setRawAttributes(map, sync: true)
      ..exists = map.containsKey('id');
  }
}
```
