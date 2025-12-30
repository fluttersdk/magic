# Configuration

## Introduction

All of the configuration files for Magic are stored in the `lib/config` directory. Each option is documented, so feel free to look through the files and get familiar with the options available to you.

Magic uses a modular configuration system. The framework loads sensible defaults automatically for all services (Auth, Database, Logging, etc.). You only need to create config files for values you wish to override.

## Configuration Files

You may organize your configuration files as you wish. Here is the recommended structure:

| File | Purpose | Key |
|------|---------|-----|
| `app.dart` | General settings, registering Service Providers | `app` |
| `auth.dart` | Authentication guards, providers, and behavior | `auth` |
| `database.dart` | Database connections and drivers | `database` |
| `logging.dart` | Log levels and channels | `logging` |
| `network.dart` | API endpoints, base URLs, timeouts | `network` |
| `cache.dart` | Cache stores and TTL | `cache` |

## Environment Configuration

It is often helpful to have different configuration values based on the environment the application is running in. For example, you may want to use a different API endpoint locally than you do on your production server.

Magic uses `.env` files located in your project root. To create one:

1. Create a `.env` file in your project root:

```bash
APP_NAME="Magic App"
APP_ENV=local
APP_DEBUG=true
APP_URL=http://localhost

API_BASE_URL=https://api.example.com
```

2. Register the file in your `pubspec.yaml`:

```yaml
flutter:
  assets:
    - .env
```

3. Access the values in your configuration files:

```dart
final appConfig = {
  'app': {
    'name': Env.get('APP_NAME', 'Default Name'),
    'debug': Env.get('APP_DEBUG', false),
  }
};
```

> **Note**  
> Any variable in your `.env` file can be overridden by external environment variables at runtime.

## Accessing Configuration Values

You may easily access your configuration values using the `Config` facade from anywhere in your application. Configuration values may be accessed using "dot" syntax, which includes the name of the file and option you wish to access:

```dart
// Get a value with a default fallback
final appName = Config.get('app.name', 'Magic App');

// Get a nested configuration map
final dbConfig = Config.get('database.connections.sqlite');

// Check if a configuration value exists
if (Config.has('app.custom_key')) {
  // ...
}
```

### Runtime Configuration

You may set configuration values at runtime using the `set` method:

```dart
Config.set('app.locale', 'fr');
```

> **Warning**  
> Runtime configuration values are ephemeral and will not persist across application restarts.

## Overriding Default Configuration

To override Magic's default configuration, define your config map and pass it to `Magic.init()`. The framework will deep-merge your values with the defaults:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Magic.init(
    configFactories: [
      () => appConfig,
      () => databaseConfig,
      () => authConfig,
    ],
  );

  runApp(MagicApplication(...));
}
```

## MagicApplication Widget

The `MagicApplication` widget is the recommended way to bootstrap your app. It handles environment loading, router setup, theme integration, and localization automatically.

```dart
runApp(
  MagicApplication(
    title: 'My App',
    themeMode: ThemeMode.system,
    initialRoute: '/',
    debugShowCheckedModeBanner: false,
    onInit: () {
      // Register routes, custom config, etc.
    },
  ),
);
```

### Available Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `title` | String | `'Magic App'` | App title |
| `windTheme` | WindThemeData? | null | Custom Wind theme |
| `themeMode` | ThemeMode | `.system` | Light/dark/system |
| `initialRoute` | String | `'/'` | Starting route |
| `locale` | Locale? | from config | Override locale |
| `debugShowCheckedModeBanner` | bool | `false` | Debug banner |
| `onInit` | Function? | null | Initialization callback |

## Wind Theme Integration

Magic automatically integrates with the Wind UI plugin. Pass a custom `WindThemeData` to customize colors, fonts, and spacing:

```dart
MagicApplication(
  windTheme: WindThemeData(
    colors: {
      'primary': MaterialColor(0xFF3B82F6, {...}),
      'secondary': MaterialColor(0xFF10B981, {...}),
    },
    fontFamily: 'Inter',
  ),
)
```

The Material theme is automatically derived from your Wind theme via `controller.toThemeData()`.

## Soft App Restart

Magic supports soft app restarts without killing the process. This is useful for applying theme changes, locale switches, or resetting app state:

```dart
// Restart the app (rebuilds entire widget tree)
Magic.restart();
```

This triggers a rebuild of the entire app while keeping the Dart VM running—faster than a full restart.

