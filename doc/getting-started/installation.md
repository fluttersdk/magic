# Installation

Magic is a Laravel-inspired Flutter framework: add the package, call `Magic.init()`, and your app gains an IoC container, 13 facades, Eloquent ORM, routing, auth, and more.

- [Meet Magic](#meet-magic)
- [Why Magic?](#why-magic)
- [Requirements](#requirements)
- [Installing Magic](#installing-magic)
- [Bootstrapping Your Application](#bootstrapping-your-application)
- [Wind UI Plugin](#wind-ui-plugin)
- [Upgrading from 0.0.x](#upgrading-from-0-0-x)
- [Next Steps](#next-steps)

<a name="meet-magic"></a>
## Meet Magic

Magic is **Laravel for Flutter**. It's a framework built on the belief that mobile app development should be a joy, not a chore. Like Laravel revolutionized PHP development, Magic brings the same elegance and developer happiness to Flutter.

If you've ever used Laravel, you'll feel right at home. Magic provides:

- **Eloquent ORM** - Beautiful, active-record style models over your REST API (and local storage with a plugin) with the same syntax you love.
- **Expressive Routing** - Define your app's navigation with clean, fluent route definitions.
- **Service Container** - Powerful dependency injection and service management.
- **Facades** - Simple, static-like access to core services without the complexity.
- **Magic CLI** - Laravel-style scaffolding (a `dowel` plugin) for controllers, models, views, actions, and more.
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
final users = await User.all();
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

- **Dart SDK**: 3.13.0 or higher
- **Flutter**: 3.47.0 or higher

<a name="installing-magic"></a>
## Installing Magic

### 1. Add the Package

Add `magic` to your Flutter project:

```bash
flutter pub add magic
```

This pulls in Magic and its dependencies, including **Wind UI** (`wind_kit`) and the **Magic CLI**. Optional layers are separate plugin packages: `magic_local_storage` (SQLite, migrations, seeders, sync), `magic_encryption` (AES encryption), `magic_picker` (file, image and video picking, share sheet) and `magic_socket` (real-time broadcasting). Add one with `flutter pub add <package>` then `dart run magic:dowel plugin:install <package>`.

### 2. Scaffold Your Application

The Magic CLI ships as a `dowel` executable bundled with the `magic` package (declared in its `pubspec.yaml` `executables:`). Run it from any project that depends on magic:

```bash
dart run magic:dowel magic:install
```

No global activation or package-name substitution is needed: `dart run magic:dowel` resolves magic's bundled executable directly.

The installer adds `wind_kit`, `material_ui` and `dowel` to your `pubspec.yaml` and scaffolds `bin/dispatcher.dart` (plus the fast wrapper `bin/dowel`) through dowel's `install`. This command creates everything you need:
- `lib/config/`: Configuration files (app, auth, cache, network, logging, routing, view)
- `lib/app/` — Controllers, models, providers, middleware, policies
- `lib/routes/` — Route definitions
- `lib/resources/views/` — UI view classes
- `lib/main.dart` — Bootstrapped entry point with `Magic.init()`
- `.env` / `.env.example` — Environment configuration

You can exclude features you don't need:

```bash
dart run magic:dowel magic:install --without-auth --without-cache
```

Available flags: `--without-auth`, `--without-network`, `--without-cache`, `--without-localization`, `--without-logging`. See [Magic CLI](../packages/magic-cli.md#install) for details.

<a name="bootstrapping-your-application"></a>
## Bootstrapping Your Application

If you used `dart run magic:dowel magic:install`, your application is already bootstrapped. The install command generates a ready-to-run `main.dart` and all configuration files. Here's what was created:

### Generated Entry Point

The generated `lib/main.dart` initializes Magic and runs your app:

```dart
import 'package:material_ui/material_ui.dart';
import 'package:magic/magic.dart';
import 'config/app.dart';
import 'config/view.dart';
import 'config/auth.dart';
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
import 'package:material_ui/material_ui.dart';
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

To keep a widget on screen across every page, such as a floating player, pass a `builder`; see [A Layer Above Every Page](../basics/routing.md#a-layer-above-every-page).

<a name="wind-ui-plugin"></a>
## Wind UI Plugin

Magic includes **Wind UI** (`wind_kit`), a utility-first styling engine inspired by Tailwind CSS. Instead of nesting widgets, you compose UIs with className strings like `flex flex-col p-4 bg-white rounded-xl shadow-md`.

> [!TIP]
> For the complete widget reference, utility classes, and advanced patterns, see the [Wind UI Documentation](https://wind.fluttersdk.com/getting-started/installation).

<a name="upgrading-from-0-0-x"></a>
## Upgrading from 0.0.x

The CLI, the styling package and the SDK floor changed in 0.1.0. See the changelog for the full list; the steps an app needs are:

1. Raise the SDK floor to Dart 3.13 and Flutter 3.47, then swap the packages: `dart pub remove fluttersdk_artisan fluttersdk_wind` and `dart pub add dowel wind_kit material_ui`. Magic itself resolves to 0.1.x.
2. `fluttersdk_wind` is now `wind_kit`: change `package:fluttersdk_wind/fluttersdk_wind.dart` to `package:wind_kit/wind_kit.dart`. `MaterialApp`, `ThemeData` and `Colors` come from `package:material_ui/material_ui.dart`, because wind_kit builds on it and the two sets of types do not mix: run `dart fix --apply --code=deprecated_member_use` to swap the imports.
3. Move the project state from `.artisan/` to `.dowel/`, so the install records and their file hashes survive. Delete `.dowel/plugins.json` and the records under `.dowel/installed/` that belong to renamed packages (`fluttersdk_*`). Delete the generated `bin/dispatcher.dart`, `bin/fsa`, a leftover `bin/artisan.dart`, `lib/app/_plugins.g.dart` and `lib/app/commands/_index.g.dart`. In your own commands and providers replace `package:fluttersdk_artisan/artisan.dart` with `package:dowel/dowel.dart` and `Artisan*` classes with `Dowel*`.
4. Run `dart run dowel install`, which scaffolds `bin/dispatcher.dart` and `bin/dowel`, then `dart run dowel commands:refresh`. Register magic and each plugin again so they land in `.dowel/plugins.json`: `dart run dowel plugin:install magic`, then `dart run dowel plugin:install <package>`. A file a renamed plugin published earlier is reported as an `unmanaged-file` conflict: review it, then re-run with `--force`.
5. From then on run the CLI as `dart run magic:dowel <command>`. It hands over to your `bin/dispatcher.dart`, so plugin commands resolve. If `dart run dowel install` ran before `magic` was in the project, the dispatcher has no magic provider: run `dart run dowel plugin:install magic`.

The dowel changelog for 0.0.21 carries the full recipe, including the `.mcp.json` cleanup.

<a name="next-steps"></a>
## Next Steps

Now that you've installed Magic, you may be wondering what to learn next. Here are some recommendations:

- **[Configuration](./configuration.md)** - Learn how Magic's configuration system works.
- **[Directory Structure](./directory-structure.md)** - Understand the recommended project layout.
- **[Routing](../basics/routing.md)** - Define your application's navigation.
- **[Controllers](../basics/controllers.md)** - Handle user interactions and business logic.
- **[Eloquent ORM](../eloquent/getting-started.md)** - Work with your models the beautiful way.

Welcome to the Magic community. We're excited to see what you'll build!
