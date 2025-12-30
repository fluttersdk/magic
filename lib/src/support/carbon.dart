import 'package:jiffy/jiffy.dart';
import 'package:timezone/timezone.dart' as tz;

import 'date_manager.dart';

/// The Carbon Class - Laravel-Style Date Wrapper.
///
/// Provides a fluent, expressive API for date manipulation without exposing
/// the underlying Jiffy engine to developers.
///
/// ## Usage
///
/// ```dart
/// // Create instances
/// final now = Carbon.now();
/// final parsed = Carbon.parse('2024-01-15');
/// final fromDt = Carbon.fromDateTime(DateTime.now());
///
/// // Manipulation (returns new instance)
/// final tomorrow = now.addDay();
/// final nextMonth = now.addMonths(1);
/// final startOfMonth = now.startOfMonth();
///
/// // Formatting
/// now.format('yyyy-MM-dd');  // "2024-01-15"
/// now.diffForHumans();       // "2 hours ago"
///
/// // Comparison
/// now.isToday();    // true
/// now.isFuture();   // false
/// ```
class Carbon implements Comparable<Carbon> {
  // ---------------------------------------------------------------------------
  // Internal Engine
  // ---------------------------------------------------------------------------

  /// The hidden Jiffy engine.
  final Jiffy _engine;

  /// Private constructor.
  Carbon._(this._engine);

  // ---------------------------------------------------------------------------
  // Constructors
  // ---------------------------------------------------------------------------

  /// Create a Carbon instance for the current date/time.
  ///
  /// ```dart
  /// final now = Carbon.now();
  /// final inNY = Carbon.now('America/New_York');
  /// ```
  factory Carbon.now([String? timezone]) {
    var jiffy = Jiffy.now();
    if (timezone != null) {
      try {
        final location = tz.getLocation(timezone);
        final tzDateTime = tz.TZDateTime.from(jiffy.dateTime, location);
        jiffy = Jiffy.parseFromDateTime(tzDateTime);
      } catch (_) {
        // Use default if timezone is invalid
      }
    }
    return Carbon._(jiffy);
  }

  /// Parse a date string into a Carbon instance.
  ///
  /// ```dart
  /// Carbon.parse('2024-01-15');
  /// Carbon.parse('January 15, 2024');
  /// Carbon.parse('2024-01-15 14:30:00');
  /// ```
  factory Carbon.parse(String date) {
    return Carbon._(Jiffy.parse(date));
  }

  /// Create a Carbon instance from a DateTime.
  ///
  /// ```dart
  /// Carbon.fromDateTime(DateTime.now());
  /// ```
  factory Carbon.fromDateTime(DateTime dateTime) {
    return Carbon._(Jiffy.parseFromDateTime(dateTime));
  }

