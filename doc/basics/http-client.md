# HTTP Client

- [Introduction](#introduction)
- [Configuration](#configuration)
- [Making Requests](#making-requests)
    - [GET Requests](#get-requests)
    - [POST Requests](#post-requests)
    - [PUT, PATCH & DELETE](#put-patch--delete)
- [RESTful Resources](#restful-resources)
- [Handling Responses](#handling-responses)
    - [Response Properties](#response-properties)
    - [Validation Errors](#validation-errors)
- [File Uploads](#file-uploads)
- [Interceptors](#interceptors)

<a name="introduction"></a>
## Introduction

Magic provides a powerful HTTP client through the `Http` facade. Built on top of Dio, it offers a clean, expressive API for making HTTP requests and handling responses—just like you'd expect from Laravel.

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
  final users = response.body; // Parsed JSON
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
  final user = response.body;
  Magic.success('Success', 'User created!');
}
```

<a name="put-patch--delete"></a>
### PUT, PATCH & DELETE

```dart
// PUT - Full update
await Http.put('/users/1', data: {
  'name': 'Jane Doe',
  'email': 'jane@example.com',
});

// PATCH - Partial update
await Http.patch('/users/1', data: {
  'name': 'Jane Smith',
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
response.body            // Parsed response body
response['key']          // Direct access to body key
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
