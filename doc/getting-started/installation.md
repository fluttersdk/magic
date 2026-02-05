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

- **Dart SDK**: 3.4.0 or higher
- **Flutter**: 3.22.0 or higher

<a name="installing-magic"></a>
## Installing Magic

### 1. Add Dependencies

Add `fluttersdk_magic` and `fluttersdk_wind` to your `pubspec.yaml`:

```yaml
dependencies:
  fluttersdk_magic:
    git:
      url: https://github.com/fluttersdk/magic.git
  fluttersdk_wind:
    git:
      url: https://github.com/fluttersdk/wind.git
```

Then run:

```bash
flutter pub get
```

### 2. Activate Magic CLI

The Magic CLI provides helpful commands for generating code. Activate it globally:

```bash
dart pub global activate fluttersdk_magic_cli
```

> [!NOTE]
> Ensure `~/.pub-cache/bin` is in your system PATH to use the `magic` command globally.

<a name="bootstrapping-your-application"></a>
## Bootstrapping Your Application

### 1. Create Configuration

Create a `lib/config/app.dart` file to export your application configuration:

```dart
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

final appConfig = {
  'app': {
    'name': Env.get('APP_NAME', 'Magic App'),
    'debug': Env.get('APP_DEBUG', true),
    'url': Env.get('APP_URL', 'http://localhost'),
    'providers': [
      // Register logic providers here
      // (app) => RouteServiceProvider(app),
    ],
  }
};
```

### 2. Initialize in Main

In your `lib/main.dart`, initialize Magic before running your app:

```dart
import 'package:flutter/material.dart';
import 'package:fluttersdk_magic/fluttersdk_magic.dart';
import 'config/app.dart';

void main() async {
  // 1. Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Magic
  await Magic.init(
    envFileName: '.env',
    configFactories: [
      () => appConfig,
    ],
  );

  // 3. Register Routes (if using manual route registration)
  // registerRoutes();

  // 4. Run App
  runApp(const MagicApplication());
}
```

The `Magic.init()` method accepts:

| Parameter | Type | Description |
|-----------|------|-------------|
| `envFileName` | `String` | Environment file name (default: `.env`) |
| `configFactories` | `List<Function>` | Configuration factory functions |
| `configs` | `List<Map>` | Direct configuration maps |
| `providers` | `List<ServiceProvider>` | Additional service providers |

### 3. The Application Widget

Use `MagicApplication` as your root widget. It handles strict routing, themes, and localization automatically:

```dart
class MagicApplication extends StatelessWidget {
  const MagicApplication({super.key});

  @override
  Widget build(BuildContext context) {
    return MagicAppWidget(
      title: Config.get('app.name', 'Magic App'),
      initialRoute: '/',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
      ),
    );
  }
}
```

<a name="wind-ui-plugin"></a>
## Wind UI Plugin

Magic includes **Wind UI** (`fluttersdk_wind`), a utility-first styling engine inspired by Tailwind CSS. Instead of nesting widgets, you compose UIs with className strings:

```dart
WDiv(
  className: 'flex flex-col gap-4 p-6 bg-slate-900 rounded-xl',
  children: [
    WText('Welcome', className: 'text-2xl font-bold text-white'),
    WFormInput(
      controller: emailController,
      label: 'Email',
      placeholder: 'you@example.com',
      className: 'w-full bg-slate-800 border border-gray-700 rounded-lg p-3',
    ),
    WButton(
      onTap: () => submit(),
      className: 'bg-primary hover:bg-primary/80 px-4 py-3 rounded-lg',
      child: WText('Sign In', className: 'text-white text-center'),
    ),
  ],
)
```

> [!TIP]
> See the [Wind UI Documentation](/packages/wind-ui) for the complete widget reference and utility class guide.

<a name="next-steps"></a>
## Next Steps

Now that you've installed Magic, you may be wondering what to learn next. Here are some recommendations:

- **[Configuration](/getting-started/configuration)** - Learn how Magic's configuration system works.
- **[Directory Structure](/getting-started/directory-structure)** - Understand the recommended project layout.
- **[Routing](/basics/routing)** - Define your application's navigation.
- **[Controllers](/basics/controllers)** - Handle user interactions and business logic.
- **[Eloquent ORM](/eloquent/getting-started)** - Work with databases the beautiful way.

Welcome to the Magic community. We're excited to see what you'll build!
