# Installation

## Requirements

Magic is designed to work with Flutter 3.22.0 or higher and Dart SDK 3.4.0 or higher.

## Installing Via Magic CLI (Recommended)

The easiest way to set up Magic is using the Magic CLI. First, activate it globally:

```bash
dart pub global activate fluttersdk_magic_cli
```

Then navigate to your Flutter project and run:

```bash
cd my_app
magic init
```

This command will install **all Magic features** by default:
- Add the `fluttersdk_magic` dependency
- Create the required directory structure
- Set up all configuration files
- Configure all service providers (database, cache, auth, events, localization)
- Generate an application key

### Excluding Features

If you don't need certain features, use `--without-*` flags to exclude them:

```bash
# Exclude specific features
magic init --without-database      # Skip database support
magic init --without-cache         # Skip caching
magic init --without-auth          # Skip authentication
magic init --without-events        # Skip event system
magic init --without-localization  # Skip localization/i18n

# Combine multiple exclusions
magic init --without-database --without-events
```

## Wind UI Plugin

Magic includes the **Flutter Wind** plugin (`fluttersdk_wind`), which allows you to build UIs using Tailwind CSS-like utility classes:

```dart
WDiv(
  className: "flex flex-col p-4 bg-white shadow-lg rounded-xl",
  children: [
    WText("Hello World", className: "text-xl font-bold text-blue-500"),
  ],
)
```

See the [Wind Documentation](/plugins/fluttersdk_wind/docs) for complete widget reference.

---

## Manual Installation

If you prefer manual setup, follow these steps:

### 1. Add Dependency

```yaml
# pubspec.yaml
dependencies:
  fluttersdk_magic:
    git:
      url: https://github.com/fluttersdk/magic.git
```

```bash
flutter pub get
```

### 2. Create Configuration

Create `lib/config/app.dart`:

```dart
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

In your `main.dart`:

```dart
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

## Directory Structure

A typical Magic application follows this structure:

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
