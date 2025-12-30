# HTTP Client

## Introduction

Magic provides a powerful HTTP client built on top of `dio`. The `Http` facade offers a clean, expressive API for making HTTP requests and handling responses.

## Configuration

### Create Network Config

```dart
// lib/config/network.dart
Map<String, dynamic> get networkConfig => {
  'network': {
    'default': 'api',
    'drivers': {
      'api': {
        'base_url': env('API_URL', 'https://api.example.com/v1'),
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

### Include in Magic.init()

```dart
await Magic.init(configs: [appConfig, networkConfig]);
```

## Making Requests

### GET Requests

```dart
final response = await Http.get('/users', query: {'page': 1});

if (response.successful) {
  final users = response.data;
}
```

### POST Requests

```dart
final response = await Http.post('/users', data: {
  'name': 'John Doe',
  'email': 'john@example.com',
});
```

### PUT & DELETE

```dart
await Http.put('/users/1', data: {'name': 'Jane'});
await Http.delete('/users/1');
```

## RESTful Resources

For RESTful APIs, use the resource methods:

```dart
// GET /users
final all = await Http.index('users');

// GET /users/1
final one = await Http.show('users', '1');

// POST /users
final created = await Http.store('users', {'name': 'New'});

// PUT /users/1
final updated = await Http.update('users', '1', {'name': 'Updated'});

// DELETE /users/1
await Http.destroy('users', '1');
```

## Interceptors

Create interceptors to modify requests globally:

```dart
class AuthInterceptor extends MagicNetworkInterceptor {
  @override
  dynamic onRequest(RequestOptions options) async {
    final token = await Vault.get('auth_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return options;
  }

  @override
  dynamic onError(DioException error) {
    if (error.response?.statusCode == 401) {
      MagicRoute.to('/auth/login');
    }
    return error;
  }
}
```

## File Uploads

### Using MagicFile (Recommended)

```dart
final image = await Pick.image();
final response = await image!.upload('/api/upload', fieldName: 'avatar');

// With additional data
final response = await image!.upload(
  '/api/upload',
  fieldName: 'photo',
  data: {'title': 'My Photo'},
);
```

### Using Http.upload()

```dart
final file = await Pick.file(extensions: ['pdf']);
final response = await Http.upload(
  '/upload',
  data: {'title': 'Document'},
  files: {'document': file},
);
```

## Handling Responses

The `MagicResponse` object provides helpful methods:

```dart
final response = await Http.get('/users');

if (response.successful) {
  // 2xx status
}

if (response.failed) {
  // 4xx or 5xx status
}

if (response.unauthorized) {
  // 401
}

// Access data
final data = response.dataAs<List>();
final id = response['id'];
```

### Validation Helpers

Easily handle Laravel-style 422 validation errors:

```dart
if (response.isValidationError) {
  // Get all errors map
  final errors = response.errors; 
  // {'email': ['Taken'], 'password': ['Too short']}

  // Get flat list of all messages
  final allMessages = response.errorsList;
  
  // Get just the first error message (useful for snackbars)
  final first = response.firstError;
  
  // Get main error message
  final msg = response.errorMessage;
}
```
