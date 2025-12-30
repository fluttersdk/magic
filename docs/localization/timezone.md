# Timezone & Dates

## Introduction

Magic's localization system includes timezone and date configuration that integrates with Carbon for consistent date/time handling across your application.

## Configuration

Add timezone settings to `config/localization.dart`:

```dart
final localizationConfig = {
  'localization': {
    // Timezone
    'timezone': 'UTC',
    'auto_detect_timezone': true,
    
    // Date formatting
    'date_format': 'MMMM do yyyy',
  },
};
```

| Key | Default | Description |
|-----|---------|-------------|
| `timezone` | `'UTC'` | Default IANA timezone |
| `auto_detect_timezone` | `false` | Auto-detect from device on boot |
| `date_format` | `'MMMM do yyyy'` | Default date format for Carbon |

## Automatic Detection

When `auto_detect_timezone: true`, the system automatically detects the device timezone on boot.

## Manual Detection

```dart
// Detect and set
DateManager.instance.detectAndSetTimezone();

// Detect without setting
final tz = DateManager.instance.detectTimezone();  // "Europe/Istanbul"

// Get current timezone
DateManager.instance.timezoneName;  // "Europe/Istanbul"

// Set manually
DateManager.instance.setTimezone('America/New_York');
```

## Available Timezones

The system includes the full IANA timezone database (429 timezones):

```dart
final timezones = DateManager.instance.getAvailableTimezones();
print(timezones.length);  // 429
// ["Africa/Abidjan", "Africa/Accra", ..., "US/Pacific"]
```

## Carbon Integration

Carbon uses the configured timezone automatically:

```dart
// Create with current timezone
Carbon.now();

// Create with specific timezone
Carbon.now('America/New_York');

// Convert between timezones
final ny = Carbon.now().setTimezone('America/New_York');
```

## Locale-Aware Formatting

Date output respects the current locale:

```dart
await Lang.setLocale(Locale('tr'));
Carbon.now().diffForHumans();  // "2 dakika önce"
Carbon.now().format('MMMM dd');  // "Ocak 15"

await Lang.setLocale(Locale('en'));
Carbon.now().diffForHumans();  // "2 minutes ago"
Carbon.now().format('MMMM dd');  // "January 15"
```

See the [Carbon documentation](../digging-deeper/carbon.md) for full date/time manipulation.
