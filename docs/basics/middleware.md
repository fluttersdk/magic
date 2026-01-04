# Middleware

- [Introduction](#introduction)
- [Defining Middleware](#defining-middleware)
- [Registering Middleware](#registering-middleware)
    - [Global Middleware](#global-middleware)
    - [Assigning Middleware To Routes](#assigning-middleware-to-routes)
- [Middleware & Responses](#middleware--responses)
- [Authorization Middleware](#authorization-middleware)

<a name="introduction"></a>
## Introduction

Middleware provide a convenient mechanism for inspecting and filtering navigation requests entering your application. For example, Magic includes a middleware that verifies the user is authenticated. If the user is not authenticated, the middleware will redirect the user to your application's login screen. However, if the user is authenticated, the middleware will allow the request to proceed further into the application.

Of course, additional middleware can be written to perform a variety of tasks besides authentication. Middleware are stored in the `lib/app/middleware` directory.

<a name="defining-middleware"></a>
## Defining Middleware

To create a new middleware, create a class that extends `MagicMiddleware`:

```dart
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

class EnsureAuthenticated extends MagicMiddleware {
  @override
  Future<void> handle(void Function() next) async {
    if (Auth.check()) {
      next(); // Allow navigation to proceed
    } else {
      MagicRoute.to('/login'); // Redirect to login
    }
  }
}
```

As you can see, if the user is not authenticated, the middleware will redirect the user to the login screen. If the user is authenticated, the request is passed further into the application by calling `next()`.

> [!IMPORTANT]
> If you do NOT call `next()`, navigation will be blocked. Always ensure you either call `next()` or redirect the user.

### Async Operations

All middleware is asynchronous. You may perform `await` operations before deciding whether to call `next()`:

```dart
class TeamAccessMiddleware extends MagicMiddleware {
  @override
  Future<void> handle(void Function() next) async {
    final team = await Team.find(Request.route('teamId'));
    
    if (team != null && team.hasMember(Auth.id())) {
      next();
    } else {
      MagicRoute.to('/unauthorized');
    }
  }
}
```

<a name="registering-middleware"></a>
## Registering Middleware

<a name="global-middleware"></a>
### Global Middleware

If you want middleware to run during every navigation in your application, register it globally in your `lib/app/kernel.dart`:

```dart
void registerKernel() {
  Kernel.global([
    () => LoggingMiddleware(),
    () => VerifyDeviceMiddleware(),
  ]);
}
```

Global middleware runs on every route, in the order they are registered.

<a name="assigning-middleware-to-routes"></a>
### Assigning Middleware To Routes

To assign middleware to specific routes, first register it with a key in your Kernel:

```dart
void registerKernel() {
  Kernel.registerAll({
    'auth': () => EnsureAuthenticated(),
    'guest': () => RedirectIfAuthenticated(),
    'admin': () => EnsureAdmin(),
  });
}
```

Then use the string key in your route definitions:

```dart
// Single middleware
MagicRoute.page('/dashboard', () => DashboardView())
    .middleware(['auth']);

// Multiple middleware (executed in order)
MagicRoute.page('/admin', () => AdminPanel())
    .middleware(['auth', 'admin']);
```

### Route Group Middleware

You can apply middleware to all routes within a group:

```dart
MagicRoute.group(
  middleware: ['auth'],
  routes: () {
    MagicRoute.page('/dashboard', () => DashboardView());
    MagicRoute.page('/profile', () => ProfileView());
    MagicRoute.page('/settings', () => SettingsView());
  },
);
```

<a name="middleware--responses"></a>
## Middleware & Responses

Since middleware controls navigation flow, there are two possible outcomes:

| Action | Effect |
|--------|--------|
| Call `next()` | Navigation proceeds to the route |
| Don't call `next()` | Navigation is blocked |

When blocking, you should redirect the user:

```dart
@override
Future<void> handle(void Function() next) async {
  if (await hasValidSubscription()) {
    next();
  } else {
    // Don't call next() - redirect instead
    MagicRoute.to('/subscription/required');
    Magic.error('Subscription Required', 'Please upgrade your plan.');
  }
}
```

<a name="authorization-middleware"></a>
## Authorization Middleware

Magic includes `AuthorizeMiddleware` that integrates with the Gate authorization system—equivalent to Laravel's `can` middleware.

### Basic Usage

Register authorization middleware in your Kernel:

```dart
void registerKernel() {
  Kernel.registerAll({
    'auth': () => EnsureAuthenticated(),
    'can:manage-team': () => AuthorizeMiddleware('manage-team'),
    'can:admin': () => AuthorizeMiddleware('admin-access'),
  });
}
```

Use in your routes:

```dart
MagicRoute.page('/team/settings', () => TeamSettings())
    .middleware(['auth', 'can:manage-team']);

MagicRoute.page('/admin', () => AdminPanel())
    .middleware(['auth', 'can:admin']);
```

### Custom Redirect

By default, unauthorized users are redirected to `/unauthorized`. Customize this:

```dart
Kernel.register('can:admin', () => AuthorizeMiddleware(
  'admin-access',
  unauthorizedRoute: '/access-denied',
));
```

### With Model Arguments

For authorization requiring a model (like checking ownership), create a custom middleware:

```dart
class CanEditPostMiddleware extends MagicMiddleware {
  @override
  Future<void> handle(void Function() next) async {
    final postId = Request.route('id');
    final post = await Post.find(postId);

    if (post != null && Gate.allows('edit-post', post)) {
      next();
    } else {
      MagicRoute.to('/unauthorized');
    }
  }
}
```

Register and use it:

```dart
Kernel.register('can:edit-post', () => CanEditPostMiddleware());

MagicRoute.page('/posts/:id/edit', (id) => EditPostView(id: id))
    .middleware(['auth', 'can:edit-post']);
```

See the [Authorization documentation](/security/authorization) for more on defining abilities and policies.
