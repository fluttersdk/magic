# Middleware

## Introduction

Middleware provide a convenient mechanism for inspecting and filtering navigation requests in your application. For example, Magic includes a middleware that verifies the user is authenticated. If the user is not authenticated, the middleware will redirect them to the login screen. If authenticated, the middleware allows the request to proceed.

## Defining Middleware

To create a new middleware, create a class that extends `MagicMiddleware`. Middleware typically lives in the `lib/app/middleware` directory:

```dart
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

class EnsureAuthenticated extends MagicMiddleware {
  @override
  Future<void> handle(void Function() next) async {
    if (Auth.check()) {
      next(); // Proceed to the route
    } else {
      MagicRoute.to('/login'); // Redirect
    }
  }
}
```

If the user is authenticated, call `next()` to pass the request deeper into the application. To block the request, simply don't call `next()` and redirect elsewhere.

> **Note**  
> All middleware is asynchronous. You may perform `await` operations (like checking a database or API) before deciding to call `next()`.

## Registering Middleware

### Global Middleware

If you want middleware to run during every navigation, register it globally in your `lib/app/kernel.dart`:

```dart
void registerKernel() {
  Kernel.global([
    () => LoggingMiddleware(),
  ]);
}
```

### Assigning Middleware To Routes

To assign middleware to specific routes, first register it with a key in `kernel.dart`:

```dart
void registerKernel() {
  Kernel.registerAll({
    'auth': () => EnsureAuthenticated(),
    'guest': () => RedirectIfAuthenticated(),
  });
}
```

Then use the key in your route definitions:

```dart
MagicRoute.page('/profile', () => UserProfile())
    .middleware(['auth']);
```

## Authorization Middleware

Magic includes `AuthorizeMiddleware` that integrates with the Gate authorization system, equivalent to Laravel's `can` middleware.

### Basic Usage

Register authorization middleware in your kernel:

```dart
void registerKernel() {
  Kernel.registerAll({
    'auth': () => EnsureAuthenticated(),
    'can:edit-post': () => AuthorizeMiddleware('edit-post'),
    'can:admin': () => AuthorizeMiddleware('admin-access'),
  });
}
```

Use in your routes:

```dart
MagicRoute.page('/posts/:id/edit', () => EditPost())
    .middleware(['auth', 'can:edit-post']);

MagicRoute.page('/admin', () => AdminPanel())
    .middleware(['auth', 'can:admin']);
```

### Custom Redirect

By default, unauthorized users are redirected to `/unauthorized`. You may customize this:

```dart
Kernel.register('can:admin', () => AuthorizeMiddleware(
  'admin-access',
  unauthorizedRoute: '/access-denied',
));
```

### With Model Arguments

For authorization that requires a model (like checking post ownership), create a custom middleware:

```dart
class EditPostMiddleware extends MagicMiddleware {
  @override
  Future<void> handle(void Function() next) async {
    final postId = MagicRoute.param('id');
    final post = await Post.find(postId);

    if (Gate.allows('edit-post', post)) {
      next();
    } else {
      MagicRoute.to('/unauthorized');
    }
  }
}
```
