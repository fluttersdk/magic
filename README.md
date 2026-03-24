<p align="center">
  <img src=".github/magic-logo.svg" width="120" alt="Magic Logo" />
</p>

<h1 align="center">Magic</h1>

<p align="center">
  <strong>The Laravel Experience for Flutter.</strong><br/>
  Build production-ready Flutter apps with Facades, Eloquent ORM, Service Providers, and IoC Container — zero boilerplate.
</p>

<p align="center">
  <a href="https://pub.dev/packages/magic"><img src="https://img.shields.io/pub/v/magic.svg" alt="pub package"></a>
  <a href="https://github.com/fluttersdk/magic/actions"><img src="https://img.shields.io/github/actions/workflow/status/fluttersdk/magic/ci.yml?branch=master&label=CI" alt="CI"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
  <a href="https://pub.dev/packages/magic/score"><img src="https://img.shields.io/pub/points/magic" alt="pub points"></a>
  <a href="https://github.com/fluttersdk/magic/stargazers"><img src="https://img.shields.io/github/stars/fluttersdk/magic?style=flat" alt="GitHub stars"></a>
</p>

<p align="center">
  <a href="https://magic.fluttersdk.com">Documentation</a> ·
  <a href="https://pub.dev/packages/magic">pub.dev</a> ·
  <a href="https://github.com/fluttersdk/magic/issues">Issues</a>
</p>

---

