---
name: magic-framework
description: >
  Laravel-inspired Flutter framework (Magic Framework) development guide. Provides complete API reference
  for 15 Facades (Auth, Cache, Config, DB, Event, Http, Log, Lang, Storage, Route, Schema, Gate, Crypt, Vault, Pick),
  Eloquent ORM, IoC Container, Service Providers, MVC architecture, validation, and routing.
  Use when working on any Flutter project that imports `package:fluttersdk_magic`, or when the user asks about
  Magic Framework patterns, facades, models, controllers, providers, migrations, routing, auth, events, or testing.
  Also use when creating new models, controllers, views, service providers, migrations, seeders, factories,
  middleware, events, listeners, policies, or validation rules in a Magic-based project.
---

# Magic Framework — Skill Guide

## Lifecycle

```
Magic.init() → Env.load() → configFactories evaluated → MagicApp.init(configs)
→ providers register() → providers boot() → router pre-built → app ready
```

**Critical**: `await Magic.init()` must complete before ANY facade call.

## IoC Container (MagicApp)

| Method | Purpose |
|--------|---------|
| `app.singleton(key, () => T())` | Shared instance (created once) |
| `app.bind(key, () => T())` | Factory (new instance each call) |
| `app.setInstance(key, value)` | Store pre-built instance |
| `Magic.make<T>(key)` | Resolve from container |
| `Magic.app.bound(key)` | Check if registered |

## Quick Facade Reference

Read `references/facades.md` for full method signatures of all 15 facades.

**Resolution patterns**:
- Static singleton: `Auth`, `Config`, `Event`, `Lang`, `Route`, `Gate`, `Pick`, `Storage`
- Container-based: `Cache`, `DB`, `Http`, `Log`, `Crypt`, `Vault`

## Eloquent ORM

Read `references/eloquent.md` for Model, QueryBuilder, Blueprint, migrations, factories, and seeders.

**Key patterns**:
```dart
// Model definition
class User extends Model with HasTimestamps, InteractsWithPersistence, Authenticatable {
  @override String get table => 'users';
  @override String get resource => 'users';
  @override List<String> get fillable => ['name', 'email'];
  @override Map<String, String> get casts => {'born_at': 'datetime'};
}

// Query
DB.table('users').where('active', true).orderBy('name').get();

// Schema
Schema.create('users', (table) {
  table.id();
  table.string('name');
  table.string('email').unique();
  table.timestamps();
});
```

## Service Providers

```dart
class FeatureServiceProvider extends ServiceProvider {
  FeatureServiceProvider(super.app);

  @override
  void register() {
    // Bind only — NO resolution or side effects
    app.singleton('feature', () => FeatureService());
  }

  @override
  Future<void> boot() async {
    // All providers registered — safe to resolve
    final feature = app.make<FeatureService>('feature');
    await feature.configure();
  }
}
```

Register in `app.providers` config or via `Magic.init(providers: [...])`.

## MVC Architecture

Read `references/mvc.md` for controllers, views, forms, feedback, and responsive views.

**Key patterns**:
```dart
// Controller with state
class UserController extends MagicController with MagicStateMixin<User> {
  Future<void> fetch() async {
    setLoading();
    try { setSuccess(await User.find(1)); }
    catch (e) { setError(e.toString()); }
  }
}

// View
class UserView extends MagicView<UserController> {
  @override
  Widget build(BuildContext context) =>
    controller.renderState((user) => Text(user.name));
}
```

## Routing

```dart
// Define routes
Route.page('/', HomePage.new).name('home');
Route.group(prefix: '/admin', middleware: [AuthMw()], routes: () {
  Route.page('/dashboard', DashboardView.new);
});

// Navigate (context-free)
Route.to('/dashboard');
Route.toNamed('home');
Route.push('/details');
Route.back();

// Use in MaterialApp
MaterialApp.router(routerConfig: Route.config)
```

## Auth System

```dart
// Setup: register user factory in boot phase
Auth.registerModel<User>(User.fromMap);

// Usage
await Auth.login(credentials, user);
if (Auth.check()) { final user = Auth.user<User>(); }
await Auth.logout();

// Guards: bearer, sanctum, basic, api_key
// Events: UserLoggedIn, UserLoggedOut, AuthRestored, AuthFailed
```

## Events

```dart
class EventServiceProvider extends BaseEventServiceProvider {
  @override
  Map<Type, List<MagicListener Function()>> get listen => {
    UserRegistered: [() => SendWelcomeEmail(), () => LogRegistration()],
  };
}

// Dispatch
await Event.dispatch(UserRegistered(user));
```

**Listeners are factories** — pass `() => Listener()`, not instances.

## Validation

```dart
// Programmatic
final v = Validator.make({'email': ''}, {'email': [Required(), Email()]});
if (v.fails()) print(v.errors());

// In forms (Flutter integration)
TextFormField(validator: FormValidator.rules<String>([Required(), Email()], field: 'email'))

// Rules: Required, Email, Min, Max, Between, Numeric, Alpha, AlphaNumeric,
//        Confirmed, In, NotIn, Regex
```

## Config Access

Dot notation: `Config.get('database.connections.sqlite.database')`

Use `configFactories` for values needing `env()`:
```dart
Magic.init(configFactories: [() => {'app': {'key': env('APP_KEY')}}]);
```

## Testing

```dart
setUp(() {
  MagicApp.reset();  // Reset singleton
  Magic.flush();     // Clear container
});
```

- Mirror source structure: `lib/src/auth/` → `test/auth/`
- Mock by implementing contracts — no codegen
- Use `setUpAll()` for expensive setup (translator, DB)

## Naming Conventions

| Item | Convention | Example |
|------|-----------|---------|
| Provider | `{Feature}ServiceProvider` | `AuthServiceProvider` |
| Controller | `{Resource}Controller` | `UserController` |
| Model | Singular PascalCase | `User`, `ProductType` |
| Event | `{Noun}{Verb}Event` | `UserLoggedInEvent` |
| Guard | `{Type}Guard` | `BearerTokenGuard` |
| Migration | `m_YYYY_MM_DD_HHMMSS_{verb}_{table}_table.dart` | `m_2024_01_01_120000_create_users_table.dart` |
| Files | snake_case | `user_controller.dart` |

## Gotchas

1. `Magic.init()` must complete before facade calls — it's async
2. Auth requires user factory: `Auth.registerModel<User>(factory)` in boot
3. Tests need `MagicApp.reset()` + `Magic.flush()` in setUp
4. Use `configFactories` for configs needing `env()`
5. Event listeners are factories: `() => Listener()`, not instances
6. Access `Route.config` only after `Magic.init()` completes
7. `EncryptionServiceProvider` must be added manually to providers
8. Web uses in-memory SQLite; mobile uses file-based
9. Always use `package:` imports, never relative
