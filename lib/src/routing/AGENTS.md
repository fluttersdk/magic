# ROUTING SYSTEM

GoRouter wrapper with context-free navigation, middleware guards, and fluent route definitions.

## STRUCTURE

```
routing/
├── magic_router.dart          # MagicRouter singleton (GoRouter wrapper)
├── magic_router_outlet.dart   # MagicRouterOutlet — nested router shell widget
└── route_definition.dart      # RouteDefinition fluent builder
```

`MagicRoute` facade lives in `facades/route.dart` — provides static navigation API.

## MAGIC ROUTER

Singleton wrapping GoRouter. Navigation is context-free via `navigatorKey`.

```dart
MagicRouter.instance.routerConfig   // Pass to MaterialApp.router — only after Magic.init()
MagicRouter.instance.pathParameter('id')    // Extract :id from current path
MagicRouter.instance.queryParameter('q')   // Extract ?q= from URL
```

`routerConfig` must not be accessed before `Magic.init()` completes — GoRouter builds on first access.

## ROUTE DEFINITIONS

```dart
// Simple page registration
MagicRoute.page('/monitors', () => MonitorController.instance.index());
MagicRoute.page('/monitors/:id', () => MonitorController.instance.show());

// Fluent builder — name, middleware, transition
RouteDefinition('/admin', () => AdminController.instance.index())
    .name('admin.index')
    .middleware(['auth'])
    .transition(RouteTransition.fade);
```

All route builders collect into `MagicRouter.instance` before `Magic.init()` builds GoRouter.
Register routes in `RouteServiceProvider.register()`, never in `boot()`.

## NAVIGATION API

```dart
MagicRoute.to('/monitors');              // Push
MagicRoute.back();                       // Pop
MagicRoute.toNamed('admin.index');       // Named route push
MagicRoute.replace('/login');            // Replace current (no back stack entry)
```

All methods delegate to `MagicRouter.instance` which uses `navigatorKey.currentState`.
No `BuildContext` required anywhere in the call chain.

## INTENDED URL (Redirect-After-Login)

Store a destination before redirecting to login, then restore it post-auth.

```dart
MagicRouter.instance.setIntendedUrl('/dashboard/settings');
final url = MagicRouter.instance.pullIntendedUrl(); // Returns and clears stored URL
```

`pullIntendedUrl()` returns `null` if nothing was stored. Pattern: redirect guard calls
`setIntendedUrl`, auth success calls `pullIntendedUrl` and navigates there.

## MIDDLEWARE GUARD

`_MiddlewareGuard` is a private widget injected by `RouteDefinition` when `.middleware()` is set.
It runs the Kernel middleware pipeline synchronously before rendering the page widget.

- Middleware receives `RouteSettings` and a `next` callback.
- Returning without calling `next` halts rendering (redirect in middleware body).
- Auth guard middleware calls `setIntendedUrl` + `MagicRoute.replace('/login')` on failure.

## ROUTE TRANSITIONS

```dart
enum RouteTransition { fade, slideRight, slideUp, scale, none }
```

Set per-route via `.transition(RouteTransition.slideUp)`. Default is `none` (platform default).
Custom transitions wrap the page builder in a `CustomTransitionPage`.

## GOTCHAS

- Routes must be registered before `Magic.init()` — GoRouter snapshot is taken at build time.
- `pathParameter` / `queryParameter` read from GoRouter's current route state, not a URL string.
- Named routes require `.name()` on `RouteDefinition`; `MagicRoute.page()` does not register names.
- Middleware list strings map to kernel middleware aliases — unknown keys are silently skipped.
- `replace()` clears the current history entry; avoid on root routes or the stack empties.