  /// Create a Carbon instance from specific date/time parts.
  ///
  /// ```dart
  /// Carbon.create(year: 2024, month: 1, day: 15);
  /// Carbon.create(year: 2024, month: 1, day: 15, hour: 14, minute: 30);
  /// ```
  factory Carbon.create({
    int year = 1970,
    int month = 1,
    int day = 1,
    int hour = 0,
    int minute = 0,
    int second = 0,
    int millisecond = 0,
  }) {
    final dateTime =
        DateTime(year, month, day, hour, minute, second, millisecond);
    return Carbon.fromDateTime(dateTime);
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  /// Get the year.
  int get year => _engine.year;

  /// Get the month (1-12).
  int get month => _engine.month;

  /// Get the day of month.
  int get day => _engine.date;

  /// Get the hour (0-23).
  int get hour => _engine.hour;

  /// Get the minute (0-59).
  int get minute => _engine.minute;

  /// Get the second (0-59).
  int get second => _engine.second;

  /// Get the millisecond.
  int get millisecond => _engine.millisecond;

  /// Get the day of week (1 = Monday, 7 = Sunday).
  int get dayOfWeek => _engine.dayOfWeek;

  /// Get the day of year (1-366).
  int get dayOfYear => _engine.dayOfYear;

  /// Get the week of year.
  int get weekOfYear => _engine.weekOfYear;

  /// Get the number of days in the current month.
  int get daysInMonth => _engine.daysInMonth;

  /// Get the quarter (1-4).
  int get quarter => _engine.quarter;

  /// Get the underlying DateTime.
  DateTime get toDateTime => _engine.dateTime;

  /// Get the timezone name.
  String get timeZoneName => _engine.dateTime.timeZoneName;

  /// Get milliseconds since epoch.
  int get millisecondsSinceEpoch => _engine.microsecondsSinceEpoch ~/ 1000;

  /// Get microseconds since epoch.
  int get microsecondsSinceEpoch => _engine.microsecondsSinceEpoch;

  // ---------------------------------------------------------------------------
  // Manipulation - Days
  // ---------------------------------------------------------------------------

  /// Add a duration.
  Carbon add(Duration duration) {
    return Carbon.fromDateTime(_engine.dateTime.add(duration));
  }

  /// Subtract a duration.
  Carbon subtract(Duration duration) {
    return Carbon.fromDateTime(_engine.dateTime.subtract(duration));
  }

  /// Add one day.
  Carbon addDay() => addDays(1);

  /// Add days.
  Carbon addDays(int value) {
    return Carbon._(_engine.add(days: value));
  }

  /// Subtract one day.
  Carbon subDay() => subDays(1);

  /// Subtract days.
  Carbon subDays(int value) {
    return Carbon._(_engine.subtract(days: value));
  }

  // ---------------------------------------------------------------------------
  // Manipulation - Weeks
  // ---------------------------------------------------------------------------

  /// Add one week.
  Carbon addWeek() => addWeeks(1);

  /// Add weeks.
  Carbon addWeeks(int value) {
    return Carbon._(_engine.add(weeks: value));
  }

  /// Subtract one week.
  Carbon subWeek() => subWeeks(1);

  /// Subtract weeks.
  Carbon subWeeks(int value) {
    return Carbon._(_engine.subtract(weeks: value));
  }

  // ---------------------------------------------------------------------------
  // Manipulation - Months
  // ---------------------------------------------------------------------------

  /// Add one month.
  Carbon addMonth() => addMonths(1);

  /// Add months.
  Carbon addMonths(int value) {
    return Carbon._(_engine.add(months: value));
  }

  /// Subtract one month.
  Carbon subMonth() => subMonths(1);

  /// Subtract months.
  Carbon subMonths(int value) {
    return Carbon._(_engine.subtract(months: value));
  }

  // ---------------------------------------------------------------------------
  // Manipulation - Years
  // ---------------------------------------------------------------------------

  /// Add one year.
  Carbon addYear() => addYears(1);

  /// Add years.
  Carbon addYears(int value) {
    return Carbon._(_engine.add(years: value));
  }

  /// Subtract one year.
  Carbon subYear() => subYears(1);

  /// Subtract years.
  Carbon subYears(int value) {
    return Carbon._(_engine.subtract(years: value));
  }

  // ---------------------------------------------------------------------------
  // Manipulation - Hours/Minutes/Seconds
  // ---------------------------------------------------------------------------

  /// Add hours.
  Carbon addHours(int value) {
    return Carbon._(_engine.add(hours: value));
  }

  /// Subtract hours.
  Carbon subHours(int value) {
    return Carbon._(_engine.subtract(hours: value));
  }

  /// Add minutes.
  Carbon addMinutes(int value) {
    return Carbon._(_engine.add(minutes: value));
  }

  /// Subtract minutes.
  Carbon subMinutes(int value) {
    return Carbon._(_engine.subtract(minutes: value));
  }

  /// Add seconds.
  Carbon addSeconds(int value) {
    return Carbon._(_engine.add(seconds: value));
  }

  /// Subtract seconds.
  Carbon subSeconds(int value) {
    return Carbon._(_engine.subtract(seconds: value));
  }

  // ---------------------------------------------------------------------------
  // Modifiers
  // ---------------------------------------------------------------------------

  /// Get start of day (00:00:00).
  Carbon startOfDay() {
    return Carbon._(_engine.startOf(Unit.day));
  }

  /// Get end of day (23:59:59.999).
  Carbon endOfDay() {
    return Carbon._(_engine.endOf(Unit.day));
  }

  /// Get start of week.
  Carbon startOfWeek() {
    return Carbon._(_engine.startOf(Unit.week));
  }

  /// Get end of week.
  Carbon endOfWeek() {
    return Carbon._(_engine.endOf(Unit.week));
  }

  /// Get start of month.
  Carbon startOfMonth() {
    return Carbon._(_engine.startOf(Unit.month));
  }

  /// Get end of month.
  Carbon endOfMonth() {
    return Carbon._(_engine.endOf(Unit.month));
  }

  /// Get start of year.
  Carbon startOfYear() {
    return Carbon._(_engine.startOf(Unit.year));
  }

  /// Get end of year.
  Carbon endOfYear() {
    return Carbon._(_engine.endOf(Unit.year));
  }

  // ---------------------------------------------------------------------------
  // Timezone
  // ---------------------------------------------------------------------------

  /// Convert to a different timezone.
  ///
  /// ```dart
  /// final utc = Carbon.now();
  /// final ny = utc.setTimezone('America/New_York');
  /// ```
  Carbon setTimezone(String timezone) {
    try {
      final location = tz.getLocation(timezone);
      final tzDateTime = tz.TZDateTime.from(_engine.dateTime, location);
      return Carbon.fromDateTime(tzDateTime);
    } catch (_) {
      return this;
    }
  }

  // ---------------------------------------------------------------------------
  // Formatting
  // ---------------------------------------------------------------------------

  /// Format the date with a custom pattern.
  ///
  /// ```dart
  /// carbon.format('yyyy-MM-dd');        // "2024-01-15"
  /// carbon.format('MMMM dd, yyyy');     // "January 15, 2024"
  /// carbon.format('HH:mm:ss');          // "14:30:00"
  /// ```
  String format(String pattern) {
    return _engine.format(pattern: pattern);
  }

  /// Get ISO 8601 string.
  String toIso8601String() {
    return _engine.dateTime.toIso8601String();
  }

  /// Get date string (yyyy-MM-dd).
  String toDateString() {
    return format('yyyy-MM-dd');
  }

  /// Get time string (HH:mm:ss).
  String toTimeString() {
    return format('HH:mm:ss');
  }

  /// Get date time string (yyyy-MM-dd HH:mm:ss).
  String toDateTimeString() {
    return format('yyyy-MM-dd HH:mm:ss');
  }

  /// Get formatted date using config pattern.
  String toFormattedDateString() {
    return format(DateManager.instance.dateFormat);
  }

  // ---------------------------------------------------------------------------
  // Diff
  // ---------------------------------------------------------------------------

  /// Get human-readable difference (e.g., "2 hours ago").
  ///
  /// ```dart
  /// created.diffForHumans();  // "3 days ago"
  /// ```
  String diffForHumans([Carbon? other]) {
    if (other != null) {
      return _engine.from(other._engine);
    }
    return _engine.fromNow();
  }

  /// Get difference in days.
  int diffInDays(Carbon other) {
    return _engine.diff(other._engine, unit: Unit.day).toInt();
  }

  /// Get difference in hours.
  int diffInHours(Carbon other) {
    return _engine.diff(other._engine, unit: Unit.hour).toInt();
  }

  /// Get difference in minutes.
  int diffInMinutes(Carbon other) {
    return _engine.diff(other._engine, unit: Unit.minute).toInt();
  }

  /// Get difference in seconds.
  int diffInSeconds(Carbon other) {
    return _engine.diff(other._engine, unit: Unit.second).toInt();
  }

  /// Get difference in months.
  int diffInMonths(Carbon other) {
    return _engine.diff(other._engine, unit: Unit.month).toInt();
  }

  /// Get difference in years.
  int diffInYears(Carbon other) {
    return _engine.diff(other._engine, unit: Unit.year).toInt();
  }

  // ---------------------------------------------------------------------------
  // Comparison
  // ---------------------------------------------------------------------------

  /// Check if this date is after another.
  bool isAfter(Carbon other) {
    return _engine.isAfter(other._engine);
  }

  /// Check if this date is before another.
  bool isBefore(Carbon other) {
    return _engine.isBefore(other._engine);
  }

  /// Check if this date is the same as another.
  bool isSame(Carbon other, [Unit unit = Unit.day]) {
    return _engine.isSame(other._engine, unit: unit);
  }

  /// Check if this date is the same or after another.
  bool isSameOrAfter(Carbon other, [Unit unit = Unit.day]) {
    return _engine.isSameOrAfter(other._engine, unit: unit);
  }

  /// Check if this date is the same or before another.
  bool isSameOrBefore(Carbon other, [Unit unit = Unit.day]) {
    return _engine.isSameOrBefore(other._engine, unit: unit);
  }

  /// Check if this date is between two others.
  bool isBetween(Carbon start, Carbon end, [Unit unit = Unit.day]) {
    return _engine.isBetween(start._engine, end._engine, unit: unit);
  }

  /// Check if this is today.
  bool isToday() {
    final now = Jiffy.now();
    return _engine.isSame(now, unit: Unit.day);
  }

  /// Check if this is yesterday.
  bool isYesterday() {
    final yesterday = Jiffy.now().subtract(days: 1);
    return _engine.isSame(yesterday, unit: Unit.day);
  }

  /// Check if this is tomorrow.
  bool isTomorrow() {
    final tomorrow = Jiffy.now().add(days: 1);
    return _engine.isSame(tomorrow, unit: Unit.day);
  }

  /// Check if this date is in the future.
  bool isFuture() {
    return _engine.isAfter(Jiffy.now());
  }

  /// Check if this date is in the past.
  bool isPast() {
    return _engine.isBefore(Jiffy.now());
  }

  /// Check if this is a weekend.
  bool isWeekend() {
    final dow = _engine.dayOfWeek;
    return dow == 6 || dow == 7; // Saturday or Sunday
  }

  /// Check if this is a weekday.
  bool isWeekday() {
    return !isWeekend();
  }

  /// Check if this is a leap year.
  bool isLeapYear() {
    return _engine.isLeapYear;
  }

  // ---------------------------------------------------------------------------
  // Copy
  // ---------------------------------------------------------------------------

  /// Create a copy of this Carbon instance.
  Carbon copy() {
    return Carbon.fromDateTime(_engine.dateTime);
  }

  // ---------------------------------------------------------------------------
  // Object Overrides
  // ---------------------------------------------------------------------------

  @override
  int compareTo(Carbon other) {
    return _engine.dateTime.compareTo(other._engine.dateTime);
  }

  @override
  bool operator ==(Object other) {
    if (other is Carbon) {
      return _engine.dateTime == other._engine.dateTime;
    }
    return false;
  }

  @override
  int get hashCode => _engine.dateTime.hashCode;

  @override
  String toString() => toDateTimeString();
}
