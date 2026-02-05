# Directory Structure

- [Introduction](#introduction)
- [The Root Directory](#the-root-directory)
- [The App Directory](#the-app-directory)
- [The Config Directory](#the-config-directory)
- [The Resources Directory](#the-resources-directory)
- [The Routes Directory](#the-routes-directory)
- [The Database Directory](#the-database-directory)

<a name="introduction"></a>
## Introduction

The default Magic application structure is intended to provide a great starting point for both large and small applications. But you are free to organize your application however you like. Magic imposes almost no restrictions on where any given class is located—as long as the classes can be imported.

<a name="the-root-directory"></a>
## The Root Directory

A fresh Magic project contains the following directories:

```
my_app/
├── lib/
│   ├── app/                 # Application logic
│   ├── config/              # Configuration files
│   ├── database/            # Migrations, seeders, factories
│   ├── resources/           # Views and assets
│   ├── routes/              # Route definitions
│   └── main.dart            # Application entry point
├── assets/
│   └── lang/                # Localization JSON files
├── .env                     # Environment variables
└── pubspec.yaml             # Dependencies
```

<a name="the-app-directory"></a>
## The App Directory

The `app` directory contains the core code of your application. Almost all of the classes in your application will be in this directory.

```
lib/app/
├── controllers/             # Request handlers
├── middleware/              # Route middleware
├── models/                  # Eloquent models
├── policies/                # Authorization policies
├── providers/               # Service providers
└── kernel.dart              # Application kernel
```

### The Controllers Directory

The `controllers` directory contains all of your application's controller classes. Controllers are responsible for handling incoming requests and returning responses.

```dart
// lib/app/controllers/user_controller.dart
class UserController extends MagicController with MagicStateMixin<List<User>> {
  static UserController get instance => Magic.findOrPut(UserController.new);
  
  Widget index() => UserListView();
  Widget show(String id) => UserShowView(id: id);
}
```

### The Middleware Directory

The `middleware` directory contains your application's route middleware. Middleware provide a convenient mechanism for filtering requests entering your application.

```dart
// lib/app/middleware/auth_middleware.dart
class AuthMiddleware extends Middleware {
  @override
  Future<bool> handle() async {
    if (!Auth.check()) {
      MagicRoute.to('/login');
      return false;
    }
    return true;
  }
}
```

### The Models Directory

The `models` directory contains all of your Eloquent model classes. Each database table has a corresponding "Model" which is used to interact with that table.

```dart
// lib/app/models/user.dart
class User extends Model with HasTimestamps, InteractsWithPersistence {
  @override String get table => 'users';
  @override String get resource => 'users';
  
  String? get name => getAttribute('name') as String?;
  String? get email => getAttribute('email') as String?;
}
```

### The Policies Directory

The `policies` directory contains the authorization policy classes for your application. Policies are used to determine if a user can perform a given action against a resource.

### The Providers Directory

The `providers` directory contains all of the service providers for your application. Service providers bootstrap your application by binding services in the service container and registering events.

```dart
// lib/app/providers/route_service_provider.dart
class RouteServiceProvider extends ServiceProvider {
  @override
  void boot() {
    registerRoutes();
  }
}
```

<a name="the-config-directory"></a>
## The Config Directory

The `config` directory contains all of your application's configuration files. Each file returns a Map that is merged into Magic's configuration.

```
lib/config/
├── app.dart                 # App name, env, providers
├── auth.dart                # Guards, session config
├── database.dart            # Database connections
├── network.dart             # API endpoints, timeouts
├── cache.dart               # Cache drivers
├── logging.dart             # Log channels
└── localization.dart        # Supported locales
```

> [!TIP]
> Use the `magic config:list` command to see all available configuration keys.

<a name="the-resources-directory"></a>
## The Resources Directory

The `resources` directory contains your views and other UI resources.

```
lib/resources/
└── views/
    ├── auth/                # Authentication views
    │   ├── login_view.dart
    │   └── register_view.dart
    ├── layouts/             # Layout components
    │   ├── app_layout.dart
    │   └── guest_layout.dart
    ├── components/          # Reusable UI components
    │   ├── app_sidebar.dart
    │   └── app_header.dart
    └── dashboard_view.dart
```

Views in Magic are Dart classes that extend `MagicView` or `MagicStatefulView`:

```dart
// lib/resources/views/dashboard_view.dart
class DashboardView extends MagicView {
  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'p-4 flex flex-col gap-4',
      children: [
        WText('Dashboard', className: 'text-2xl font-bold'),
      ],
    );
  }
}
```

<a name="the-routes-directory"></a>
## The Routes Directory

The `routes` directory contains all of the route definitions for your application.

```
lib/routes/
├── web.dart                 # Main application routes
└── api.dart                 # API routes (optional)
```

Routes are defined using the `MagicRoute` facade:

```dart
// lib/routes/web.dart
void registerRoutes() {
  MagicRoute.group(
    prefix: '/',
    middleware: ['auth'],
    layout: (child) => AppLayout(child: child),
    routes: () {
      MagicRoute.page('/', () => DashboardView());
      MagicRoute.page('/users', () => UserController.instance.index());
      MagicRoute.page('/users/:id', (id) => UserController.instance.show(id));
    },
  );
}
```

> [!NOTE]
> Use `magic route:list` to display all registered routes in your application.

<a name="the-database-directory"></a>
## The Database Directory

The `database` directory contains your database migrations, model factories, and seeders.

```
lib/database/
├── migrations/              # Schema migrations
│   └── 2024_01_01_000000_create_users_table.dart
├── seeders/                 # Data seeders
│   └── user_seeder.dart
└── factories/               # Model factories
    └── user_factory.dart
```

### Migrations

Migrations are like version control for your database, allowing you to modify your database schema:

```dart
class CreateUsersTable extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await schema.create('users', (table) {
      table.id();
      table.string('name');
      table.string('email').unique();
      table.timestamps();
    });
  }
  
  @override
  Future<void> down(Schema schema) async {
    await schema.drop('users');
  }
}
```

### Seeders

Seeders populate your database with test data:

```dart
class UserSeeder extends Seeder {
  @override
  Future<void> run() async {
    await User.factory().count(10).create();
  }
}
```

### Factories

Factories define how to generate fake model instances:

```dart
class UserFactory extends Factory<User> {
  @override
  Map<String, dynamic> definition() => {
    'name': faker.person.name(),
    'email': faker.internet.email(),
  };
}
```