> **Alpha Release** — Magic is under active development. APIs may change before stable. [Star the repo](https://github.com/fluttersdk/magic) to follow progress.

## Why Magic?

Flutter gives you widgets, but not architecture. Building a real app means wiring up HTTP clients, auth flows, caching, validation, routing, and state management — all from scratch, every time.

**Magic fixes this.** If you know Laravel, you already know Magic:

```dart
// Before — the Flutter way
final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
final response = await dio.get('/users/1');
final user = User.fromJson(response.data['data']);
// ...manually handle tokens, errors, caching, state...

// After — the Magic way
final user = await User.find(1);
```

## Features

| | Feature | Description |
|:--|:--------|:------------|
| 🏗️ | **IoC Container** | Service Container with singleton, bind, and instance registration |
| 🎭 | **16 Facades** | `Auth`, `Http`, `Cache`, `DB`, `Event`, `Gate`, `Log`, `Route`, `Lang`, `Storage`, `Vault`, `Crypt` and more |
| 🗄️ | **Eloquent ORM** | Models, QueryBuilder, migrations, seeders, factories — hybrid API + SQLite persistence |
| 🛣️ | **Routing** | GoRouter integration with middleware, named routes, and context-free navigation |
| 🔐 | **Authentication** | Token-based auth with guards (Bearer, BasicAuth, ApiKey), session restore, auto-refresh |
| 🛡️ | **Authorization** | Gates, policies, `MagicCan` / `MagicCannot` widgets |
| ✅ | **Validation** | Laravel-style rules: `Required`, `Email`, `Min`, `Max`, `In`, `Confirmed` |
| 📡 | **Events** | Pub/sub event system with `MagicEvent` and `MagicListener` |
| 💾 | **Caching** | Memory and file drivers with TTL and `remember()` |
| 🌍 | **Localization** | JSON-based i18n with `:attribute` placeholders |
| 🎨 | **Wind UI** | Built-in Tailwind CSS-like styling with `className` syntax |
| 🧰 | **Magic CLI** | Artisan-style code generation: `magic make:model`, `magic make:controller` |

## Quick Start

### 1. Add Magic to Your Project

```bash
# Create a new Flutter project (or use an existing one)
flutter create my_app
cd my_app

# Add Magic as a dependency
flutter pub add magic
```

### 2. Scaffold with Magic CLI

Magic CLI is bundled with the package — no global install needed:

```bash
# Initialize Magic with all features
dart run magic:magic install

# Or exclude specific features
dart run magic:magic install --without-database --without-auth
```

The CLI sets up everything: directory structure, config files, service providers, environment files, and bootstraps `main.dart`.

> [!TIP]
> For convenience, you can also activate the CLI globally: `dart pub global activate magic_cli`, then use `magic install` directly.

### 3. Build

```dart
class UserController extends MagicController with MagicStateMixin<List<User>> {
  static UserController get instance => Magic.findOrPut(UserController.new);

  Future<void> fetchUsers() async {
    setLoading();
    final response = await Http.get('/users');
    response.successful
        ? setSuccess(response.data['data'].map((e) => User.fromMap(e)).toList())
        : setError(response.firstError ?? 'Failed to load');
  }

  Widget index() => renderState(
    (users) => ListView.builder(
      itemCount: users.length,
      itemBuilder: (_, i) => ListTile(title: Text(users[i].name ?? '')),
    ),
    onLoading: const CircularProgressIndicator(),
    onError: (msg) => Text('Error: $msg'),
  );
}
```

## Facades

### Auth

```dart
// Login with token and user model
final response = await Http.post('/login', data: credentials);
final user = User.fromMap(response['data']['user']);
await Auth.login({'token': response['data']['token']}, user);

// Check authentication
if (Auth.check()) {
  final user = Auth.user<User>();
}

// Restore session on app start
await Auth.restore();

// Logout
await Auth.logout();
```

### HTTP Client

```dart
// Standard requests
final response = await Http.get('/users', query: {'page': 1});
await Http.post('/users', data: {'name': 'John', 'email': 'john@example.com'});
await Http.put('/users/1', data: {'name': 'Jane'});
await Http.delete('/users/1');

// RESTful resource helpers
final users = await Http.index('users', filters: {'role': 'admin'});
final user = await Http.show('users', '1');
await Http.store('users', {'name': 'John'});
await Http.update('users', '1', {'name': 'Jane'});
await Http.destroy('users', '1');

// File upload
await Http.upload('/avatar', data: {'user_id': '1'}, files: {'photo': file});

// Response API
response.successful   // 200-299
response.failed       // >= 400
response.data         // Map<String, dynamic>
response['key']       // Shorthand access
response.errors       // Laravel validation errors (422)
response.firstError   // First error message
```

### Routing

```dart
// Define routes
MagicRoute.page('/home', () => HomeController.instance.index());
MagicRoute.page('/users/:id', () => UserController.instance.show());

// Route groups with middleware
MagicRoute.group(
  prefix: '/admin',
  middleware: [AuthMiddleware()],
  routes: () {
    MagicRoute.page('/dashboard', () => AdminController.instance.index());
  },
);

// Navigate (context-free)
MagicRoute.to('/users');
MagicRoute.toNamed('user.show', params: {'id': '1'});
MagicRoute.back();
MagicRoute.replace('/login');
```

### Cache

```dart
// Store and retrieve
await Cache.put('key', 'value', ttl: Duration(minutes: 30));
final value = await Cache.get('key');

// Remember pattern — fetch once, cache for duration
final users = await Cache.remember<List<User>>(
  'all_users',
  Duration(minutes: 5),
  () => fetchUsersFromApi(),
);

// Check and forget
if (Cache.has('key')) {
  await Cache.forget('key');
}
await Cache.flush(); // Clear all
```

## Eloquent ORM

```dart
class User extends Model with HasTimestamps, InteractsWithPersistence {
  // Typed getters — always use get<T>()
  int? get id => get<int>('id');
  String? get name => get<String>('name');
  String? get email => get<String>('email');

  // Setters
  set name(String? v) => set('name', v);
  set email(String? v) => set('email', v);

  // Required overrides
  @override String get table => 'users';
  @override String get resource => 'users';
  @override List<String> get fillable => ['name', 'email'];

  // Static finders
  static Future<User?> find(dynamic id) =>
      InteractsWithPersistence.findById<User>(id, User.new);
  static Future<List<User>> all() =>
      InteractsWithPersistence.allModels<User>(User.new);
}

// CRUD — hybrid persistence (API + local SQLite)
final user = await User.find(1);     // SQLite first → API fallback → sync
final users = await User.all();
await user.save();                    // POST (create) or PUT (update)
await user.delete();                  // DELETE
await user.refresh();                 // Re-fetch from API
```

## Validation

```dart
final validator = Validator.make(
  {'email': email, 'password': password},
  {
    'email': [Required(), Email()],
    'password': [Required(), Min(8)],
  },
);

if (validator.fails()) {
  print(validator.errors()); // {'email': 'The email field is required.'}
}

// Or throw on failure
final data = validator.validate(); // Throws ValidationException if invalid
```

## Authorization

```dart
// Define abilities
Gate.define('update-post', (user, post) => user.id == post.userId);
Gate.before((user, ability) {
  if (user.isAdmin) return true;
  return null; // Fall through to specific check
});

// Check in code
if (Gate.allows('update-post', post)) {
  // Show edit button
}

// Check in widgets
MagicCan(
  ability: 'update-post',
  arguments: post,
  child: EditButton(),
)
```

## Forms

```dart
final form = MagicFormData({
  'name': user.name ?? '',
  'email': user.email ?? '',
});

// In widget tree
MagicForm(
  formData: form,
  child: Column(children: [
    WFormInput(label: 'Name', controller: form['name']),
    WFormInput(label: 'Email', controller: form['email']),
    WButton(
      onTap: () async {
        if (form.validate()) {
          await form.process(() => controller.updateProfile(form.data));
        }
      },
      isLoading: form.isProcessing,
      child: Text('Save'),
    ),
  ]),
)
```

## Events

```dart
// Define event
class UserRegistered extends MagicEvent {
  final User user;
  UserRegistered(this.user);
}

// Dispatch
await Event.dispatch(UserRegistered(user));

// Listen (register in ServiceProvider)
Event.listen<UserRegistered>(() => SendWelcomeEmail());
```

## Service Providers

```dart
class AppServiceProvider extends ServiceProvider {
  @override
  void register() {
    // Sync — bind to container
    app.singleton('payment', () => StripeService());
  }

  @override
  Future<void> boot() async {
    // Async — other services available
    Auth.registerModel<User>(User.fromMap);
  }
}

// Register in config
final appConfig = {
  'app': {
    'providers': [
      (app) => AppServiceProvider(app),
    ],
  },
};
```

## Wind UI

Magic includes [Wind UI](https://github.com/fluttersdk/wind) — Tailwind CSS-like styling for Flutter:

```dart
WDiv(
  className: 'flex flex-col gap-4 p-6 bg-white dark:bg-gray-900 rounded-xl shadow-lg',
  children: [
    WText('Dashboard', className: 'text-2xl font-bold text-gray-900 dark:text-white'),
    WButton(
      onTap: _refresh,
      className: 'bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg',
      child: Text('Refresh'),
    ),
  ],
)
```

## CLI Commands

```bash
dart run magic:magic make:model User -mcf        # Model + migration + controller + factory
dart run magic:magic make:controller User         # Controller
dart run magic:magic make:view Login              # View class
dart run magic:magic make:migration create_users  # Migration
dart run magic:magic make:seeder UserSeeder       # Database seeder
dart run magic:magic make:policy Post             # Authorization policy
dart run magic:magic make:provider Payment        # Service provider
dart run magic:magic make:event OrderShipped      # Event class
dart run magic:magic make:listener SendEmail      # Event listener
dart run magic:magic make:middleware Auth          # Middleware
dart run magic:magic make:request StoreUser       # Form request
dart run magic:magic make:lang tr                 # Language file
dart run magic:magic make:enum Status             # Enum class
```

> [!TIP]
> If you activated the CLI globally (`dart pub global activate magic_cli`), you can use the shorter `magic <command>` syntax instead.

## Architecture

```
Magic.init() → Env.load() → configFactories → providers register() → providers boot() → app ready
```

```
lib/
├── config/              # Configuration files (app, auth, cache, database)
├── app/
│   ├── controllers/     # Request handlers (MagicController)
│   ├── models/          # Eloquent models
│   └── policies/        # Authorization policies
├── database/
│   ├── migrations/      # Schema migrations
│   ├── seeders/         # Database seeders
│   └── factories/       # Model factories
├── resources/views/     # UI view classes
├── routes/              # Route definitions
└── main.dart            # Entry point
```

## Documentation

Full docs at **[magic.fluttersdk.com](https://magic.fluttersdk.com)**.

| Topic | |
|-------|--|
| [Installation](doc/getting-started/installation.md) | Setup and requirements |
| [Configuration](doc/getting-started/configuration.md) | Environment and config files |
| [Service Providers](doc/getting-started/service-providers.md) | Provider lifecycle |
| [Routing](doc/basics/routing.md) | Routes and navigation |
| [Controllers](doc/basics/controllers.md) | Request handlers |
| [Views](doc/basics/views.md) | UI layer |
| [HTTP Client](doc/basics/http-client.md) | Network requests |
| [Middleware](doc/basics/middleware.md) | Request pipeline |
| [Forms](doc/basics/forms.md) | Form handling and validation |

## AI Agent Integration

Use Magic with AI coding assistants like Claude Code, Cursor, or GitHub Copilot. The **magic-framework** skill teaches your AI the correct patterns — Facades, Eloquent ORM, Service Providers, controllers, routing, and common anti-patterns — so it generates correct Magic code on the first try.

Setup instructions and skill files: **[fluttersdk/ai](https://github.com/fluttersdk/ai)**

## Contributing

```bash
git clone https://github.com/fluttersdk/magic.git
cd magic && flutter pub get
flutter test && dart analyze
```

[Report a bug](https://github.com/fluttersdk/magic/issues/new?template=bug_report.yml) · [Request a feature](https://github.com/fluttersdk/magic/issues/new?template=feature_request.yml)

## License

MIT — see [LICENSE](LICENSE) for details.

---

<p align="center">
  <sub>Built with care by <a href="https://github.com/fluttersdk">FlutterSDK</a></sub><br/>
  <sub>If Magic saves you time, <a href="https://github.com/fluttersdk/magic">give it a star</a> — it helps others discover it.</sub>
</p>
