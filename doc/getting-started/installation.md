# Installation

- [Meet Magic](#meet-magic)
- [Why Magic?](#why-magic)
- [Requirements](#requirements)
- [Installing Magic](#installing-magic)
- [Bootstrapping Your Application](#bootstrapping-your-application)
- [Wind UI Plugin](#wind-ui-plugin)
- [Next Steps](#next-steps)

<a name="meet-magic"></a>
## Meet Magic

Magic is **Laravel for Flutter**. It's a framework built on the belief that mobile app development should be a joy, not a chore. Like Laravel revolutionized PHP development, Magic brings the same elegance and developer happiness to Flutter.

If you've ever used Laravel, you'll feel right at home. Magic provides:

- **Eloquent ORM** - Beautiful, active-record style database interactions with the same syntax you love.
- **Expressive Routing** - Define your app's navigation with clean, fluent route definitions.
- **Service Container** - Powerful dependency injection and service management.
- **Facades** - Simple, static-like access to core services without the complexity.
- **Magic CLI** - Artisan-inspired scaffolding for controllers, models, migrations, and more.
- **Wind UI** - Tailwind CSS-like styling directly in Flutter. No more widget tree nightmares.

Magic strives to provide an amazing developer experience while taking care of the complex infrastructure concerns, so you can focus on building something extraordinary.

<a name="why-magic"></a>
## Why Magic?

There are many ways to build Flutter apps. So why choose Magic?

Magic is a **progressive framework**, meaning you can start simple and adopt more features as your application grows. Whether you're building a quick MVP or an enterprise-grade application, Magic scales with you.

### The Laravel Developer Experience

If you're coming from Laravel, you already know how to use Magic:

```dart
// Routing - Feels like home, right?
MagicRoute.get('/users', () => UserController().index());
MagicRoute.get('/users/:id', (id) => UserController().show(id));

// Eloquent - Same beautiful syntax
final users = await User.where('active', true).get();
final user = await User.find(1);
await user.delete();

// HTTP - Clean and simple
final response = await Http.get('/api/users');
if (response.successful) {
  // Handle data
}
```

### No BuildContext Nightmare

One of Flutter's most frustrating aspects is passing `BuildContext` everywhere. Magic eliminates this entirely:

```dart
// Show dialogs from anywhere - controllers, services, even pure Dart!
Magic.success('Done!', 'Profile updated successfully');
Magic.dialog(ConfirmationDialog());
Magic.loading();

// Navigate without context
MagicRoute.to('/dashboard');
MagicRoute.back();
```

### Wind UI - Tailwind for Flutter

Stop wrestling with nested widgets. Build UIs with utility-first classes:

```dart
WDiv(
  className: 'flex flex-col p-4 bg-white shadow-lg rounded-xl',
  children: [
    WText('Hello World', className: 'text-xl font-bold text-primary'),
    WButton(
      onTap: () => MagicRoute.to('/next'),
      className: 'bg-blue-500 hover:bg-blue-600 px-4 py-2 rounded-lg',
      child: WText('Get Started', className: 'text-white'),
    ),
  ],
)
```

<a name="requirements"></a>
## Requirements

Magic requires:

- **Dart SDK**: 3.11.0 or higher
- **Flutter**: 3.41.0 or higher

<a name="installing-magic"></a>
## Installing Magic

### 1. Add the Package

Add `magic` to your Flutter project:

```bash
flutter pub add magic
```

This pulls in Magic and all its dependencies, including **Wind UI** and the **Magic CLI**.

### 2. Scaffold Your Application

Magic CLI is bundled with the package — no global install needed. Run it via `dart run`:

```bash
dart run magic:magic install
```

This command creates everything you need:
- `lib/config/` — Configuration files (app, auth, broadcasting, cache, database, network, logging, routing, view)
- `lib/app/` — Controllers, models, providers, middleware, policies
- `lib/routes/` — Route definitions
- `lib/resources/views/` — UI view classes
- `lib/database/` — Migrations, seeders, factories
- `lib/main.dart` — Bootstrapped entry point with `Magic.init()`
- `.env` / `.env.example` — Environment configuration

You can exclude features you don't need:

```bash
dart run magic:magic install --without-database --without-auth --without-cache
```

Available flags: `--without-auth`, `--without-database`, `--without-network`, `--without-cache`, `--without-events`, `--without-localization`, `--without-logging`, `--without-broadcasting`. See [Magic CLI](/doc/packages/magic-cli.md#install) for details.

> [!TIP]
> For convenience, you can also activate the CLI globally: `dart pub global activate magic_cli`. This lets you use the shorter `magic install` syntax instead of `dart run magic:magic install`.

<a name="bootstrapping-your-application"></a>
## Bootstrapping Your Application

If you used `dart run magic:magic install`, your application is already bootstrapped. The install command generates a ready-to-run `main.dart` and all configuration files. Here's what was created:

### Generated Entry Point

The generated `lib/main.dart` initializes Magic and runs your app:

```dart
import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'config/app.dart';
import 'config/view.dart';
import 'config/auth.dart';
import 'config/database.dart';
import 'config/network.dart';
import 'config/cache.dart';
import 'config/logging.dart';
import 'config/routing.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Magic.init(
    configFactories: [
      () => appConfig,
      () => viewConfig,
      () => authConfig,
      () => databaseConfig,
      () => networkConfig,
      () => cacheConfig,
      () => loggingConfig,
      () => routingConfig,
    ],
  );

  runApp(
    MagicApplication(title: 'My App'),
  );
}
```

The `Magic.init()` method accepts:

| Parameter | Type | Description |
|-----------|------|-------------|
| `envFileName` | `String` | Environment file name (default: `.env`) |
| `configFactories` | `List<Function>` | Configuration factory functions |
| `configs` | `List<Map>` | Direct configuration maps |
| `providers` | `List<ServiceProvider>` | Additional service providers |

### Manual Setup (Without CLI)

If you prefer to set up manually without the CLI, create a `lib/config/app.dart`:

```dart
import 'package:magic/magic.dart';

final appConfig = {
  'app': {
    'name': Env.get('APP_NAME', 'Magic App'),
    'debug': Env.get('APP_DEBUG', true),
    'url': Env.get('APP_URL', 'http://localhost'),
    'providers': [
      (app) => RouteServiceProvider(app),
      (app) => AppServiceProvider(app),
    ],
  }
};
```

Then initialize in `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'config/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Magic.init(
    configFactories: [() => appConfig],
  );

  runApp(MagicApplication(title: 'My App'));
}
```

### The Application Widget

`MagicApplication` is your root widget. It handles routing, themes, localization, and overlays automatically:

```dart
runApp(
  MagicApplication(
    title: 'My App',
    debugShowCheckedModeBanner: false,
  ),
);
```

<a name="wind-ui-plugin"></a>
## Wind UI Plugin

Magic includes **Wind UI** (`fluttersdk_wind`), a utility-first styling engine inspired by Tailwind CSS. Instead of nesting widgets, you compose UIs with className strings like `flex flex-col p-4 bg-white rounded-xl shadow-md`.

> [!TIP]
> For the complete widget reference, utility classes, and advanced patterns, see the [Wind UI Documentation](https://wind.fluttersdk.com/getting-started/installation).

<a name="next-steps"></a>
## Next Steps

Now that you've installed Magic, you may be wondering what to learn next. Here are some recommendations:

- **[Configuration](/getting-started/configuration)** - Learn how Magic's configuration system works.
- **[Directory Structure](/getting-started/directory-structure)** - Understand the recommended project layout.
- **[Routing](/basics/routing)** - Define your application's navigation.
- **[Controllers](/basics/controllers)** - Handle user interactions and business logic.
- **[Eloquent ORM](/eloquent/getting-started)** - Work with databases the beautiful way.

Welcome to the Magic community. We're excited to see what you'll build!
