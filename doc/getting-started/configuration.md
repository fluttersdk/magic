# Configuration

- [Introduction](#introduction)
- [Environment Configuration](#environment-configuration)
    - [Environment Variable Types](#environment-variable-types)
    - [Determining the Current Environment](#determining-the-current-environment)
- [Accessing Configuration Values](#accessing-configuration-values)
- [Configuration Files](#configuration-files)
- [CLI Commands](#cli-commands)
- [Configuration Caching](#configuration-caching)

<a name="introduction"></a>
## Introduction

All of the configuration files for Magic are stored in the `lib/config` directory. Each option is documented, so feel free to look through the files and get familiar with the options available to you.

Magic uses a modular configuration system. The framework loads sensible defaults automatically for all services. You only need to create config files for values you wish to override.

These configuration files allow you to configure things like your database connection information, your mail server information, as well as various other core configuration values such as your application URL and encryption key.

<a name="environment-configuration"></a>
## Environment Configuration

It is often helpful to have different configuration values based on the environment the application is running in. For example, you may wish to use a different API endpoint locally than you do on your production server.

Magic uses `.env` files located in your project root. To set up environment-based configuration:

### 1. Create Your Environment File

Create a `.env` file in your project root:

```bash
APP_NAME="My Magic App"
APP_ENV=local
APP_DEBUG=true
APP_URL=http://localhost
APP_KEY=base64:your-generated-key

API_BASE_URL=https://api.example.com
```

### 2. Register as Flutter Asset

Add the `.env` file to your `pubspec.yaml`:

```yaml
flutter:
  assets:
    - .env
```

### 3. Access in Configuration

Use the `env()` helper or `Env.get()` in your configuration files:

```dart
Map<String, dynamic> get appConfig => {
  'app': {
    'name': env('APP_NAME', 'Magic App'),
    'debug': env('APP_DEBUG', false),
    'url': env('APP_URL', 'http://localhost'),
  }
};
```

> [!NOTE]
> Any variable in your `.env` file can be overridden by external environment variables at runtime.

<a name="environment-variable-types"></a>
### Environment Variable Types

All variables in your `.env` files are parsed as strings. The `env()` helper automatically converts common values:

| `.env` Value | Dart Value |
|--------------|------------|
| `true` / `(true)` | `true` (bool) |
| `false` / `(false)` | `false` (bool) |
| `null` / `(null)` | `null` |
| `empty` / `(empty)` | `''` (empty string) |
| Numeric strings | Parsed as `int` or `double` |

<a name="determining-the-current-environment"></a>
### Determining the Current Environment

The current application environment is determined via the `APP_ENV` variable. You may access this value via the `Config` facade:

```dart
final environment = Config.get('app.env');

if (environment == 'local') {
  // Enable debug features
}
```

<a name="accessing-configuration-values"></a>
## Accessing Configuration Values

You may easily access configuration values using the `Config` facade from anywhere in your application. Configuration values may be accessed using "dot" notation, which includes the name of the file and option you wish to access:

```dart
// Get a value with a default fallback
final appName = Config.get('app.name', 'Magic App');

// Get a typed value
final timeout = Config.get<int>('network.timeout', 5000);

// Get a nested configuration
final dbConfig = Config.get('database.connections.sqlite');
```

### Checking If Configuration Exists

```dart
if (Config.has('services.stripe')) {
  initializeStripe();
}
```

### Getting Required Values

If a configuration value is required and must exist, use `getOrFail`:

```dart
final apiKey = Config.getOrFail<String>('services.stripe.secret');
// Throws if not found
```

### Runtime Configuration

You may set configuration values at runtime:

```dart
Config.set('app.locale', 'fr');
Config.set('app.timezone', 'Europe/Istanbul');
```

> [!WARNING]
> Runtime configuration values are ephemeral and will not persist across application restarts.

### Merging Configuration

You can deep-merge additional configuration at runtime:

```dart
Config.merge({
  'database': {
    'host': 'production.db.example.com',
    'port': 5432,
  }
});
```

<a name="configuration-files"></a>
## Configuration Files

Magic recommends organizing your configuration into logical files:

| File | Purpose | Config Key |
|------|---------|------------|
| `app.dart` | General settings, service providers | `app` |
| `auth.dart` | Authentication guards and behavior | `auth` |
| `database.dart` | Database connections and drivers | `database` |
| `network.dart` | API endpoints, timeouts, headers | `network` |
| `cache.dart` | Cache stores and TTL settings | `cache` |
| `logging.dart` | Log levels and channels | `logging` |
| `localization.dart` | Supported locales and defaults | `localization` |

### Example: app.dart

```dart
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

Map<String, dynamic> get appConfig => {
  'app': {
    'name': env('APP_NAME', 'My App'),
    'env': env('APP_ENV', 'production'),
    'debug': env('APP_DEBUG', false),
    'url': env('APP_URL', 'http://localhost'),
    'key': env('APP_KEY'),
    'providers': [
      (app) => CacheServiceProvider(app),
      (app) => RouteServiceProvider(app),
      (app) => NetworkServiceProvider(app),
      (app) => AuthServiceProvider(app),
    ],
  },
};
```

### Example: network.dart

```dart
Map<String, dynamic> get networkConfig => {
  'network': {
    'default': 'api',
    'drivers': {
      'api': {
        'base_url': env('API_BASE_URL', 'http://localhost:8000/api/v1'),
        'timeout': 10000,
        'headers': {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      },
    },
  },
};
```

<a name="cli-commands"></a>
## CLI Commands

Magic CLI provides commands for inspecting your application's configuration:

### Listing Configuration Files

```bash
magic config:list
```

This displays all configuration files and their keys:

```
+------------------+---------------------------+
| File             | Keys                      |
+------------------+---------------------------+
| app.dart         | app.name, app.debug, ...  |
| network.dart     | network.default, ...      |
+------------------+---------------------------+
```

### Getting Specific Values

```bash
magic config:get app.name
# Output: My App

magic config:get network.drivers.api.base_url
# Output: http://localhost:8000/api/v1

# Show source of the value
magic config:get app.name --show-source
# Output: My App (from: lib/config/app.dart)
```

<a name="configuration-caching"></a>
## Configuration Caching

Configuration is loaded during `Magic.init()` and cached in memory for the duration of the application lifecycle. To update configuration:

1. Modify your config files
2. Use `Magic.restart()` for a soft restart, or
3. Hot reload/restart your application

```dart
// Soft restart (applies config changes without killing VM)
Magic.reload();
```

> [!TIP]
> For production apps, consider using `Config.getOrFail()` for critical values to catch missing configuration early during startup.
