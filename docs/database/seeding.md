# Seeding

## Introduction

Magic includes the ability to seed your database with data using seed classes. All seed classes are stored in the `lib/database/seeders` directory. Seeders are useful for populating your database with test data during development.

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
await Magic.seed([UserSeeder(), TodoSeeder()]);
```

## Writing Seeders

Generate a seeder using the CLI:

```bash
magic make:seeder UserSeeder
```

A seeder class contains a single `run` method which is called when the seeder is executed:

```dart
class UserSeeder extends Seeder {
  @override
  Future<void> run() async {
    await UserFactory().count(50).create();
  }
}
```

## The DatabaseSeeder

The `DatabaseSeeder` is the entry point for all seeders. Use `call()` to run multiple seeders in order:

```dart
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

## Writing Factories

Generate a factory using the CLI:

```bash
magic make:factory User
```

A factory defines how to generate fake data for a model:

```dart
class UserFactory extends Factory<User> {
  @override
  User newInstance() => User();

  @override
  Map<String, dynamic> definition() {
    return {
      'name': faker.person.name(),
      'email': faker.internet.email(),
      'is_active': true,
    };
  }
}
```

### Available Faker Methods

```dart
faker.person.name()              // John Doe
faker.internet.email()           // john@example.com
faker.lorem.sentence()           // Lorem ipsum...
faker.address.city()             // New York
faker.randomGenerator.integer(100) // 0-100
faker.date.dateTime()            // Random DateTime
```

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
final mocks = UserFactory().count(10).make();
```

### Factory States

You may define reusable state transformations within your factory:

```dart
class UserFactory extends Factory<User> {
  // ...definition

  UserFactory admin() {
    return state({'role': 'admin'}) as UserFactory;
  }

  UserFactory unverified() {
    return state({'email_verified_at': null}) as UserFactory;
  }
}

// Usage:
await UserFactory().admin().count(3).create();
```

## CLI Commands

### Create Seeder

```bash
magic make:seeder UserSeeder
magic make:seeder User           # Auto-appends 'Seeder'
```

**Output:** Creates `lib/database/seeders/user_seeder.dart`

### Create Factory

```bash
magic make:factory User
magic make:factory UserFactory   # Auto-strips duplicate suffix
```

**Output:** Creates `lib/database/factories/user_factory.dart`
