# HTTP Tests

- [Introduction](#introduction)
- [Making Requests](#making-requests)
- [Testing JSON APIs](#testing-json-apis)
- [Testing Responses](#testing-responses)
- [Mocking HTTP](#mocking-http)
- [Authentication Testing](#authentication-testing)

<a name="introduction"></a>
## Introduction

Magic provides utilities for testing HTTP interactions in your application. Test your API calls, mock responses, and verify your application handles various HTTP scenarios correctly.

<a name="making-requests"></a>
## Making Requests

### Test HTTP Client

Set up a mock HTTP client for testing:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockHttpClient extends Mock implements MagicHttpClient {}

void main() {
  late MockHttpClient mockHttp;

  setUp(() {
    mockHttp = MockHttpClient();
    Http.setTestClient(mockHttp);
  });

  tearDown(() {
    Http.resetClient();
  });
}
```

<a name="testing-json-apis"></a>
## Testing JSON APIs

### Mocking GET Requests

```dart
test('fetches users from API', () async {
  // Arrange
  when(() => mockHttp.get('/users'))
      .thenAnswer((_) async => MagicResponse(
        statusCode: 200,
        body: [
          {'id': 1, 'name': 'John'},
          {'id': 2, 'name': 'Jane'},
        ],
      ));

  // Act
  final users = await UserController().fetchUsers();

  // Assert
  expect(users.length, equals(2));
  expect(users.first.name, equals('John'));
  verify(() => mockHttp.get('/users')).called(1);
});
```

### Mocking POST Requests

```dart
test('creates user via API', () async {
  final userData = {'name': 'John', 'email': 'john@example.com'};
  
  when(() => mockHttp.post('/users', data: userData))
      .thenAnswer((_) async => MagicResponse(
        statusCode: 201,
        body: {'id': 1, ...userData},
      ));

  final user = await UserController().createUser(userData);

  expect(user.id, equals(1));
  expect(user.name, equals('John'));
});
```

<a name="testing-responses"></a>
## Testing Responses

### Testing Success Responses

```dart
test('handles successful response', () async {
  when(() => mockHttp.get('/status'))
      .thenAnswer((_) async => MagicResponse(
        statusCode: 200,
        body: {'status': 'ok'},
      ));

  final response = await Http.get('/status');

  expect(response.successful, isTrue);
  expect(response['status'], equals('ok'));
});
```

### Testing Error Responses

```dart
test('handles 404 not found', () async {
  when(() => mockHttp.get('/users/999'))
      .thenAnswer((_) async => MagicResponse(
        statusCode: 404,
        body: {'message': 'User not found'},
      ));

  final response = await Http.get('/users/999');

  expect(response.notFound, isTrue);
  expect(response.errorMessage, equals('User not found'));
});
```

### Testing Validation Errors

```dart
test('handles validation errors', () async {
  when(() => mockHttp.post('/users', data: any(named: 'data')))
      .thenAnswer((_) async => MagicResponse(
        statusCode: 422,
        body: {
          'message': 'The given data was invalid.',
          'errors': {
            'email': ['The email field is required.'],
            'password': ['The password must be at least 8 characters.'],
          },
        },
      ));

  final response = await Http.post('/users', data: {});

  expect(response.isValidationError, isTrue);
  expect(response.errors['email'], contains('The email field is required.'));
});
```

<a name="mocking-http"></a>
## Mocking HTTP

### Creating Mock Responses

```dart
MagicResponse mockSuccess(dynamic body) {
  return MagicResponse(statusCode: 200, body: body);
}

MagicResponse mockValidationError(Map<String, List<String>> errors) {
  return MagicResponse(
    statusCode: 422,
    body: {
      'message': 'Validation failed',
      'errors': errors,
    },
  );
}

MagicResponse mockUnauthorized() {
  return MagicResponse(
    statusCode: 401,
    body: {'message': 'Unauthenticated'},
  );
}
```

### Using Mock Helpers

```dart
test('controller handles validation error', () async {
  when(() => mockHttp.post('/register', data: any(named: 'data')))
      .thenAnswer((_) async => mockValidationError({
        'email': ['Email already taken'],
      }));

  final controller = AuthController();
  await controller.register({'email': 'existing@test.com'});

  expect(controller.hasError('email'), isTrue);
  expect(controller.getError('email'), equals('Email already taken'));
});
```

<a name="authentication-testing"></a>
## Authentication Testing

### Testing Login Flow

```dart
test('successful login stores token and redirects', () async {
  when(() => mockHttp.post('/login', data: any(named: 'data')))
      .thenAnswer((_) async => MagicResponse(
        statusCode: 200,
        body: {
          'token': 'test-token',
          'user': {'id': 1, 'name': 'John'},
        },
      ));

  final controller = AuthController();
  await controller.login({
    'email': 'john@example.com',
    'password': 'password',
  });

  expect(Auth.check(), isTrue);
  expect(Auth.user<User>()?.name, equals('John'));
});
```

### Testing Token Refresh

```dart
test('refreshes token on 401', () async {
  // First request fails with 401
  when(() => mockHttp.get('/protected'))
      .thenAnswer((_) async => MagicResponse(statusCode: 401));

  // Refresh succeeds
  when(() => mockHttp.post('/refresh', data: any(named: 'data')))
      .thenAnswer((_) async => MagicResponse(
        statusCode: 200,
        body: {'token': 'new-token'},
      ));

  final success = await Auth.refreshToken();
  
  expect(success, isTrue);
});
```

### Testing Protected Routes

```dart
test('redirects unauthenticated user to login', () async {
  // Ensure user is logged out
  await Auth.logout();

  final middleware = EnsureAuthenticated();
  var redirected = false;

  await middleware.handle(() {
    // Should not reach here
    fail('Should have redirected');
  });

  // Verify redirect happened
  // (actual implementation would check navigation)
});
```

> [!TIP]
> Create a `test/mocks/` directory with reusable mock classes and response factories to keep tests DRY.
