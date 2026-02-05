# Database Testing

- [Introduction](#introduction)
- [Using In-Memory Database](#using-in-memory-database)
- [Running Migrations](#running-migrations)
- [Using Factories](#using-factories)
- [Model Testing](#model-testing)
- [Database Assertions](#database-assertions)
- [Refreshing Database](#refreshing-database)

<a name="introduction"></a>
## Introduction

Magic makes it easy to test database interactions using in-memory SQLite databases and model factories. Tests run fast because the database lives entirely in memory and is recreated fresh for each test.

<a name="using-in-memory-database"></a>
## Using In-Memory Database

Configure your tests to use an in-memory database:

```dart
// test/test_helper.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

Future<void> setupTestDatabase() async {
  await Magic.init(
    envFileName: '.env.testing',
    configFactories: [
      () => testDatabaseConfig,
    ],
  );
}

Map<String, dynamic> get testDatabaseConfig => {
  'database': {
    'default': 'sqlite',
    'connections': {
      'sqlite': {
        'driver': 'sqlite',
        'database': ':memory:',  // In-memory database
      },
    },
  },
};
```

<a name="running-migrations"></a>
## Running Migrations

Run migrations before your tests:

```dart
void main() {
  setUpAll(() async {
    await setupTestDatabase();
    
    // Run all migrations
    await Migrator().run([
      CreateUsersTable(),
      CreatePostsTable(),
      CreateCommentsTable(),
    ]);
  });

  // Your tests here
}
```

### Fresh Database Per Test

For isolation, reset the database for each test:

```dart
void main() {
  setUp(() async {
    await setupTestDatabase();
    await Migrator().fresh([  // Drops all tables and re-runs migrations
      CreateUsersTable(),
      CreatePostsTable(),
    ]);
  });

  test('creates user', () async {
    // Database is fresh for each test
  });
}
```

<a name="using-factories"></a>
## Using Factories

Use factories to create test data:

```dart
test('creates users with factory', () async {
  // Create 10 users
  final users = await UserFactory().count(10).create();
  
  expect(users.length, equals(10));
  expect(users.first.id, isNotNull);
});

test('creates user with specific attributes', () async {
  final admin = (await UserFactory()
      .state({'role': 'admin', 'is_active': true})
      .create())
      .first;
  
  expect(admin.role, equals('admin'));
  expect(admin.isActive, isTrue);
});

test('uses factory states', () async {
  final unverifiedUsers = await UserFactory()
      .unverified()
      .count(5)
      .create();
  
  for (final user in unverifiedUsers) {
    expect(user.emailVerifiedAt, isNull);
  }
});
```

<a name="model-testing"></a>
## Model Testing

### Testing CRUD Operations

```dart
group('User Model', () {
  test('creates user', () async {
    final user = User()
      ..fill({
        'name': 'John Doe',
        'email': 'john@example.com',
      });
    
    await user.save();
    
    expect(user.id, isNotNull);
    expect(user.createdAt, isNotNull);
  });

  test('finds user by id', () async {
    final created = (await UserFactory().create()).first;
    
    final found = await User.find(created.id);
    
    expect(found, isNotNull);
    expect(found!.id, equals(created.id));
  });

  test('updates user', () async {
    final user = (await UserFactory().create()).first;
    
    user.name = 'Updated Name';
    await user.save();
    
    final fresh = await User.find(user.id);
    expect(fresh!.name, equals('Updated Name'));
  });

  test('deletes user', () async {
    final user = (await UserFactory().create()).first;
    final id = user.id;
    
    await user.delete();
    
    final found = await User.find(id);
    expect(found, isNull);
  });
});
```

### Testing Relationships

```dart
test('user has many posts', () async {
  final user = (await UserFactory().create()).first;
  
  await PostFactory()
      .state({'user_id': user.id})
      .count(3)
      .create();
  
  final posts = await user.posts();
  
  expect(posts.length, equals(3));
});
```

<a name="database-assertions"></a>
## Database Assertions

### Assert Record Exists

```dart
test('creates record in database', () async {
  await UserFactory().state({'email': 'test@example.com'}).create();
  
  final exists = await DB.table('users')
      .where('email', 'test@example.com')
      .exists();
  
  expect(exists, isTrue);
});
```

### Assert Record Count

```dart
test('seeds correct number of users', () async {
  await UserFactory().count(5).create();
  
  final count = await DB.table('users').count();
  
  expect(count, equals(5));
});
```

### Assert Record Deleted

```dart
test('deletes user from database', () async {
  final user = (await UserFactory().create()).first;
  
  await user.delete();
  
  final exists = await DB.table('users')
      .where('id', user.id)
      .exists();
  
  expect(exists, isFalse);
});
```

### Assert Specific Values

```dart
test('updates user attributes', () async {
  final user = (await UserFactory().create()).first;
  
  user.name = 'New Name';
  await user.save();
  
  final row = await DB.table('users')
      .where('id', user.id)
      .first();
  
  expect(row?['name'], equals('New Name'));
});
```

<a name="refreshing-database"></a>
## Refreshing Database

### Between Test Groups

```dart
void main() {
  group('User Tests', () {
    setUpAll(() async {
      await setupTestDatabase();
      await Migrator().run([CreateUsersTable()]);
    });

    setUp(() async {
      // Clear users table before each test
      await DB.table('users').delete();
    });

    test('test 1', () async { /* ... */ });
    test('test 2', () async { /* ... */ });
  });
}
```

### Using Transactions

Roll back database changes after each test:

```dart
void main() {
  setUp(() async {
    DB.beginTransaction();
  });

  tearDown(() async {
    DB.rollback();  // Undo all changes
  });

  test('creates user (rolled back)', () async {
    await UserFactory().create();
    // Changes are rolled back after test
  });
}
```

> [!TIP]
> Use `:memory:` database and transactions for the fastest test execution. Each test runs in isolation without persisting data.
