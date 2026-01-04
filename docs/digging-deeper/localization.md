# Localization

- [Introduction](#introduction)
- [Configuration](#configuration)
- [Defining Translation Strings](#defining-translation-strings)
- [Retrieving Translations](#retrieving-translations)
- [Pluralization](#pluralization)
- [Changing Locale](#changing-locale)
- [CLI Commands](#cli-commands)

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
// assets/lang/en.json
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

### The trans() Helper

The `trans()` function is globally available:

```dart
String trans(String key, [Map<String, dynamic>? params])
```

- Returns the translation for the current locale
- Falls back to `fallback_locale` if not found
- Returns the key itself if no translation exists
- Replaces `:param` placeholders with provided values

### Using in Controllers

```dart
class AuthController extends MagicController {
  Future<void> login(Map<String, dynamic> data) async {
    final response = await Http.post('/login', data: data);
    
    if (response.successful) {
      Magic.success(trans('common.success'), trans('auth.logged_in'));
    } else {
      Magic.error(trans('common.error'), trans('auth.failed'));
    }
  }
}
```



<a name="changing-locale"></a>
## Changing Locale

### Programmatically

```dart
// Change locale at runtime
await Lang.setLocale(Locale('tr'));

// Get current locale
final currentLocale = Lang.locale;  // Locale('tr')

// Check if locale is supported
if (Lang.isSupported(Locale('fr'))) {
  await Lang.setLocale(Locale('fr'));
}
```

### Language Picker Example

```dart
WFormSelect<String>(
  value: Lang.locale.languageCode,
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

<a name="cli-commands"></a>
## CLI Commands

### Create Translation File

```bash
magic make:lang fr
magic make:lang de
magic make:lang tr
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
