# Seeding

Database seeders let you populate your SQLite tables with test or default data using simple seeder classes and expressive model factories.

- [Introduction](#introduction)
- [Running Seeders](#running-seeders)
- [Writing Seeders](#writing-seeders)
- [The DatabaseSeeder](#the-databaseseeder)
- [Writing Factories](#writing-factories)
    - [Available Faker Methods](#available-faker-methods)
- [Using Factories](#using-factories)
    - [Factory States](#factory-states)
- [CLI Commands](#cli-commands)

<a name="introduction"></a>
## Introduction

Magic includes the ability to seed your database with data using seed classes. All seed classes are stored in the `lib/database/seeders` directory. Seeders are useful for populating your database with test data during development.

<a name="running-seeders"></a>
## Running Seeders

The primary way to seed your database is using `Magic.seed()` in your `main.dart`:

```dart
void main() async {
  await Magic.init(...);

  // Seed database in development
  if (kDebugMode) {
    final count = await DB.table('users').count();
    if (count == 0) {
      await Magic.seed([DatabaseSeeder()]);
    }
  }

  runApp(MagicApplication(...));
}
```

You may also seed specific seeders directly:

```dart
await Magic.seed([UserSeeder(), PostSeeder()]);
```

<a name="writing-seeders"></a>
## Writing Seeders

Generate a seeder using the CLI:

```bash
dart run magic:artisan make:seeder UserSeeder
```

A seeder class contains a single `run` method which is called when the seeder is executed:

```dart
import 'package:magic/magic.dart';
import '../factories/user_factory.dart';

class UserSeeder extends Seeder {
  @override
  Future<void> run() async {
    await UserFactory().count(50).create();
  }
}
```

<a name="the-databaseseeder"></a>
## The DatabaseSeeder

The `DatabaseSeeder` is the entry point for all seeders. Use `call()` to run multiple seeders in order:

```dart
import 'package:magic/magic.dart';
import 'user_seeder.dart';
import 'post_seeder.dart';
import 'comment_seeder.dart';

class DatabaseSeeder extends Seeder {
  @override
  Future<void> run() async {
    await call([
      UserSeeder(),
      PostSeeder(),
      CommentSeeder(),
    ]);
  }
}
```

<a name="writing-factories"></a>
## Writing Factories

Factories define how to generate fake data for a model. Generate a factory using the CLI:

```bash
dart run magic:artisan make:factory User
```

A factory extends `Factory<T>` and defines the model's default attributes:

```dart
import 'package:magic/magic.dart';
import '../../app/models/user.dart';

class UserFactory extends Factory<User> {
  @override
  Factory<User> newFactory() => UserFactory();

  @override
  User newInstance() => User();

  @override
  Map<String, dynamic> definition() {
    return {
      'name': faker.person.name(),
      'email': faker.internet.email(),
      'password': 'password123',  // Use a consistent test password
      'is_active': true,
    };
  }
}
```

`newFactory()` returns a fresh factory of the same class. `state()` and `count()` never change the factory they are called on; they return a copy built through `newFactory()`, so a shared base factory can branch without one branch leaking into the other.

Like Laravel, a factory fills its models **unguarded**: `id`, timestamps, and any key missing from the model's `fillable` list are kept, so a factory can build a model exactly as the API returns it. Outside a factory, `fill()` still honours `fillable` and `guarded`. The same switch is available directly:

```dart
final user = Model.unguarded(() => User()..fill({'id': 1, 'name': 'Taylor'}));
```

`Model.unguarded()` restores the guard when the callback returns or throws, and it needs a synchronous callback: an async one would keep running after the guard is back on.

<a name="available-faker-methods"></a>
### Available Faker Methods

Magic includes the Faker library for generating realistic test data:

```dart
// Person
faker.person.name()              // "John Doe"
faker.person.firstName()         // "John"
faker.person.lastName()          // "Doe"

// Internet
faker.internet.email()           // "john@example.com"
faker.internet.userName()        // "johndoe123"
faker.internet.domainName()      // "example.com"
faker.internet.uri('https')      // "https://example.com/path"

// Lorem
faker.lorem.word()               // "lorem"
faker.lorem.sentence()           // "Lorem ipsum dolor sit amet."
faker.lorem.sentences(3)         // Multiple sentences

// Address
faker.address.city()             // "New York"
faker.address.country()          // "United States"
faker.address.streetAddress()    // "123 Main St"

// Date
faker.date.dateTime()            // Random DateTime
faker.date.dateTimeBetween(start: startDate, end: endDate)

// Random
faker.randomGenerator.integer(100)    // 0-100
faker.randomGenerator.boolean()       // true/false
faker.randomGenerator.element(['a', 'b', 'c'])  // Random from list
```

<a name="using-factories"></a>
## Using Factories

```dart
// Create a single model (saved to DB)
final user = (await UserFactory().create()).first;

// Create 50 models
final users = await UserFactory().count(50).create();

// Create with state override
final admins = await UserFactory()
    .state({'role': 'admin'})
    .count(5)
    .create();

// Create without saving (in-memory only)
final users = UserFactory().count(10).make();

// Attribute maps only, one per model (a request payload, a faked response)
final payloads = UserFactory().count(3).raw();
```

`make()` leaves each model with `exists` false and every attribute dirty, as Laravel does. `raw()` always returns a list: a single map when no `count()` was set.

<a name="factory-states"></a>
### Factory States

Write reusable states as an extension on `Factory<User>`. `state()` and `count()` return `Factory<User>`, so an extension method chains before or after either of them:

```dart
extension UserFactoryStates on Factory<User> {
  Factory<User> admin() => state({'role': 'admin'});

  Factory<User> unverified() => state({'email_verified_at': null});

  Factory<User> inactive() => state({'is_active': false});
}

// Usage
await UserFactory().admin().count(3).create();
await UserFactory().count(10).unverified().create();
```

A method declared on `UserFactory` itself would be unreachable after the first `state()` or `count()` call, whose result is typed `Factory<User>`.

<a name="cli-commands"></a>
## CLI Commands

### Create Seeder

```bash
dart run magic:artisan make:seeder UserSeeder
dart run magic:artisan make:seeder User           # Auto-appends 'Seeder'
```

**Output:** Creates `lib/database/seeders/user_seeder.dart`

### Create Factory

```bash
dart run magic:artisan make:factory User
dart run magic:artisan make:factory UserFactory   # Accepts either form
```

**Output:** Creates `lib/database/factories/user_factory.dart`

> [!TIP]
> Use the `--all` flag with `make:model` to generate model, migration, seeder, and factory in one command: `dart run magic:artisan make:model User --all`
