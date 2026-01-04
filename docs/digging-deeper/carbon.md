# Carbon (Date/Time)

- [Introduction](#introduction)
- [Creating Carbon Instances](#creating-carbon-instances)
- [Formatting](#formatting)
- [Manipulation](#manipulation)
- [Comparison](#comparison)
- [Human Readable](#human-readable)
- [Model Integration](#model-integration)

<a name="introduction"></a>
## Introduction

Magic includes Carbon, a powerful date/time utility inspired by PHP's Carbon library. Carbon provides an expressive, fluent API for creating, formatting, and manipulating dates and times.

```dart
// Create, manipulate, and format dates fluently
Carbon.now().addDays(5).format('MMMM d, yyyy');  // "January 20, 2024"

// Human-readable differences
carbon.diffForHumans();  // "2 days ago"
```

<a name="creating-carbon-instances"></a>
## Creating Carbon Instances

```dart
// Current date/time
final now = Carbon.now();

// Parse from string
final date = Carbon.parse('2024-01-15');
final datetime = Carbon.parse('2024-01-15 14:30:00');
final iso = Carbon.parse('2024-01-15T14:30:00Z');

// From DateTime
final fromDart = Carbon.fromDateTime(DateTime.now());

// Specific dates
final today = Carbon.today();       // Today at 00:00:00
final tomorrow = Carbon.tomorrow();
final yesterday = Carbon.yesterday();
```

<a name="formatting"></a>
## Formatting

```dart
final date = Carbon.now();

// Standard formats
date.format('yyyy-MM-dd');           // "2024-01-15"
date.format('dd/MM/yyyy');           // "15/01/2024"
date.format('MMMM d, yyyy');         // "January 15, 2024"
date.format('EEEE');                 // "Monday"
date.format('h:mm a');               // "2:30 PM"

// ISO 8601
date.toIso8601String();              // "2024-01-15T14:30:00.000Z"

// Convenience methods
date.toDateString();                 // "2024-01-15"
date.toTimeString();                 // "14:30:00"
date.toDateTimeString();             // "2024-01-15 14:30:00"
```

### Format Tokens

| Token | Output | Description |
|-------|--------|-------------|
| `yyyy` | 2024 | 4-digit year |
| `yy` | 24 | 2-digit year |
| `MMMM` | January | Full month name |
| `MMM` | Jan | Abbreviated month |
| `MM` | 01 | 2-digit month |
| `dd` | 15 | 2-digit day |
| `d` | 15 | Day of month |
| `EEEE` | Monday | Full weekday name |
| `EEE` | Mon | Abbreviated weekday |
| `HH` | 14 | 24-hour hour |
| `hh` | 02 | 12-hour hour |
| `mm` | 30 | Minutes |
| `ss` | 00 | Seconds |
| `a` | PM | AM/PM |

<a name="manipulation"></a>
## Manipulation

### Adding Time

```dart
final date = Carbon.now();

date.addSeconds(30);
date.addMinutes(15);
date.addHours(2);
date.addDays(5);
date.addWeeks(2);
date.addMonths(3);
date.addYears(1);
```

### Subtracting Time

```dart
date.subSeconds(30);
date.subMinutes(15);
date.subHours(2);
date.subDays(5);
date.subWeeks(2);
date.subMonths(3);
date.subYears(1);
```

### Start/End of Period

```dart
date.startOfDay();     // 00:00:00
date.endOfDay();       // 23:59:59
date.startOfWeek();    // Monday 00:00:00
date.endOfWeek();      // Sunday 23:59:59
date.startOfMonth();   // First day 00:00:00
date.endOfMonth();     // Last day 23:59:59
```

<a name="comparison"></a>
## Comparison

```dart
final date1 = Carbon.parse('2024-01-15');
final date2 = Carbon.parse('2024-01-20');

// Boolean comparisons
date1.isBefore(date2);    // true
date1.isAfter(date2);     // false
date1.isSame(date2);      // false

// Special checks
date.isToday();
date.isTomorrow();
date.isYesterday();
date.isWeekend();
date.isWeekday();
date.isFuture();
date.isPast();

// Between check
date.isBetween(startDate, endDate);
```

### Difference

```dart
final start = Carbon.parse('2024-01-15');
final end = Carbon.parse('2024-01-20');

start.diff(end).inDays;      // 5
start.diff(end).inHours;     // 120
start.diff(end).inMinutes;   // 7200
```

<a name="human-readable"></a>
## Human Readable

The `diffForHumans()` method returns a human-readable string:

```dart
Carbon.now().subMinutes(5).diffForHumans();   // "5 minutes ago"
Carbon.now().subHours(2).diffForHumans();     // "2 hours ago"
Carbon.now().subDays(1).diffForHumans();      // "1 day ago"
Carbon.now().subMonths(3).diffForHumans();    // "3 months ago"

// Future dates
Carbon.now().addDays(3).diffForHumans();      // "in 3 days"
Carbon.now().addHours(1).diffForHumans();     // "in 1 hour"
```

### Relative To Another Date

```dart
final date1 = Carbon.parse('2024-01-15');
final date2 = Carbon.parse('2024-01-20');

date1.diffForHumans(date2);  // "5 days before"
date2.diffForHumans(date1);  // "5 days after"
```

<a name="model-integration"></a>
## Model Integration

Carbon integrates seamlessly with Eloquent models through attribute casting:

```dart
class Post extends Model with HasTimestamps {
  @override
  Map<String, String> get casts => {
    'published_at': 'datetime',
    'expires_at': 'datetime',
  };

  // Typed getter
  Carbon? get publishedAt => getAttribute('published_at') as Carbon?;
  Carbon? get expiresAt => getAttribute('expires_at') as Carbon?;
}
```

### Using in Views

```dart
// Display formatted date
WText(post.publishedAt?.format('MMMM d, yyyy') ?? 'Draft')

// Human-readable
WText(post.publishedAt?.diffForHumans() ?? '')  // "2 days ago"

// Conditional display
if (post.expiresAt?.isFuture() == true) {
  WText('Expires ${post.expiresAt!.diffForHumans()}');
}
```

### HasTimestamps Mixin

Models using `HasTimestamps` automatically get `createdAt` and `updatedAt` as Carbon instances:

```dart
class User extends Model with HasTimestamps {
  // Automatically available:
  // Carbon? get createdAt
  // Carbon? get updatedAt
}

// Usage
WText('Member since ${user.createdAt?.format('MMM yyyy')}');
```

> [!TIP]
> Use `diffForHumans()` in your UI for relative timestamps that are easier for users to understand.
