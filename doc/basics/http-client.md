# HTTP Client

Magic provides a powerful HTTP client through the `Http` facade, built on top of Dio, with a clean API for making requests and handling responses.

- [Introduction](#introduction)
- [Configuration](#configuration)
- [Making Requests](#making-requests)
    - [GET Requests](#get-requests)
    - [POST Requests](#post-requests)
    - [PUT & DELETE](#put--delete)
- [RESTful Resources](#restful-resources)
- [Paginated Collections](#paginated-collections)
    - [Cursor or Offset](#cursor-or-offset)
    - [Rendering It Lazily](#rendering-it-lazily)
- [Handling Responses](#handling-responses)
    - [Response Properties](#response-properties)
    - [Validation Errors](#validation-errors)
- [File Uploads](#file-uploads)
- [Interceptors](#interceptors)
    - [Configuring the Underlying Driver](#configuring-the-underlying-driver)
- [Testing HTTP](#testing-http)

<a name="introduction"></a>
## Introduction

Magic provides a powerful HTTP client through the `Http` facade. Built on top of Dio, it offers a clean, expressive API for making HTTP requests and handling responses, just like you would expect from Laravel.

<a name="configuration"></a>
## Configuration

### Network Config

Create `lib/config/network.dart`:

```dart
Map<String, dynamic> get networkConfig => {
  'network': {
    'default': 'api',
    'drivers': {
      'api': {
        'base_url': env('API_BASE_URL', 'https://api.example.com/v1'),
        'timeout': 10000,
        'headers': {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      },
    },
  },
};
```

### Register in Config

```dart
await Magic.init(
  configFactories: [
    () => appConfig,
    () => networkConfig,
  ],
);
```

Don't forget to add `NetworkServiceProvider` to your app providers:

```dart
'providers': [
  (app) => NetworkServiceProvider(app),
  // ...
],
```

<a name="making-requests"></a>
## Making Requests

<a name="get-requests"></a>
### GET Requests

```dart
// Simple GET
final response = await Http.get('/users');

// With query parameters
final response = await Http.get('/users', query: {
  'page': 1,
  'per_page': 25,
  'sort': 'name',
});

// Access the data
if (response.successful) {
  final users = response.data; // Parsed JSON
}
```

<a name="post-requests"></a>
### POST Requests

```dart
final response = await Http.post('/users', data: {
  'name': 'John Doe',
  'email': 'john@example.com',
  'password': 'secret123',
});

if (response.successful) {
  final user = response.data;
  Magic.success('Success', 'User created!');
}
```

<a name="put--delete"></a>
### PUT & DELETE

```dart
// PUT - Full update
await Http.put('/users/1', data: {
  'name': 'Jane Doe',
  'email': 'jane@example.com',
});

// DELETE
await Http.delete('/users/1');
```

<a name="restful-resources"></a>
## RESTful Resources

For RESTful APIs, Magic provides resource helper methods:

```dart
// GET /users
final all = await Http.index('users');

// GET /users/1
final one = await Http.show('users', '1');

// POST /users
final created = await Http.store('users', {
  'name': 'New User',
  'email': 'new@example.com',
});

// PUT /users/1
final updated = await Http.update('users', '1', {
  'name': 'Updated Name',
});

// DELETE /users/1
await Http.destroy('users', '1');
```

<a name="paginated-collections"></a>
## Paginated Collections

`Http.index()` and `fetchList()` read a collection in one request and hand you every row. That is the right shape for a settings screen and the wrong one for a log, a check history, or a feed: a long collection rendered as a column of every row costs one build, one layout and one semantics node per row on the first frame, whether or not the reader ever scrolls that far.

`MagicPaginator` reads such a collection one page at a time. It holds the rows fetched so far, knows whether the server has more, and appends rather than replaces:

```dart
final checks = MagicPaginator<CheckRow>(
  url: 'monitors/$id/checks',
  fromMap: CheckRow.fromMap,
  perPage: 50,
);

await checks.loadFirst();   // first page
await checks.loadMore();    // append the next one
await checks.refresh();     // start over from page one

checks.items;      // every row so far, oldest page first
checks.hasMore;    // is there another page
checks.isLoading;  // a request is in flight
checks.error;      // the last failure, cleared by the next success
checks.isEmpty;    // a first page arrived and held nothing
```

It is a `ChangeNotifier`, so a widget can listen to it directly and a controller can hold several without inventing a state enum per list.

> [!NOTE]
> `loadMore()` is a no-op while a request is in flight and when there is nothing more to fetch, so it is safe to call from a scroll callback that fires every frame.

A failed `loadMore()` keeps the rows already on screen and leaves `hasMore` alone, so the reader does not lose page one because page two timed out, and a retry still has a target. A **transport** failure counts as a failure here: a timeout or a dead link arrives as statusCode 0, and `error` is set rather than the collection reporting itself empty, because "no rows" and "nobody answered" are different screens.

`refresh()` issued while the tail is auto-fetching waits for that page to land and then starts over, so a pull-to-refresh cannot retract over stale rows having done nothing. Disposing the paginator while a request is in flight is safe.

<a name="cursor-or-offset"></a>
### Cursor or Offset

The mode is read from the response rather than configured, so one paginator serves whichever the endpoint uses:

| Response `meta` | Mode | Next page |
|---|---|---|
| `next_cursor` | `PaginationMode.cursor` | `?cursor=<token>` |
| `current_page` + `last_page` | `PaginationMode.offset` | `?page=<n+1>` |
| neither | `PaginationMode.single` | there is no next page |

**Prefer `cursorPaginate()` on the server for anything that grows at the head**, which is most live data: checks, events, messages, notifications.

```php
// Drifts: a row inserted at the top between two requests shifts
// everything down, so page two repeats the last row of page one.
return CheckResource::collection($query->paginate($perPage));

// Stable: the cursor names a position in the ordering.
return CheckResource::collection($query->cursorPaginate($perPage));
```

Cursor pagination also costs the database the same at any depth, because it seeks to a position instead of counting past every row it skips. What you give up is a total count and the ability to jump to page five, neither of which an infinitely scrolling list uses.

<a name="rendering-it-lazily"></a>
### Rendering It Lazily

`MagicPaginatedListView` builds the rows the viewport can show and asks for the next page as the tail comes into view:

```dart
WDiv(
  className: 'h-[600px]',
  child: MagicPaginatedListView<CheckRow>(
    paginator: controller.checks,
    itemBuilder: (_, CheckRow row, _) => CheckHistoryRow(row: row),
    separatorBuilder: (_, _) => const WDiv(className: 'h-px bg-gray-200'),
    emptyState: const MSEmptyState(title: 'No checks yet'),
    loadingFooter: const WDiv(className: 'p-4', child: WText('Loading...')),
  ),
)
```

A first page too short to fill the viewport still fetches its successor: the widget checks after the frame whether there is anything to scroll, so a small `perPage` cannot strand the reader on a truncated list. That fill stops on an error and on a page that added no rows, so a failing endpoint is asked once rather than once per frame.

> [!WARNING]
> It is a `ListView`, so it needs a **bounded height**. Dropping it into a page that already scrolls without a bound throws, and reaching for `shrinkWrap: true` to make that work defeats the whole thing: shrink-wrapping measures every row, so all of them get built and nothing is saved. Give it a height, or give the page a sliver-based scaffold.

<a name="handling-responses"></a>
## Handling Responses

The `MagicResponse` object provides helpful properties and methods for handling API responses.

<a name="response-properties"></a>
### Response Properties

```dart
final response = await Http.get('/users');

// Status checks
response.successful        // true if 2xx status
response.failed           // true if 4xx or 5xx
response.unauthorized     // true if 401
response.forbidden        // true if 403
response.notFound         // true if 404
response.isValidationError // true if 422

// Access data
response.statusCode       // HTTP status code
response.data            // Parsed response body
response['key']          // Direct access to data key
response.dataAs<List>()  // Typed access
```

<a name="validation-errors"></a>
### Validation Errors

Magic handles Laravel-style 422 validation errors elegantly:

```dart
final response = await Http.post('/register', data: formData);

if (response.isValidationError) {
  // Get all errors as a Map
  final errors = response.errors;
  // {'email': ['Email already taken'], 'password': ['Too short']}
  
  // Get flat list of all error messages
  final allMessages = response.errorsList;
  // ['Email already taken', 'Too short']
  
  // Get just the first error (useful for snackbars)
  final firstError = response.firstError;
  // 'Email already taken'
  
  // Get the main error message
  final message = response.errorMessage;
  // 'The given data was invalid.'
}
```

### Controller Integration

Use `ValidatesRequests` mixin in your controller for automatic error handling:

```dart
class AuthController extends MagicController with ValidatesRequests {
  Future<void> register(Map<String, dynamic> data) async {
    clearErrors();
    
    final response = await Http.post('/register', data: data);
    
    if (response.successful) {
      // Handle success
    } else {
      // Automatically populates controller errors from 422 response
      handleApiError(response, fallback: 'Registration failed');
    }
  }
}
```

<a name="file-uploads"></a>
## File Uploads

### Using MagicFile (Recommended)

```dart
// Pick and upload an image
final image = await Pick.image();

if (image != null) {
  final response = await image.upload('/upload', fieldName: 'avatar');
  
  if (response.successful) {
    final url = response['url'];
  }
}

// With additional form data
final response = await image.upload(
  '/upload',
  fieldName: 'photo',
  data: {'title': 'Profile Photo', 'public': true},
);
```

### Using Http.upload()

```dart
final file = await Pick.file(extensions: ['pdf', 'doc']);

final response = await Http.upload(
  '/documents',
  data: {'title': 'My Document'},
  files: {'document': file},
);
```

<a name="interceptors"></a>
## Interceptors

Create interceptors to modify requests or handle responses globally:

```dart
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Add auth token to every request
    final token = await Auth.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Log or transform successful responses
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Handle errors globally
    if (err.response?.statusCode == 401)
```

Register interceptors in your `NetworkServiceProvider`:

```dart
class NetworkServiceProvider extends ServiceProvider {
  @override
  void boot() {
    Http.addInterceptor(AuthInterceptor());
    Http.addInterceptor(LoggingInterceptor());
  }
}
```

<a name="configuring-the-underlying-driver"></a>
### Configuring the Underlying Driver

For SDK integrations that need direct Dio access (such as `sentry_dio` for performance tracing or certificate pinning), resolve the `DioNetworkDriver` from the IoC container and call `configureDriver()`:

```dart
final driver = Magic.make<DioNetworkDriver>('network');
driver.configureDriver((dio) {
  // Attach a Sentry performance tracing interceptor
  dio.addSentry();
});
```

You can also use this hook to pin a certificate by supplying a custom `HttpClientAdapter`:

```dart
final driver = Magic.make<DioNetworkDriver>('network');
driver.configureDriver((dio) {
  dio.httpClientAdapter = PinnedHttpClientAdapter(
    trustedCertificate: certBytes,
  );
});
```

> [!NOTE]
> `configureDriver()` is specific to `DioNetworkDriver`. Call it after `Magic.init()` completes, typically in a service provider's `boot()` method.

<a name="testing-http"></a>
## Testing HTTP

Magic provides first-class HTTP faking so tests never make real network calls. For a full guide to request assertions and stubbing strategies, see [HTTP Tests](../testing/http-tests.md).

```dart
import 'package:magic/testing.dart';

// Replace the real driver with a fake that returns 200 for all requests
Http.fake();

// Stub specific URL patterns
Http.fake({
  '/users': Http.response({'data': []}, 200),
  '/users/1': Http.response({'id': 1, 'name': 'Alice'}, 200),
});

// Restore the real driver when done
Http.unfake();
```
