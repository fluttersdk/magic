# Eloquent: Mutators

- [Introduction](#introduction)
- [Accessors](#accessors)
- [Mutators](#mutators)
- [Attribute Casting](#attribute-casting)
- [Date Casting](#date-casting)
- [JSON Casting](#json-casting)

<a name="introduction"></a>
## Introduction

Accessors and mutators allow you to transform Eloquent attribute values when you retrieve or set them on model instances. For example, you may want to encrypt a value while it is stored in the database and then automatically decrypt it when you access it on an Eloquent model.

<a name="accessors"></a>
## Accessors

Accessors transform attribute values when you retrieve them. Define typed getter methods in your model:

```dart
class User extends Model {
  // Raw attribute access
  String? get rawName => getAttribute('name') as String?;
  
  // Accessor with transformation
  String get fullName {
    final firstName = getAttribute('first_name') as String? ?? '';
    final lastName = getAttribute('last_name') as String? ?? '';
    return '$firstName $lastName'.trim();
  }
  
  // Accessor with formatting
  String get formattedPhone {
    final phone = getAttribute('phone') as String?;
    if (phone == null) return '';
    return '+1 (${phone.substring(0, 3)}) ${phone.substring(3, 6)}-${phone.substring(6)}';
  }
}
```

### Using Accessors

```dart
final user = await User.find(1);

print(user.fullName);        // "John Doe"
print(user.formattedPhone);  // "+1 (555) 123-4567"
```

<a name="mutators"></a>
## Mutators

Mutators transform attribute values when you set them. Define setter methods:

```dart
class User extends Model {
  // Raw setter
  set name(String? value) => setAttribute('name', value);
  
  // Mutator with transformation
  set email(String? value) =>
      setAttribute('email', value?.toLowerCase().trim());
  
  // Mutator with hashing (example)
  set password(String? value) =>
      setAttribute('password', value != null ? hashPassword(value) : null);
}
```

### Using Mutators

```dart
final user = User();

user.email = '  JOHN@EXAMPLE.COM  ';
print(user.getAttribute('email')); // "john@example.com"

user.password = 'secret123';
// Stored as hashed value
```

<a name="attribute-casting"></a>
## Attribute Casting

The `casts` property provides automatic type conversion for attributes:

```dart
class Task extends Model {
  @override
  Map<String, String> get casts => {
    'is_completed': 'bool',
    'priority': 'int',
    'progress': 'double',
    'due_date': 'datetime',
    'settings': 'json',
  };
  
  // Typed accessors use the cast values
  bool get isCompleted => getAttribute('is_completed') as bool? ?? false;
  int get priority => getAttribute('priority') as int? ?? 0;
  double get progress => getAttribute('progress') as double? ?? 0.0;
  Carbon? get dueDate => getAttribute('due_date') as Carbon?;
  Map<String, dynamic>? get settings =>
      getAttribute('settings') as Map<String, dynamic>?;
}
```

### Available Cast Types

| Cast | Returns | Database Type |
|------|---------|---------------|
| `bool` | `bool` | INTEGER (0/1) |
| `int` | `int` | INTEGER |
| `double` | `double` | REAL |
| `datetime` | `Carbon` | TEXT (ISO 8601) |
| `json` | `Map` or `List` | TEXT (JSON) |

<a name="date-casting"></a>
## Date Casting

Date attributes are automatically converted to Carbon instances:

```dart
class Event extends Model {
  @override
  Map<String, String> get casts => {
    'starts_at': 'datetime',
    'ends_at': 'datetime',
    'published_at': 'datetime',
  };
  
  Carbon? get startsAt => getAttribute('starts_at') as Carbon?;
  Carbon? get endsAt => getAttribute('ends_at') as Carbon?;
  Carbon? get publishedAt => getAttribute('published_at') as Carbon?;
  
  // Duration helper
  Duration? get duration {
    if (startsAt == null || endsAt == null) return null;
    return endsAt!.diff(startsAt!);
  }
  
  // Check if event is happening now
  bool get isHappeningNow {
    final now = Carbon.now();
    return startsAt?.isBefore(now) == true &&
           endsAt?.isAfter(now) == true;
  }
}
```

### Working with Dates

```dart
final event = await Event.find(1);

// Format dates
print(event.startsAt?.format('MMMM d, yyyy'));  // "January 15, 2024"

// Human readable
print(event.startsAt?.diffForHumans());  // "in 2 days"

// Comparison
if (event.startsAt?.isFuture() == true) {
  print('Upcoming event');
}
```

<a name="json-casting"></a>
## JSON Casting

JSON attributes are serialized/deserialized automatically:

```dart
class Monitor extends Model {
  @override
  Map<String, String> get casts => {
    'settings': 'json',
    'tags': 'json',
  };
  
  // Access as Map
  Map<String, dynamic> get settings =>
      (getAttribute('settings') as Map<String, dynamic>?) ?? {};
  
  // Access as List
  List<String> get tags =>
      (getAttribute('tags') as List?)?.cast<String>() ?? [];
  
  // Setters
  set settings(Map<String, dynamic> value) =>
      setAttribute('settings', value);
  
  set tags(List<String> value) =>
      setAttribute('tags', value);
}
```

### Using JSON Attributes

```dart
final monitor = Monitor();

// Set complex data
monitor.settings = {
  'timeout': 30,
  'retries': 3,
  'headers': {'Authorization': 'Bearer token'},
};

monitor.tags = ['production', 'critical', 'api'];

await monitor.save();

// Retrieve
print(monitor.settings['timeout']);  // 30
print(monitor.tags.first);           // "production"
```

> [!TIP]
> Always define typed getters for your attributes to get IDE autocompletion and type safety throughout your application.
