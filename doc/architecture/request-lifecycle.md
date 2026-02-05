# Request Lifecycle

- [Introduction](#introduction)
- [Lifecycle Overview](#lifecycle-overview)
- [Application Bootstrap](#application-bootstrap)
- [Service Providers](#service-providers)
- [Routing](#routing)
- [Middleware](#middleware)
- [Controller Dispatch](#controller-dispatch)
- [View Rendering](#view-rendering)

<a name="introduction"></a>
## Introduction

Understanding the Magic request lifecycle will help you build better applications. This document covers how a Magic application starts up, handles navigation requests, and renders views.

<a name="lifecycle-overview"></a>
## Lifecycle Overview

```
┌─────────────────────────────────────────────────────────┐
│                    main.dart                            │
│                       │                                 │
│                  Magic.init()                           │
│                       │                                 │
│      ┌────────────────┼────────────────┐                │
│      ▼                ▼                ▼                │
│  Load .env     Register Configs   Boot Providers        │
│                                                         │
│                       │                                 │
│                 runApp(MagicApplication)                │
│                       │                                 │
│              Route Matched (GoRouter)                   │
│                       │                                 │
│         ┌─────────────┼─────────────┐                   │
│         ▼             ▼             ▼                   │
│   Run Middleware   Resolve Layout   Get Controller      │
│                                                         │
│                       │                                 │
│              Controller.method()                        │
│                       │                                 │
│                 Render View                             │
└─────────────────────────────────────────────────────────┘
```

<a name="application-bootstrap"></a>
## Application Bootstrap

The application starts in `main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize Magic
  await Magic.init(
    envFileName: '.env',
    configFactories: [
      () => appConfig,
      () => networkConfig,
      () => authConfig,
    ],
  );
  
  // 2. Restore authentication (optional)
  await Auth.restore();
  
  // 3. Run migrations (development)
  if (kDebugMode) {
    await Migrator().run([...migrations]);
  }
  
  // 4. Start the application
  runApp(MagicApplication(
    title: 'My App',
    initialRoute: Auth.check() ? '/dashboard' : '/login',
  ));
}
```

### Magic.init() Steps

1. **Load Environment** - Reads `.env` file into memory
2. **Merge Configurations** - Combines all config factories
3. **Register Service Providers** - Calls `register()` on each provider
4. **Boot Service Providers** - Calls `boot()` on each provider

<a name="service-providers"></a>
## Service Providers

Providers are registered in `config/app.dart`:

```dart
'providers': [
  (app) => NetworkServiceProvider(app),
  (app) => AuthServiceProvider(app),
  (app) => DatabaseServiceProvider(app),
  (app) => CacheServiceProvider(app),
  (app) => LocalizationServiceProvider(app),
  (app) => EventServiceProvider(app),
  (app) => AppServiceProvider(app),
],
```

### Provider Lifecycle

1. **register()** - Bind services to container (no dependencies)
2. **boot()** - Initialize services (can use other services)

```dart
class AppServiceProvider extends ServiceProvider {
  @override
  void register() {
    // Runs first - just bind services
    app.bind('api', () => ApiService());
  }

  @override
  Future<void> boot() async {
    // Runs after ALL providers register
    // Safe to use other services here
    Gate.before((user, ability) {
      if ((user as User).isAdmin) return true;
      return null;
    });
  }
}
```

<a name="routing"></a>
## Routing

Routes are defined in `lib/routes/`:

```dart
// lib/routes/web.dart
void registerRoutes() {
  // Guest routes
  MagicRoute.group(
    layout: (child) => GuestLayout(child: child),
    routes: () {
      MagicRoute.page('/login', () => AuthController.instance.login());
      MagicRoute.page('/register', () => AuthController.instance.register());
    },
  );

  // Authenticated routes
  MagicRoute.group(
    middleware: ['auth'],
    layout: (child) => AppLayout(child: child),
    routes: () {
      MagicRoute.page('/dashboard', () => DashboardView());
      MagicRoute.page('/settings', () => SettingsView());
    },
  );
}
```

### Route Resolution

1. URL is matched against defined routes
2. Layout is wrapped around the view
3. Middleware is executed in order
4. Controller/View is resolved

<a name="middleware"></a>
## Middleware

Middleware intercepts navigation before the view renders:

```dart
class EnsureAuthenticated extends MagicMiddleware {
  @override
  Future<void> handle(void Function() next) async {
    if (Auth.check()) {
      next();  // Allow navigation
    } else {
      MagicRoute.to('/login');  // Redirect
    }
  }
}
```

### Middleware Execution Order

1. Global middleware (registered in provider)
2. Route group middleware
3. Route-specific middleware

<a name="controller-dispatch"></a>
## Controller Dispatch

Controllers are resolved using the `findOrPut` pattern:

```dart
// Route definition
MagicRoute.page('/tasks', () => TaskController.instance.index());

// Controller
class TaskController extends MagicController {
  static TaskController get instance => Magic.findOrPut(TaskController.new);
  
  Widget index() {
    if (isEmpty) _loadTasks();
    return const TaskListView();
  }
}
```

### Controller Lifecycle

1. **findOrPut** - Get existing or create new controller
2. **onInit()** - Called when controller is created
3. **Method execution** - Returns view widget
4. **State updates** - `notifyListeners()` triggers rebuilds
5. **onClose()** - Called when controller is disposed

<a name="view-rendering"></a>
## View Rendering

Views render using controller state:

```dart
class TaskListView extends MagicView {
  const TaskListView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = TaskController.instance;
    
    return controller.renderState(
      (tasks) => _buildList(tasks),
      onLoading: CircularProgressIndicator(),
      onError: (msg) => ErrorWidget(message: msg),
      onEmpty: EmptyState(),
    );
  }
}
```

### State Flow

1. Controller calls `setLoading()` → View shows loading
2. Controller calls `setSuccess(data)` → View renders data
3. Controller calls `setError(msg)` → View shows error
4. Controller calls `notifyListeners()` → View rebuilds

> [!TIP]
> Understanding this lifecycle helps you place logic in the right location: configuration in providers, authorization in middleware, business logic in controllers, and UI in views.
