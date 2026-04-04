# HTTP Tests

- [Introduction](#introduction)
- [Faking Responses](#faking-responses)
    - [URL Pattern Stubs](#url-pattern-stubs)
    - [Callback Stubs](#callback-stubs)
- [Making Assertions](#making-assertions)
- [Preventing Stray Requests](#preventing-stray-requests)
- [Response Factory](#response-factory)
- [Unfaking](#unfaking)
- [Full Example](#full-example)

<a name="introduction"></a>
## Introduction

Magic provides a first-class HTTP faking API that lets you swap the real network driver with a `FakeNetworkDriver` during tests. All requests are recorded and no real network traffic is made. This approach is inspired by Laravel's `Http::fake()` and requires no third-party mocking libraries.

```dart
setUp(() {
  MagicApp.reset();
  Magic.flush();

  Http.fake(); // Intercept all HTTP requests
});

tearDown(() {
  Http.unfake(); // Restore real driver
});
```

<a name="faking-responses"></a>
## Faking Responses

Call `Http.fake()` before the code under test runs. When called with no arguments, every request returns a 200 response with empty data.

```dart
final fake = Http.fake();

final response = await Http.get('/users');

expect(response.successful, isTrue);
expect(response.data, isNull);
```

<a name="url-pattern-stubs"></a>
### URL Pattern Stubs

Pass a `Map<String, MagicResponse>` to stub specific URL patterns. Patterns support `*` as a wildcard.

```dart
final fake = Http.fake({
  'users/*': Http.response({'id': 1, 'name': 'Alice'}, 200),
  'posts': Http.response([], 200),
  'auth/login': Http.response({'token': 'test-token'}, 200),
});

final user = await Http.get('/users/42');
expect(user['name'], 'Alice');

final posts = await Http.get('/posts');
expect(posts.data, isEmpty);
```

Pattern matching is done after stripping the leading `/` so both `/users/42` and `users/42` match the pattern `users/*`.

<a name="callback-stubs"></a>
### Callback Stubs

Pass a `FakeRequestHandler` — a function that receives a `MagicRequest` and returns a `MagicResponse` — for dynamic stubbing logic.

```dart
final fake = Http.fake((request) {
  if (request.url.contains('admin')) {
    return Http.response({'error': 'Forbidden'}, 403);
  }

  return Http.response({'ok': true}, 200);
});

final adminResponse = await Http.get('/admin/users');
expect(adminResponse.forbidden, isTrue);

final publicResponse = await Http.get('/users');
expect(publicResponse.successful, isTrue);
```

<a name="making-assertions"></a>
## Making Assertions

`Http.fake()` returns the `FakeNetworkDriver` instance. Use it to assert on recorded requests after the code under test runs.

### `assertSent`

Assert that at least one recorded request matches the predicate.

```dart
final fake = Http.fake();

await Http.post('/users', data: {'name': 'Bob'});

fake.assertSent((request) => request.url.contains('users'));
fake.assertSent(
  (request) => request.method == 'POST' && request.url == '/users',
);
```

### `assertNotSent`

Assert that no recorded request matches the predicate.

```dart
fake.assertNotSent((request) => request.url.contains('payments'));
```

### `assertNothingSent`

Assert that no requests were made at all.

```dart
final fake = Http.fake();

// Code that should not touch the network
doSomethingLocal();

fake.assertNothingSent();
```

### `assertSentCount`

Assert an exact number of requests were recorded.

```dart
final fake = Http.fake();

await Http.get('/users');
await Http.get('/users/1');

fake.assertSentCount(2);
```

### `recorded`

Access the full list of recorded `(MagicRequest, MagicResponse)` pairs for custom assertions.

```dart
final fake = Http.fake();

await Http.post('/orders', data: {'item': 'Widget'});

final pair = fake.recorded.first;
expect(pair.$1.method, 'POST');
expect(pair.$2.statusCode, 200);
```

<a name="preventing-stray-requests"></a>
## Preventing Stray Requests

Call `preventStrayRequests()` on the fake driver to throw a `StrayRequestException` whenever an unmatched request is made. This ensures every HTTP call in your test has an explicit stub.

```dart
final fake = Http.fake({
  'users': Http.response([], 200),
})..preventStrayRequests();

// This is fine — matched by stub
await Http.get('/users');

// This throws StrayRequestException — no matching stub
await Http.get('/notifications'); // throws!
```

> [!TIP]
> Enable `preventStrayRequests()` in tests that should be fully isolated from external services to catch accidental network calls early.

<a name="response-factory"></a>
## Response Factory

`Http.response()` is a convenience factory for building `MagicResponse` objects to use as stub responses.

```dart
// 200 with empty data (default)
Http.response()

// 200 with a Map body
Http.response({'id': 1, 'name': 'Alice'})

// Custom status code
Http.response({'message': 'Not found'}, 404)

// List body
Http.response([{'id': 1}, {'id': 2}], 200)

// 422 validation errors
Http.response({
  'message': 'The given data was invalid.',
  'errors': {
    'email': ['The email field is required.'],
  },
}, 422)
```

<a name="unfaking"></a>
## Unfaking

Call `Http.unfake()` in `tearDown` to remove the fake driver from the IoC container and restore the real network driver for subsequent tests.

```dart
tearDown(() {
  Http.unfake();
});
```

Alternatively, you can call `fake.reset()` on the driver instance to clear recorded requests and stubs without restoring the real driver. This is useful when reusing the same fake across multiple test cases.

```dart
setUp(() {
  MagicApp.reset();
  Magic.flush();
});

// In a group where all tests share one fake:
final fake = Http.fake();

test('first test', () async {
  await Http.get('/a');
  fake.assertSentCount(1);
  fake.reset(); // Clear for next test
});

test('second test', () async {
  await Http.get('/b');
  fake.assertSentCount(1);
});
```

<a name="full-example"></a>
## Full Example

A controller that fetches a user profile and the test verifying it:

```dart
// lib/controllers/profile_controller.dart
class ProfileController extends MagicController
    with MagicStateMixin<Map<String, dynamic>>, ValidatesRequests {
  Future<void> load(String userId) async {
    setLoading();

    final response = await Http.show('users', userId);

    if (response.successful) {
      setSuccess(response.data as Map<String, dynamic>);
    } else {
      setError(response.firstError ?? 'Failed to load profile');
    }
  }
}

// test/http/profile_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

void main() {
  group('ProfileController', () {
    late ProfileController controller;
    late FakeNetworkDriver fake;

    setUp(() {
      MagicApp.reset();
      Magic.flush();

      controller = ProfileController();
      Magic.put<ProfileController>(controller);

      fake = Http.fake();
    });

    tearDown(() {
      Http.unfake();
    });

    test('sets success state on 200 response', () async {
      fake.stub(
        'users/*',
        Http.response({'id': '42', 'name': 'Alice'}, 200),
      );

      await controller.load('42');

      expect(controller.isSuccess, isTrue);
      expect(controller.rxState?['name'], 'Alice');
      fake.assertSent((r) => r.url.contains('users/42'));
    });

    test('sets error state on failure', () async {
      fake.stub(
        'users/*',
        Http.response({'message': 'User not found'}, 404),
      );

      await controller.load('999');

      expect(controller.isError, isTrue);
    });

    test('does not call network when userId is empty', () async {
      // No real call should be made
      fake.assertNothingSent();
    });
  });
}
```
