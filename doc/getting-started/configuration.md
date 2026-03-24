# Configuration

- [Introduction](#introduction)
- [Environment Configuration](#environment-configuration)
    - [Environment Variable Types](#environment-variable-types)
    - [Determining the Current Environment](#determining-the-current-environment)
- [Accessing Configuration Values](#accessing-configuration-values)
- [Configuration Files](#configuration-files)
- [Theme Persistence](#theme-persistence)
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

<a name="theme-persistence"></a>
## Theme Persistence

MagicApplication automatically persists the user's theme preference (dark or light) to secure storage via the Vault. This allows the application to remember the user's theme choice across restarts.

### How It Works

When the application starts, MagicApplication:

1. Loads the saved theme preference from Vault (stored under the `theme_mode` key)
2. Restores the saved preference (`'dark'` or `'light'`) if available
3. Falls back to the system brightness if no preference was previously saved
4. Gracefully defaults to system theme if `VaultServiceProvider` is not registered

When the user manually toggles the theme, the preference is automatically persisted to Vault. The `onThemeChanged` callback fires during theme toggles, allowing you to add extra side-effects like analytics tracking.

### Example Usage

```dart
void main() async {
  await Magic.init(
    configFactories: [
      appConfig,
      authConfig,
      databaseConfig,
    ],
  );

  runApp(
    MagicApplication(
      themeMode: ThemeMode.system,  // Follows system by default, or restores saved preference
      onThemeChanged: (brightness) {
        // Called when user manually toggles theme
        // Preference is auto-saved to Vault — use this for extra side-effects
        analytics.track('theme_changed', {
          'mode': brightness.name,
        });
      },
      home: const HomePage(),
    ),
  );
}
```

### Storage Details

- **Storage Key**: `theme_mode`
- **Storage Values**: `'dark'` or `'light'`
- **Provider**: Requires `VaultServiceProvider` to be registered in your app config
- **Fallback**: If Vault is unavailable, the application gracefully uses system brightness

> [!NOTE]
> Theme persistence is automatic and requires no additional setup beyond including `VaultServiceProvider` in your application providers. The `onThemeChanged` callback is optional and is useful for tracking theme changes or triggering related UI updates.

> [!WARNING]
> If `VaultServiceProvider` is not registered, theme persistence will not work, and the application will always follow system brightness on startup.

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
