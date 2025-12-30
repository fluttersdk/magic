# Carbon - Date & Time

## Introduction

Magic Carbon provides Laravel-style date manipulation with automatic timezone detection.

```dart
final now = Carbon.now();
final parsed = Carbon.parse('2024-01-15');

now.addDays(5).startOfMonth();
now.diffForHumans();  // "2 hours ago"
```

## Configuration

```dart
'localization': {
  'timezone': 'Europe/Istanbul',
  'auto_detect_timezone': true,
  'date_format': 'dd MMMM yyyy',
  'locale': 'en',
}
```

## Constructors

```dart
Carbon.now();                    // Current date/time
Carbon.now('America/New_York');  // In specific timezone
Carbon.parse('2024-01-15');      // From string
Carbon.fromDateTime(DateTime.now());
Carbon.create(year: 2024, month: 1, day: 15);
```

## Manipulation

All methods return a new Carbon instance (immutable):

```dart
now.addDay();           // +1 day
now.addDays(5);         // +5 days
now.subDays(3);         // -3 days
now.addMonth();         // +1 month
now.addMonths(6);       // +6 months
now.addYear();          // +1 year
now.addHours(2);        // +2 hours
now.addMinutes(30);     // +30 minutes
```

## Modifiers

```dart
now.startOfDay();   // 00:00:00
now.endOfDay();     // 23:59:59
now.startOfWeek();
now.endOfWeek();
now.startOfMonth();
now.endOfMonth();
```

## Formatting

```dart
now.format('yyyy-MM-dd');         // "2024-01-15"
now.format('MMMM dd, yyyy');      // "January 15, 2024"
now.toDateString();               // "2024-01-15"
now.toTimeString();               // "14:30:00"
now.toIso8601String();            // ISO format
now.toFormattedDateString();      // Uses config date_format
```

## Diff

```dart
now.diffForHumans();              // "2 hours ago"
now.diffInDays(other);
now.diffInHours(other);
now.diffInMinutes(other);
now.diffInMonths(other);
now.diffInYears(other);
```

## Comparison

```dart
now.isAfter(other);
now.isBefore(other);
now.isSame(other);
now.isBetween(start, end);

now.isToday();
now.isYesterday();
now.isTomorrow();
now.isFuture();
now.isPast();
now.isWeekend();
```

## Timezone

```dart
final ny = now.setTimezone('America/New_York');

// Get available timezones
final timezones = DateManager.instance.getAvailableTimezones();
```

## Locale Sync

```dart
await Lang.setLocale(Locale('tr'));
Carbon.now().diffForHumans();  // "2 saat önce" (Turkish)
```
