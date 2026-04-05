---
path: "lib/src/routing/**/*.dart"
---

# Routing Domain

- `MagicRouter` wraps GoRouter — singleton accessed via `MagicRouter.instance`
- Route registration: `Route.get('/path', () => Widget())`, `Route.page('/path', () => Widget())` — `page()` preferred over deprecated `path()`
- Route parameters: `Route.get('/users/:id', (id) => UserPage(id: id))` — params extracted from path
- Route groups: `Route.group('/admin', middleware: ['auth'], routes: [...])` — nested routes with shared middleware/prefix
- Layout wrapping: `Route.layout(() => AdminLayout(), routes: [...])` — shell route for persistent UI
- Middleware binding: `.middleware(['auth', 'admin'])` — names must be registered in `Kernel`
- Context-free navigation: `Route.to('/path')`, `Route.back()`, `Route.replace('/path')` — no BuildContext needed
- `routerConfig` property: use with `MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig)`
- Router config only accessible AFTER `Magic.init()` completes — accessing before init throws
- `RouteDefinition` — data class holding path, builder, middleware names, transition config
- `LayoutDefinition` — shell route wrapper for persistent navigation (sidebar, bottom nav)
- `RouteServiceProvider` registers routes in boot phase — recommended place for all route definitions
- Custom transitions: `Route.get('/path', () => Page()).transition(TransitionType.fade)`
- Observer support: `MagicRouter.instance.addObserver(observer)` — must register before `routerConfig` is accessed. Passed to GoRouter `observers` param. Read-only via `observers` getter
