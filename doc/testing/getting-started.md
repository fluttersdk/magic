# Testing: Getting Started

- [Introduction](#introduction)
- [Setting Up Tests](#setting-up-tests)
- [Writing Tests](#writing-tests)
- [Controller Testing](#controller-testing)
- [Model Testing](#model-testing)
- [Mock HTTP Responses](#mock-http-responses)
- [Running Tests](#running-tests)

<a name="introduction"></a>
## Introduction

Magic is built with testing in mind from the ground up. The framework provides a testing foundation that works seamlessly with Dart's built-in `test` package, along with helpers for testing controllers, models, and HTTP interactions.

<a name="setting-up-tests"></a>
## Setting Up Tests

### Directory Structure

```
test/
├── unit/
│   ├── models/
│   │   └── user_test.dart
│   └── controllers/
│       └── auth_controller_test.dart
├── feature/
│   └── authentication_test.dart
└── test_helper.dart
```

### Test Helper

Create a `test/test_helper.dart` for common setup:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

Future<void> setupTestEnvironment() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  await Magic.init(
    envFileName: '.env.testing',
    configFactories: [
      () => appConfig,
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
        'database': ':memory:',  // In-memory for tests
      },
    },
  },
};
```

<a name="writing-tests"></a>
## Writing Tests

### Basic Test Structure

```dart
import 'package:flutter_test/flutter_test.dart';
import '../test_helper.dart';

void main() {
  setUpAll(() async {
    await setupTestEnvironment();
  });

  group('User', () {
    test('can create a user', () async {
      final user = User()
        ..fill({
          'name': 'John Doe',
          'email': 'john@example.com',
        });
      
      await user.save();
      
      expect(user.id, isNotNull);
      expect(user.name, equals('John Doe'));
    });

    test('validates email format', () {
      final validator = EmailValidator();
      
      expect(validator.passes('john@example.com'), isTrue);
      expect(validator.passes('invalid-email'), isFalse);
    });
  });
}
```

<a name="controller-testing"></a>
## Controller Testing

Test controllers by creating instances and calling methods:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  late AuthController controller;
  
  setUp(() {
    controller = AuthController();
  });

  tearDown(() {
    controller.dispose();
  });

  group('AuthController', () {
    test('login sets loading state', () async {
      expect(controller.isLoading, isFalse);
      
      // Start login (will fail due to no mock, but tests state)
      controller.login({'email': 'test@test.com', 'password': 'password'});
      
      expect(controller.isLoading, isTrue);
    });

    test('clearErrors removes all validation errors', () {
      controller.setError('email', 'Invalid email');
      expect(controller.hasError('email'), isTrue);
      
      controller.clearErrors();
      expect(controller.hasError('email'), isFalse);
    });
  });
}
```

### Testing State Changes

```dart
test('setSuccess updates state correctly', () {
  final controller = TaskController();
  
  expect(controller.isLoading, isFalse);
  expect(controller.isSuccess, isFalse);
  
  controller.setLoading();
  expect(controller.isLoading, isTrue);
  
  controller.setSuccess([Task(name: 'Test')]);
  expect(controller.isSuccess, isTrue);
  expect(controller.data, isNotEmpty);
});
```

<a name="model-testing"></a>
## Model Testing

Test models using factories for consistent data:

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await setupTestEnvironment();
    await Migrator().run([CreateUsersTable()]);
  });

  group('User Model', () {
    test('creates user with factory', () async {
      final users = await UserFactory().count(5).create();
      
      expect(users.length, equals(5));
      expect(users.first.id, isNotNull);
    });

    test('finds user by id', () async {
      final created = (await UserFactory().create()).first;
      final found = await User.find(created.id);
      
      expect(found, isNotNull);
      expect(found!.email, equals(created.email));
    });

    test('updates user attributes', () async {
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
}
```

<a name="mock-http-responses"></a>
## Mock HTTP Responses

Use mock HTTP responses for testing API interactions:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockHttpClient extends Mock implements HttpClient {}

void main() {
  late MockHttpClient mockHttp;
  late AuthController controller;

  setUp(() {
    mockHttp = MockHttpClient();
    // Inject mock into Http facade
    Http.setTestClient(mockHttp);
    controller = AuthController();
  });

  test('login success redirects to dashboard', () async {
    // Arrange
    when(() => mockHttp.post('/login', data: any(named: 'data')))
        .thenAnswer((_) async => MagicResponse(
          statusCode: 200,
          body: {
            'token': 'test-token',
            'user': {'id': 1, 'name': 'John'},
          },
        ));

    // Act
    await controller.login({
      'email': 'john@example.com',
      'password': 'password',
    });

    // Assert
    expect(Auth.check(), isTrue);
  });

  test('login failure shows error', () async {
    when(() => mockHttp.post('/login', data: any(named: 'data')))
        .thenAnswer((_) async => MagicResponse(
          statusCode: 401,
          body: {'message': 'Invalid credentials'},
        ));

    await controller.login({
      'email': 'john@example.com',
      'password': 'wrong',
    });

    expect(controller.isError, isTrue);
  });
}
```

<a name="running-tests"></a>
## Running Tests

### Run All Tests

```bash
flutter test
```

### Run Specific Test File

```bash
flutter test test/unit/models/user_test.dart
```

### Run With Coverage

```bash
flutter test --coverage
```

### Test Output

```bash
flutter test --reporter=expanded
```

> [!TIP]
> Use the `:memory:` database driver for faster tests that don't persist to disk.
