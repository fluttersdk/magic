# Routing

- [Introduction](#introduction)
- [Basic Routing](#basic-routing)
- [Route Parameters](#route-parameters)
- [Query Parameters](#query-parameters)
- [Named Routes](#named-routes)
- [Route Groups](#route-groups)
    - [Middleware](#middleware)
    - [Prefixes](#prefixes)
    - [Layouts (Shell Routes)](#layouts-shell-routes)
- [Context-Free Navigation](#context-free-navigation)
- [Route Middleware](#route-middleware)
- [Navigator Observers](#navigator-observers)

<a name="introduction"></a>
## Introduction

The most basic Magic routes accept a URI and a closure, providing a very simple and expressive method of defining routes and behavior without complicated routing configuration files.

All routes for your application are defined in the `lib/routes` directory. These files are loaded by the `RouteServiceProvider`, which is included in your `config/app.dart` by default.

<a name="basic-routing"></a>
## Basic Routing

The most basic route definitions involve calling a method on the `MagicRoute` facade:

```dart
MagicRoute.page('/', () => HomePage());
```

### Route Methods

Use the `page` method to define full-screen page routes:

```dart
// Simple page
MagicRoute.page('/greeting', () => Text('Hello World'));

// Controller action
MagicRoute.page('/dashboard', () => DashboardController.instance.index());

// Inline widget
MagicRoute.page('/about', () => AboutPage());
```

### The Initial Route

Configure your application's initial route via `MagicApplication`:

```dart
runApp(
  MagicApplication(
    initialRoute: '/dashboard',
    // ...
  ),
);
```

<a name="route-parameters"></a>
## Route Parameters

### Required Parameters

Sometimes you need to capture segments of the URI. For example, to capture a user's ID:

```dart
MagicRoute.page('/user/:id', (id) {
  return UserProfileView(userId: id);
});
```

You may define as many route parameters as required:

```dart
MagicRoute.page('/posts/:postId/comments/:commentId', (postId, commentId) {
  return CommentView(postId: postId, commentId: commentId);
});
```

> [!NOTE]
> Magic uses `:param` syntax (like Express.js) instead of Laravel's `{param}` syntax.

<a name="query-parameters"></a>
## Query Parameters

Query parameters are the key-value pairs that appear after the `?` in a URL (e.g., `/search?q=flutter&page=2`). Magic provides the `Request` facade to read them from the current route.

### Reading Query Parameters

Use `Request.query()` to retrieve a single query parameter by key. It returns `null` when the key is absent:

```dart
// URL: /search?q=flutter&page=2
final term = Request.query('q');    // 'flutter'
final page = Request.query('page'); // '2'
final sort = Request.query('sort'); // null
```

Use `Request.queryParams` to retrieve all query parameters as a `Map<String, String>`:

```dart
// URL: /search?q=flutter&sort=desc
final params = Request.queryParams;
// {'q': 'flutter', 'sort': 'desc'}
```

### Navigating With Query Parameters

Pass a `query` map to `MagicRoute.to()` or `MagicRoute.toNamed()` to append query parameters to the URL:

```dart
// By path
MagicRoute.to('/search', query: {'q': 'flutter'});

// By name
MagicRoute.toNamed('search', query: {'q': 'flutter', 'page': '2'});
```

> [!NOTE]
> Query parameters are always `String` values. Convert to other types after reading (e.g., `int.tryParse(Request.query('page') ?? '')`).

<a name="named-routes"></a>
## Named Routes

Named routes allow convenient generation of URLs or redirects for specific routes. Specify a name by chaining the `name` method:

```dart
MagicRoute.page('/user/profile', () => ProfileView())
    .name('profile');

MagicRoute.page('/user/:id', (id) => UserView(id: id))
    .name('user.show');
```

### Navigating To Named Routes

Once you have assigned a name to a route, you may use it when navigating:

```dart
// Navigate to named route
MagicRoute.toNamed('profile');

// With path parameters
MagicRoute.toNamed('user.show', params: {'id': '42'});

// With query parameters
MagicRoute.toNamed('search', query: {'q': 'flutter'});
```

<a name="route-groups"></a>
## Route Groups

Route groups allow you to share route attributes, such as middleware or prefixes, across multiple routes.

<a name="middleware"></a>
### Middleware

Assign middleware to all routes within a group:

```dart
MagicRoute.group(
  middleware: ['auth'],
  routes: () {
    MagicRoute.page('/dashboard', () => DashboardView());
    MagicRoute.page('/profile', () => ProfileView());
  },
);
```

<a name="prefixes"></a>
### Prefixes

Add a path prefix to all routes in a group:

```dart
MagicRoute.group(
  prefix: '/admin',
  middleware: ['auth', 'admin'],
  routes: () {
    MagicRoute.page('/', () => AdminDashboard());       // /admin
    MagicRoute.page('/users', () => AdminUsers());      // /admin/users
    MagicRoute.page('/settings', () => AdminSettings()); // /admin/settings
  },
);
```

### Nested Groups

Groups can be nested. Child groups inherit parent attributes:

```dart
MagicRoute.group(
  prefix: '/admin',
  middleware: ['auth'],
  routes: () {
    MagicRoute.group(
      prefix: '/users',
      routes: () {
        MagicRoute.page('/', () => UserList());     // /admin/users
        MagicRoute.page('/:id', (id) => UserShow(id: id)); // /admin/users/:id
      },
    );
  },
);
```

<a name="layouts-shell-routes"></a>
### Layouts (Shell Routes)

Assign a persistent layout to all routes within a group. The layout persists while child pages change—perfect for tab bars, navigation rails, and sidebars:

```dart
MagicRoute.group(
  layout: (child) => AppLayout(child: child),
  middleware: ['auth'],
  routes: () {
    MagicRoute.page('/', () => DashboardView());
    MagicRoute.page('/monitors', () => MonitorsView());
    MagicRoute.page('/settings', () => SettingsView());
  },
);
```

Your layout widget should accept and render the `child` parameter:

```dart
class AppLayout extends StatelessWidget {
  final Widget child;
  
  const AppLayout({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          AppSidebar(),
          Expanded(child: child), // Child pages render here
        ],
      ),
    );
  }
}
```

> [!TIP]
> Use layouts for any UI that should persist across page navigation, such as sidebars, bottom navigation bars, or headers.

<a name="context-free-navigation"></a>
## Context-Free Navigation

You may navigate from anywhere in your application—controllers, services, or pure Dart classes—without needing `BuildContext`:

```dart
// Replace current route
MagicRoute.to('/dashboard');

// Push onto navigation stack (back button works)
MagicRoute.push('/details');

// Go back
MagicRoute.back();

// Go back with an explicit fallback path
MagicRoute.back(fallback: '/home');

// Replace current route (no new history entry)
MagicRoute.replace('/home');

// With query parameters
MagicRoute.to('/search', query: {'q': 'flutter'});
```

### Cross-Shell Back Navigation

`MagicRoute.back()` works reliably even when navigating across shell routes (layouts). Magic maintains a lightweight history stack automatically—no setup required. When the standard pop is not possible, it falls back to the last tracked history entry.

Pass an optional `fallback` path to control where navigation lands when the history stack is empty:

```dart
// Falls back to '/dashboard' if there is no navigation history
MagicRoute.back(fallback: '/dashboard');
```

> [!NOTE]
> The history stack is populated automatically by `MagicRoute.to()` and `MagicRoute.toNamed()`. `replace()` swaps the last entry without growing the stack, so back navigation after a replace lands at the entry before the replace.

### From Controllers

```dart
class AuthController extends MagicController {
  Future<void> logout() async {
    await Auth.logout();
    MagicRoute.to('/login'); // No context needed!
  }
}
```

<a name="route-middleware"></a>
## Route Middleware

Assign middleware to individual routes using the `middleware` method:

```dart
MagicRoute.page('/profile', () => ProfileView())
    .middleware(['auth']);

MagicRoute.page('/admin', () => AdminPanel())
    .middleware(['auth', 'admin']);
```

See the [Middleware documentation](/basics/middleware) for details on creating custom middleware.

<a name="navigator-observers"></a>
## Navigator Observers

Register `NavigatorObserver` instances for analytics, monitoring, or performance tracking. Observers must be added before the router is built (typically in your `RouteServiceProvider`):

```dart
class RouteServiceProvider extends ServiceProvider {
  @override
  Future<void> boot() async {
    // Add observers before registering routes
    MagicRouter.instance.addObserver(SentryNavigatorObserver(
      enableAutoTransactions: true,
      setRouteNameAsTransaction: true,
    ));

    MagicRouter.instance.addObserver(FirebaseAnalyticsObserver(
      analytics: FirebaseAnalytics.instance,
    ));

    registerAppRoutes();
  }

  void registerAppRoutes() {
    MagicRoute.page('/', () => HomePage());
    // ...
  }
}
```

Observers are passed directly to GoRouter and receive all navigation events (`didPush`, `didPop`, `didReplace`, `didRemove`).

> [!NOTE]
> Observers must be registered before `routerConfig` is accessed. Adding observers after the router is built throws a `StateError`.
