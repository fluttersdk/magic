# Localization

## Introduction

Magic provides a Laravel-style localization system that allows you to easily retrieve strings in various languages without needing `BuildContext`. The system combines Flutter's native `LocalizationsDelegate` with a context-free `Lang` facade for maximum flexibility.

```dart
// Anywhere in your code - no context needed!
Text(trans('welcome', {'name': 'Magic'}))  // "Welcome, Magic!"
Text(trans('auth.failed'))                  // "Authentication failed."
```

## Enabling Localization

By default, the localization service provider is **not enabled**. You can enable it using the Magic CLI:

```bash
magic init:localization
```

This command will:
- Create `config/localization.dart` with default settings
- Add `LocalizationServiceProvider` to your providers
- Create the `assets/lang/` directory with a default `en.json`

### Manual Setup

Alternatively, add the provider manually to your `config/app.dart`:

```dart
'providers': [
  (app) => LocalizationServiceProvider(app),
],
```

---

## Setup

### Create Translation Files

Create JSON files in `assets/lang/`:

```json
// assets/lang/en.json
{
  "welcome": "Welcome, :name!",
  "auth": {
    "failed": "Authentication failed.",
    "throttle": "Too many attempts. Try again in :seconds seconds."
  }
}
```

### Register Assets

Add to your `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/lang/
    # Or list files explicitly (recommended for Web):
    # - assets/lang/en.json
    # - assets/lang/tr.json
```

### Configure Localization

Create `config/localization.dart`:

```dart
final localizationConfig = {
  'localization': {
    'locale': 'en',
    'fallback_locale': 'en',
    'supported_locales': ['en', 'tr'],
    'auto_detect_locale': true,
    'path': 'assets/lang',
  },
};
```

## Configuration Options

| Key | Default | Description |
|-----|---------|-------------|
| `locale` | `'en'` | Default locale |
| `fallback_locale` | `'en'` | Fallback when translation is missing |
| `supported_locales` | `['en']` | Supported locale codes |
| `auto_detect_locale` | `false` | Auto-detect from device on boot |
| `path` | `'assets/lang'` | Translation JSON files path |

## CLI Commands

### Create Translation File

```bash
magic make:lang fr
```

This command will:
1. Create `assets/lang/fr.json` with a starter template
2. Automatically register the asset in `pubspec.yaml`

**Output:**
```
Created translation file: assets/lang/fr.json
Registered asset in pubspec.yaml
```

### Starter Template

The generated file includes common translation keys:

```json
{
  "welcome": "Welcome, :name!",
  "auth": {
    "failed": "Authentication failed.",
    "throttle": "Too many attempts. Please try again in :seconds seconds."
  },
  "validation": {
    "required": "The :attribute field is required.",
    "email": "The :attribute must be a valid email address."
  }
}
```
