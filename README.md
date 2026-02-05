# Magic ✨

[![pub package](https://img.shields.io/pub/v/fluttersdk_magic.svg)](https://pub.dev/packages/fluttersdk_magic)
[![Flutter Version](https://img.shields.io/badge/Flutter-3.22.0%2B-blue.svg)](https://flutter.dev)
[![Dart Version](https://img.shields.io/badge/Dart-3.4.0%2B-blue.svg)](https://dart.dev)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**The Laravel Experience for Flutter.** Magic brings Laravel's elegant syntax and powerful features to Flutter, letting you build production-ready mobile apps with zero boilerplate.

```dart
// Laravel-style routing
Route.get('/users/:id', (id) => UserController().show(id));

// Eloquent-like models
final user = await User.find(1);
await user.update({'name': 'John Doe'});

// Familiar facades  
await Auth.login({'token': token}, user);
await Cache.put('key', 'value', duration: Duration(hours: 1));
```

---

## 🚀 Quick Start

### Install via Magic CLI (Recommended)

```bash
# Activate the CLI globally
dart pub global activate fluttersdk_magic_cli

# Navigate to your Flutter project
cd my_app

# Initialize Magic with all features
magic init
```

The CLI will set up everything: dependencies, directory structure, configuration files, and service providers.

### Exclude Features (Optional)

```bash
magic init --without-database --without-events
```

---

## 📦 Manual Installation

### 1. Add Dependency

```yaml
# pubspec.yaml
dependencies:
  fluttersdk_magic:
    git:
      url: https://github.com/fluttersdk/magic.git
```

### 2. Create Configuration

```dart
// lib/config/app.dart
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

final appConfig = {
  'app': {
    'name': Env.get('APP_NAME', 'My App'),
    'providers': [
      (app) => RouteServiceProvider(app),
    ],
  }
};
```

### 3. Bootstrap Magic

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:fluttersdk_magic/fluttersdk_magic.dart';
import 'config/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Magic.init(
    configFactories: [() => appConfig],
  );

  runApp(
    MagicApplication(title: 'My App'),
  );
}
```

---

## 📁 Directory Structure

```
lib/
├── config/              # Configuration files
│   ├── app.dart
│   ├── auth.dart
│   └── database.dart
├── app/
│   ├── controllers/     # Request handlers
│   ├── models/          # Eloquent models
│   └── policies/        # Authorization policies
├── database/
│   ├── migrations/      # Schema migrations
│   ├── seeders/         # Database seeders
│   └── factories/       # Model factories
├── resources/
│   └── views/           # UI view classes
├── routes/              # Route definitions
└── main.dart            # Entry point
```

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| **Routing** | Named routes, middleware, deep linking with `go_router` |
| **Eloquent ORM** | Query builder, relationships, migrations |
| **Authentication** | Token-based auth, guards, session management |
| **Authorization** | Gates, policies, `MagicCan` widget |
| **Validation** | Laravel-style validation rules |
| **Caching** | File, memory, and secure storage |
| **Events** | Pub/sub event system |
| **Localization** | JSON-based i18n with `__()` helper |
| **Service Container** | Dependency injection |
| **Wind UI** | Tailwind CSS-like styling |

---

## 🎨 Wind UI Plugin

Build beautiful UIs with Tailwind CSS-like utility classes:

```dart
WDiv(
  className: "flex flex-col p-4 bg-white shadow-lg rounded-xl",
  children: [
    WText("Hello World", className: "text-xl font-bold text-blue-500"),
    WButton(
      onTap: () => print('Clicked!'),
      className: "mt-4 px-4 py-2 bg-blue-600 rounded-lg",
      child: WText("Click Me", className: "text-white"),
    ),
  ],
)
```

---

## ⚙️ Configuration

Magic uses `.env` files for environment-specific configuration:

```bash
# .env
APP_NAME="Magic App"
APP_ENV=local
APP_DEBUG=true
API_BASE_URL=https://api.example.com
```

Access configuration values anywhere:

```dart
final appName = Config.get('app.name', 'Default');
final apiUrl = Env.get('API_BASE_URL');
```

---

## 📖 Documentation

| Topic | Description |
|-------|-------------|
| [Installation](doc/getting-started/installation.md) | Setup and requirements |
| [Configuration](doc/getting-started/configuration.md) | Environment and config files |
| [Routing](doc/routing/basic-routing.md) | Routes and navigation |
| [Authentication](doc/security/authentication.md) | Guards and login |
| [Authorization](doc/security/authorization.md) | Gates and policies |
| [Database](doc/database/getting-started.md) | Eloquent models and queries |
| [Validation](doc/validation/validation.md) | Form validation rules |
| [Caching](doc/cache/cache.md) | Cache drivers and usage |
| [Events](doc/events/events.md) | Event dispatching |
| [Localization](doc/localization/localization.md) | Multi-language support |

---

## 🤖 AI Agent Integration

For projects using AI coding assistants (Claude Code, Cursor, etc.), Magic provides ready-to-use context files:

```
doc/claude/
├── CLAUDE.md                      # Copy to your project's CLAUDE.md
└── skills/magic-usage/SKILL.md    # Detailed usage patterns
```

**Setup:**
1. Copy `doc/claude/CLAUDE.md` to your project root as `CLAUDE.md`
2. Copy `doc/claude/skills/` to your project's `.claude/skills/`

This helps AI agents understand Magic's patterns (Facades, Eloquent, Service Providers) and generate correct code.

---

## 🛠️ CLI Commands

```bash
magic make:model User           # Create Eloquent model
magic make:controller User      # Create controller  
magic make:view Login           # Create view class
magic make:policy Post          # Create authorization policy
magic make:migration create_users_table  # Create migration
magic make:seeder UserSeeder    # Create database seeder
magic make:provider Payment     # Create service provider
magic make:lang tr              # Create language file
```

---

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines before submitting a pull request.

---

## 📄 License

Magic is open-sourced software licensed under the [MIT license](LICENSE).

---

<p align="center">
  <b>Built with ❤️ for Flutter developers who love Laravel</b>
</p>
