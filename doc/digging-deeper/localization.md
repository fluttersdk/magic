# Localization

Magic provides a Laravel-style localization system that lets you retrieve and switch translation strings at runtime without needing BuildContext.

- [Introduction](#introduction)
- [Configuration](#configuration)
- [Defining Translation Strings](#defining-translation-strings)
- [Retrieving Translations](#retrieving-translations)
    - [The trans() Helper](#the-trans-helper)
    - [Checking Key Existence](#checking-key-existence)
- [Locale State](#locale-state)
    - [Current Locale](#current-locale)
    - [Loaded State](#loaded-state)
    - [Supported Locales](#supported-locales)
- [Changing Locale](#changing-locale)
    - [Setting the Locale](#setting-the-locale)
    - [Auto-Detecting Locale](#auto-detecting-locale)
    - [Setting Supported Locales at Runtime](#setting-supported-locales-at-runtime)
- [Reacting to Locale Changes](#reacting-to-locale-changes)
- [Flutter Integration (Delegate)](#flutter-integration-delegate)
- [Automatic HTTP Headers](#automatic-http-headers)
- [CLI Commands](#cli-commands)
- [Development: Hot Restart](#development-hot-restart)

<a name="introduction"></a>
## Introduction

Magic provides a Laravel-style localization system that allows you to easily retrieve strings in various languages **without needing BuildContext**. This is a game-changer for Flutter developers who are tired of passing context everywhere.

```dart
// Anywhere in your code - no context needed!
Text(trans('welcome', {'name': 'Magic'}))  // "Welcome, Magic!"
Text(trans('auth.failed'))                  // "Authentication failed."
```

<a name="configuration"></a>
## Configuration

### Enabling Localization

Add `LocalizationServiceProvider` to your providers in `config/app.dart`:

```dart
'providers': [
  (app) => LocalizationServiceProvider(app),
  // ... other providers
],
```

### Localization Configuration

Create `lib/config/localization.dart`:

```dart
Map<String, dynamic> get localizationConfig => {
  'localization': {
    'locale': 'en',
    'fallback_locale': 'en',
    'supported_locales': ['en', 'tr', 'es', 'de'],
    'auto_detect_locale': true,
    'path': 'assets/lang',
  },
};
```

### Configuration Options

| Key | Default | Description |
|-----|---------|-------------|
| `locale` | `'en'` | Default locale |
| `fallback_locale` | `'en'` | Fallback when translation is missing |
| `supported_locales` | `['en']` | Supported locale codes |
| `auto_detect_locale` | `false` | Auto-detect from device on boot |
| `path` | `'assets/lang'` | Translation JSON files path |

### Register Assets

Add translation files to your `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/lang/en.json
    - assets/lang/tr.json
    - assets/lang/es.json
```

<a name="defining-translation-strings"></a>
## Defining Translation Strings

Translation strings are stored as JSON files in `assets/lang/`:

```json
{
  "welcome": "Welcome, :name!",
  "auth": {
    "login": "Login",
    "register": "Register",
    "logout": "Logout",
    "failed": "These credentials do not match our records.",
    "throttle": "Too many login attempts. Please try again in :seconds seconds."
  },
  "validation": {
    "required": "The :attribute field is required.",
    "email": "The :attribute must be a valid email address.",
    "min": {
      "string": "The :attribute must be at least :min characters."
    }
  },
  "attributes": {
    "email": "email address",
    "password": "password",
    "password_confirmation": "password confirmation"
  }
}
```

### Nested Keys

Use dot notation to access nested translations:

```dart
trans('auth.failed')           // "These credentials do not match..."
trans('validation.required')   // "The :attribute field is required."
```

<a name="retrieving-translations"></a>
## Retrieving Translations

### Basic Usage

```dart
// Simple translation
WText(trans('auth.login'))

// With parameters
WText(trans('welcome', {'name': user.name}))
// Output: "Welcome, John!"

// Nested keys
WText(trans('auth.throttle', {'seconds': '60'}))
// Output: "Too many login attempts. Please try again in 60 seconds."
```

<a name="the-trans-helper"></a>
### The trans() Helper

The `trans()` function is a globally available helper that delegates to `Lang.get`:

```dart
String trans(String key, [Map<String, dynamic>? replace])
```

- Returns the translation for the current locale
- Falls back to `fallback_locale` if not found
- Returns the key itself if no translation exists
- Replaces `:param` placeholders with provided values

You can also call `Lang.get` directly, which is equivalent:

```dart
final message = Lang.get('welcome', {'name': 'Magic'});
```

<a name="checking-key-existence"></a>
### Checking Key Existence

Use `Lang.has` to check whether a translation key exists for the current locale before retrieving it:

```dart
if (Lang.has('errors.payment_declined')) {
  return trans('errors.payment_declined');
}
```

<a name="locale-state"></a>
## Locale State

<a name="current-locale"></a>
### Current Locale

`Lang.current` returns the active `Locale`:

```dart
final locale = Lang.current; // Locale('tr')
print(locale.languageCode);  // "tr"
```

<a name="loaded-state"></a>
### Loaded State

`Lang.isLoaded` returns `true` once translations have been loaded for the current locale. Use this to guard against calling `trans()` before the localization service has finished booting:

```dart
if (Lang.isLoaded) {
  print(trans('welcome'));
}
```

<a name="supported-locales"></a>
### Supported Locales

`Lang.supportedLocales` returns the list of `Locale` objects your app supports, as configured in `localization.supported_locales`:

```dart
final locales = Lang.supportedLocales;
// [Locale('en'), Locale('tr'), Locale('es')]
```

<a name="changing-locale"></a>
## Changing Locale

<a name="setting-the-locale"></a>
### Setting the Locale

Call `Lang.setLocale` to switch the active locale at runtime. By default it also triggers `Magic.reload()` so all widgets rebuild with the new strings:

```dart
// Change locale and rebuild the app
await Lang.setLocale(Locale('tr'));

// Load translations without triggering app reload
await Lang.setLocale(Locale('tr'), reload: false);
```

### Language Picker Example

```dart
WFormSelect<String>(
  value: Lang.current.languageCode,
  options: [
    SelectOption(value: 'en', label: 'English'),
    SelectOption(value: 'tr', label: 'Türkçe'),
    SelectOption(value: 'es', label: 'Español'),
  ],
  onChange: (code) async {
    await Lang.setLocale(Locale(code!));
    Magic.toast(trans('common.language_changed'));
  },
  label: trans('settings.language'),
)
```

<a name="auto-detecting-locale"></a>
### Auto-Detecting Locale

`Lang.detectLocale` returns the best matching `Locale` from the device or browser without changing the current locale. It compares device preferences against `supported_locales` and returns the closest match:

```dart
final detected = Lang.detectLocale();
print(detected); // e.g., Locale('tr')
```

`Lang.detectAndSetLocale` combines detection and activation in one call. It returns the locale that was set:

```dart
// On app start, pick the user's device language automatically
final locale = await Lang.detectAndSetLocale();
print(locale); // e.g., Locale('tr')
```

You can also use `auto_detect_locale: true` in the localization config to have `LocalizationServiceProvider` call this automatically during boot.

<a name="setting-supported-locales-at-runtime"></a>
### Setting Supported Locales at Runtime

If you need to change the supported locale list after boot (for example, after loading user preferences from the server), use `Lang.setSupportedLocales`:

```dart
Lang.setSupportedLocales([Locale('en'), Locale('fr'), Locale('de')]);
```

<a name="reacting-to-locale-changes"></a>
## Reacting to Locale Changes

The `Translator` underlying `Lang` extends Flutter's `ChangeNotifier`. Use `Lang.addListener` and `Lang.removeListener` to subscribe to locale changes without a `BuildContext`:

```dart
class LocaleAwareService {
  LocaleAwareService() {
    Lang.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() {
    // Re-format any locale-sensitive values
    print('Locale changed to: ${Lang.current}');
  }

  void dispose() {
    Lang.removeListener(_onLocaleChanged);
  }
}
```

Listeners fire after every successful `setLocale` or `detectAndSetLocale` call, so they are a reliable hook for updating any state that depends on the current locale outside the widget tree.

<a name="flutter-integration-delegate"></a>
## Flutter Integration (Delegate)

When you use a plain `MaterialApp` (rather than `MagicApp`), you must pass `Lang.delegate` to `localizationsDelegates` so Flutter's localization lifecycle triggers translation reloads when the device locale changes:

```dart
MaterialApp(
  localizationsDelegates: [
    Lang.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Lang.supportedLocales,
  home: const HomePage(),
)
```

`Lang.delegate` is a `const LocalizationsDelegate<Translator>`. It implements `isSupported` by checking against `localization.supported_locales` from config and delegates `load` to the `Translator` singleton.

> [!NOTE]
> When you use `MagicApp`, the delegate is wired automatically by the framework when `LocalizationServiceProvider` is registered. You only need to add it manually when bypassing `MagicApp`.

<a name="automatic-http-headers"></a>
## Automatic HTTP Headers

When `LocalizationServiceProvider` is registered, Magic automatically attaches two headers to every outgoing HTTP request via `LocalizationInterceptor`. No manual setup is required.

| Header | Value | Example |
|--------|-------|---------|
| `Accept-Language` | Current locale language code | `en`, `tr`, `es` |
| `X-Timezone` | Current IANA timezone identifier | `Europe/Istanbul`, `America/New_York` |

Both values are resolved at request-time, so they always reflect the locale and timezone that are active when the request is dispatched.

```dart
// When the current locale is 'tr' and timezone is 'Europe/Istanbul',
// every Http.get/post/put/delete call automatically includes:
//
//   Accept-Language: tr
//   X-Timezone: Europe/Istanbul
//
// This works transparently, no configuration needed.
final response = await Http.get('/api/profile');
```

> [!NOTE]
> `LocalizationInterceptor` is registered automatically by `LocalizationServiceProvider`. You do not need to add it to your provider list or network configuration manually.

<a name="cli-commands"></a>
## CLI Commands

### Create Translation File

```bash
dart run magic:artisan make:lang fr
dart run magic:artisan make:lang de
dart run magic:artisan make:lang tr
```

This command:
1. Creates `assets/lang/<code>.json` with a starter template
2. Automatically registers the asset in `pubspec.yaml`

### Starter Template

The generated file includes common translation keys:

```json
{
  "welcome": "Welcome, :name!",
  "common": {
    "save": "Save",
    "cancel": "Cancel",
    "delete": "Delete",
    "success": "Success",
    "error": "Error"
  },
  "auth": {
    "login": "Login",
    "register": "Register",
    "logout": "Logout",
    "failed": "Authentication failed.",
    "throttle": "Too many attempts. Please try again in :seconds seconds."
  },
  "validation": {
    "required": "The :attribute field is required.",
    "email": "The :attribute must be a valid email address."
  },
  "attributes": {
    "email": "email",
    "password": "password"
  }
}
```

> [!TIP]
> Keep your translation keys organized by feature (auth, validation, users, etc.) for easier maintenance.

<a name="development-hot-restart"></a>
## Development: Hot Restart

During development, Magic attempts to bypass Flutter's asset bundle cache so that translation JSON changes can be picked up on **hot restart** (`Shift+R`) without a full rebuild.

| Platform | Mechanism | Reliability |
|----------|-----------|-------------|
| Web (Chrome) | Fetches JSON via HTTP with cache-busting query parameter | Verified |
| macOS / Linux / Windows | Reads JSON from disk via `dart:io` | Best-effort (works when `flutter run` sets the working directory to the project root) |
| iOS / Android | Attempts disk read via `dart:io`, falls back to `rootBundle` | Limited (asset files are typically not on disk) |

This behavior is **debug-mode only** (`kDebugMode`). Release builds use Flutter's standard `rootBundle` with full caching for optimal performance.

> [!NOTE]
> Hot **reload** (lowercase `r`) only reloads Dart code — it cannot pick up asset changes. Use hot **restart** (`Shift+R`) to see translation updates.
