# Eloquent: Serialization

- [Introduction](#introduction)
- [Serializing to Arrays](#serializing-to-arrays)
- [Serializing to JSON](#serializing-to-json)
- [Hiding Attributes](#hiding-attributes)
- [Appending Attributes](#appending-attributes)

<a name="introduction"></a>
## Introduction

When building APIs or passing data to JavaScript frontends, you will often need to convert your models to arrays or JSON. Magic includes convenient methods for these conversions while controlling which attributes are included.

<a name="serializing-to-arrays"></a>
## Serializing to Arrays

Convert a model to an array using `toMap()`:

```dart
final user = await User.find(1);
final array = user.toMap();

// {
//   'id': 1,
//   'name': 'John Doe',
//   'email': 'john@example.com',
//   'created_at': '2024-01-15T10:30:00.000Z',
//   'updated_at': '2024-01-15T10:30:00.000Z',
// }
```

### Converting Collections

```dart
final users = await User.all();
final array = users.map((u) => u.toMap()).toList();
```

<a name="serializing-to-json"></a>
## Serializing to JSON

Convert a model to JSON using `toJson()`:

```dart
final user = await User.find(1);
final json = user.toJson();

// '{"id":1,"name":"John Doe","email":"john@example.com",...}'
```

<a name="hiding-attributes"></a>
## Hiding Attributes

### Model-Level Hidden Attributes

Define attributes that should never be serialized:

```dart
class User extends Model {
  @override
  List<String> get hidden => ['password', 'remember_token', 'api_key'];
}
```

Now when you call `toMap()` or `toJson()`, these attributes are excluded:

```dart
final user = await User.find(1);
print(user.toMap());

// {
//   'id': 1,
//   'name': 'John Doe',
//   'email': 'john@example.com',
//   // password, remember_token, api_key are NOT included
// }
```

### Temporary Hidden Attributes

Hide additional attributes for a specific serialization:

```dart
final user = await User.find(1);
final array = user.makeHidden(['email', 'phone']).toMap();

// email and phone are hidden for this call only
```

### Making Hidden Attributes Visible

Temporarily show normally hidden attributes:

```dart
final user = await User.find(1);
final array = user.makeVisible(['password']).toMap();

// password is included for this call only
```

<a name="appending-attributes"></a>
## Appending Attributes

Include accessor values in serialization:

```dart
class User extends Model {
  @override
  List<String> get appends => ['full_name', 'is_admin'];
  
  // Accessors that will be included
  String get fullName {
    final first = getAttribute('first_name') as String? ?? '';
    final last = getAttribute('last_name') as String? ?? '';
    return '$first $last'.trim();
  }
  
  bool get isAdmin {
    return (getAttribute('role') as String?) == 'admin';
  }
}
```

Now these computed attributes are included in serialization:

```dart
final user = await User.find(1);
print(user.toMap());

// {
//   'id': 1,
//   'first_name': 'John',
//   'last_name': 'Doe',
//   'role': 'admin',
//   'full_name': 'John Doe',    // Appended
//   'is_admin': true,           // Appended
// }
```

### Temporary Appends

Append additional attributes for a specific serialization:

```dart
final user = await User.find(1);
final array = user.append(['avatar_url', 'formatted_phone']).toMap();
```

## API Response Example

Combine serialization options for clean API responses:

```dart
class UserController extends MagicController {
  Future<void> index() async {
    final users = await User.all();
    
    return users.map((user) => 
      user
        .makeHidden(['password', 'remember_token'])
        .append(['full_name'])
        .toMap()
    ).toList();
  }
}
```

This returns:

```json
[
  {
    "id": 1,
    "email": "john@example.com",
    "first_name": "John",
    "last_name": "Doe",
    "full_name": "John Doe"
  },
  ...
]
```

> [!TIP]
> Always hide sensitive attributes like passwords and API keys at the model level using the `hidden` property.
