# Routing

## Introduction

The most basic Magic routes accept a URI and a closure, providing a very simple and expressive method of defining routes and behavior without complicated routing configuration files.

All of the routes for your application are defined in the `lib/routes` directory and loaded by the `RouteServiceProvider`. This provider is included in your `config/app.dart` by default.

## Basic Routing

The most basic route definitions involve calling a static method on the `MagicRoute` class:

```dart
MagicRoute.page('/greeting', () {
  return Text('Hello World');
});
```

### Available Router Methods

You may register routes using the `page` method for full-screen pages:

```dart
MagicRoute.page('/dashboard', () => DashboardController.instance.index());
```

### The Initial Route

You may configure the initial route of your application by passing the `initialRoute` parameter to the `MagicApplication` widget:

```dart
runApp(
  MagicApplication(
    initialRoute: '/todos',
    // ...
  ),
);
```

## Route Parameters

### Required Parameters

Sometimes you will need to capture segments of the URI within your route. For example, you may need to capture a user's ID from the URL:

```dart
MagicRoute.page('/user/:id', (id) {
  return Text('User $id');
});
```

You may define as many route parameters as required:

```dart
MagicRoute.page('/posts/:postId/comments/:commentId', (postId, commentId) {
  return CommentView(postId: postId, commentId: commentId);
});
```

## Named Routes

Named routes allow convenient generation of URLs or redirects for specific routes. You may specify a name by chaining the `name` method:

```dart
MagicRoute.page('/user/profile', () => ProfileView())
    .name('profile');
```

### Generating URLs To Named Routes

Once you have assigned a name to a route, you may use it when navigating:

```dart
// Navigate to named route
MagicRoute.toNamed('profile');

// With parameters
MagicRoute.toNamed('user.show', parameters: {'id': '1'});
```

## Context-Free Navigation

You may navigate to routes from anywhere in your application—controllers, services, or any Dart class—without needing `BuildContext`:

```dart
// Navigate to a route (replaces current)
MagicRoute.to('/dashboard');

// Push onto the navigation stack (with back button)
MagicRoute.push('/profile');

// Go back
MagicRoute.back();
```

## Route Groups

Route groups allow you to share route attributes, such as middleware or prefixes, across multiple routes:

### Middleware & Prefixes

```dart
MagicRoute.group(
  prefix: '/admin',
  middleware: ['auth'],
  routes: () {
    MagicRoute.page('/', () => AdminDashboard());
    MagicRoute.page('/users', () => AdminUsers());
  }
);
```

### Layouts (Shell Routes)

You may assign a shared layout to all routes within a group. The layout persists while child pages change:

```dart
MagicRoute.group(
  prefix: '/auth',
  layout: (child) => AuthLayout(child: child),
  routes: () {
    MagicRoute.page('/login', () => LoginPage());
    MagicRoute.page('/register', () => RegisterPage());
  }
);
```

> **Note**  
> The layout widget should accept a `child` parameter and render it appropriately inside its widget tree.

## Route Middleware

You may assign middleware to individual routes using the `middleware` method:

```dart
MagicRoute.page('/profile', () => UserProfile())
    .middleware(['auth']);
```

Multiple middleware may be assigned:

```dart
MagicRoute.page('/admin', () => AdminPanel())
    .middleware(['auth', 'admin']);
```
