import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_magic/src/support/carbon.dart';

void main() {
  group('Carbon Constructors', () {
    test('now() creates current date/time', () {
      final now = Carbon.now();
      final dartNow = DateTime.now();

      expect(now.year, dartNow.year);
      expect(now.month, dartNow.month);
      expect(now.day, dartNow.day);
    });

    test('parse() creates from string', () {
      final date = Carbon.parse('2024-01-15');

      expect(date.year, 2024);
      expect(date.month, 1);
      expect(date.day, 15);
    });

    test('fromDateTime() creates from DateTime', () {
      final dt = DateTime(2024, 6, 20, 14, 30, 45);
      final carbon = Carbon.fromDateTime(dt);

      expect(carbon.year, 2024);
      expect(carbon.month, 6);
      expect(carbon.day, 20);
      expect(carbon.hour, 14);
      expect(carbon.minute, 30);
      expect(carbon.second, 45);
    });

    test('create() builds from parts', () {
      final carbon = Carbon.create(
        year: 2024,
        month: 3,
        day: 15,
        hour: 10,
        minute: 30,
      );

      expect(carbon.year, 2024);
      expect(carbon.month, 3);
      expect(carbon.day, 15);
      expect(carbon.hour, 10);
      expect(carbon.minute, 30);
    });
  });

  group('Carbon Getters', () {
    test('returns correct year, month, day', () {
      final carbon = Carbon.parse('2024-07-25');

      expect(carbon.year, 2024);
      expect(carbon.month, 7);
      expect(carbon.day, 25);
    });

    test('returns correct hour, minute, second', () {
      final carbon = Carbon.fromDateTime(DateTime(2024, 1, 1, 14, 30, 45));

      expect(carbon.hour, 14);
      expect(carbon.minute, 30);
      expect(carbon.second, 45);
    });

    test('returns correct dayOfWeek', () {
      // 2024-01-15 is a Monday (Jiffy: dayOfWeek = 2 for Monday)
      final monday = Carbon.parse('2024-01-15');
      expect(monday.dayOfWeek, 2); // Jiffy: Sunday=1, Monday=2

      // 2024-01-20 is a Saturday
      final saturday = Carbon.parse('2024-01-20');
      expect(saturday.dayOfWeek, 7);
    });

    test('toDateTime returns DateTime', () {
      final carbon = Carbon.parse('2024-01-15');
      final dt = carbon.toDateTime;

      expect(dt, isA<DateTime>());
      expect(dt.year, 2024);
    });
  });

  group('Carbon Manipulation - Days', () {
    test('addDay() adds one day', () {
      final carbon = Carbon.parse('2024-01-15');
      final result = carbon.addDay();

      expect(result.day, 16);
    });

    test('addDays() adds multiple days', () {
      final carbon = Carbon.parse('2024-01-15');
      final result = carbon.addDays(5);

      expect(result.day, 20);
    });

    test('subDay() subtracts one day', () {
      final carbon = Carbon.parse('2024-01-15');
      final result = carbon.subDay();

      expect(result.day, 14);
    });

    test('subDays() subtracts multiple days', () {
      final carbon = Carbon.parse('2024-01-15');
      final result = carbon.subDays(10);

      expect(result.day, 5);
    });

    test('manipulation is immutable', () {
      final original = Carbon.parse('2024-01-15');
      final modified = original.addDays(5);

      expect(original.day, 15);
      expect(modified.day, 20);
    });
  });

  group('Carbon Manipulation - Months', () {
    test('addMonth() adds one month', () {
      final carbon = Carbon.parse('2024-01-15');
      final result = carbon.addMonth();

      expect(result.month, 2);
    });

    test('addMonths() adds multiple months', () {
      final carbon = Carbon.parse('2024-01-15');
      final result = carbon.addMonths(6);

      expect(result.month, 7);
    });

    test('subMonth() subtracts one month', () {
      final carbon = Carbon.parse('2024-03-15');
      final result = carbon.subMonth();

      expect(result.month, 2);
    });
  });

  group('Carbon Manipulation - Years', () {
    test('addYear() adds one year', () {
      final carbon = Carbon.parse('2024-01-15');
      final result = carbon.addYear();

      expect(result.year, 2025);
    });

    test('subYears() subtracts multiple years', () {
      final carbon = Carbon.parse('2024-01-15');
      final result = carbon.subYears(5);

      expect(result.year, 2019);
    });
  });

  group('Carbon Modifiers', () {
    test('startOfDay() sets to 00:00:00', () {
      final carbon = Carbon.fromDateTime(DateTime(2024, 1, 15, 14, 30, 45));
      final result = carbon.startOfDay();

      expect(result.hour, 0);
      expect(result.minute, 0);
      expect(result.second, 0);
      expect(result.day, 15);
    });

    test('endOfDay() sets to 23:59:59', () {
      final carbon = Carbon.fromDateTime(DateTime(2024, 1, 15, 10, 0, 0));
      final result = carbon.endOfDay();

      expect(result.hour, 23);
      expect(result.minute, 59);
      expect(result.second, 59);
    });

    test('startOfMonth() sets to first day', () {
      final carbon = Carbon.parse('2024-01-15');
      final result = carbon.startOfMonth();

      expect(result.day, 1);
    });

    test('endOfMonth() sets to last day', () {
      final carbon = Carbon.parse('2024-01-15');
      final result = carbon.endOfMonth();

      expect(result.day, 31);
    });
  });

  group('Carbon Formatting', () {
    test('format() with pattern', () {
      final carbon = Carbon.parse('2024-01-15');
      final result = carbon.format('yyyy-MM-dd');

      expect(result, '2024-01-15');
    });

    test('toDateString() returns yyyy-MM-dd', () {
      final carbon = Carbon.parse('2024-01-15');

      expect(carbon.toDateString(), '2024-01-15');
    });

    test('toTimeString() returns HH:mm:ss', () {
      final carbon = Carbon.fromDateTime(DateTime(2024, 1, 1, 14, 30, 45));

      expect(carbon.toTimeString(), '14:30:45');
    });

    test('toDateTimeString() returns full format', () {
      final carbon = Carbon.fromDateTime(DateTime(2024, 1, 15, 14, 30, 45));

      expect(carbon.toDateTimeString(), '2024-01-15 14:30:45');
    });

    test('toIso8601String() returns ISO format', () {
      final carbon = Carbon.parse('2024-01-15');
      final iso = carbon.toIso8601String();

      expect(iso, contains('2024-01-15'));
    });
  });

  group('Carbon Diff', () {
    test('diffForHumans() returns human readable', () {
      final past = Carbon.now().subDays(1);
      final diff = past.diffForHumans();

      expect(diff, contains('day'));
    });

    test('diffInDays() returns days difference', () {
      final a = Carbon.parse('2024-01-15');
      final b = Carbon.parse('2024-01-20');

      expect(a.diffInDays(b), -5);
    });

    test('diffInMonths() returns months difference', () {
      final a = Carbon.parse('2024-01-15');
      final b = Carbon.parse('2024-04-15');

      expect(a.diffInMonths(b), -3);
    });
  });

  group('Carbon Comparison', () {
    test('isAfter() checks if after', () {
      final a = Carbon.parse('2024-01-20');
      final b = Carbon.parse('2024-01-15');

      expect(a.isAfter(b), isTrue);
      expect(b.isAfter(a), isFalse);
    });

    test('isBefore() checks if before', () {
      final a = Carbon.parse('2024-01-10');
      final b = Carbon.parse('2024-01-15');

      expect(a.isBefore(b), isTrue);
      expect(b.isBefore(a), isFalse);
    });

    test('isToday() checks if today', () {
      final today = Carbon.now();
      final yesterday = Carbon.now().subDay();

      expect(today.isToday(), isTrue);
      expect(yesterday.isToday(), isFalse);
    });

    test('isFuture() checks if in future', () {
      final future = Carbon.now().addDays(5);
      final past = Carbon.now().subDays(5);

      expect(future.isFuture(), isTrue);
      expect(past.isFuture(), isFalse);
    });

    test('isPast() checks if in past', () {
      final past = Carbon.now().subDays(5);
      final future = Carbon.now().addDays(5);

      expect(past.isPast(), isTrue);
      expect(future.isPast(), isFalse);
    });

    test('isWeekend() checks if Saturday or Sunday', () {
      // Find a Saturday
      var date = Carbon.now();
      while (date.dayOfWeek != 6) {
        date = date.addDay();
      }

      expect(date.isWeekend(), isTrue);
      expect(date.addDays(2).isWeekend(), isFalse); // Monday
    });
  });

  group('Carbon Equality', () {
    test('equals same date/time', () {
      final a = Carbon.parse('2024-01-15');
      final b = Carbon.parse('2024-01-15');

      expect(a == b, isTrue);
    });

    test('not equal different dates', () {
      final a = Carbon.parse('2024-01-15');
      final b = Carbon.parse('2024-01-16');

      expect(a == b, isFalse);
    });

    test('compareTo orders correctly', () {
      final a = Carbon.parse('2024-01-10');
      final b = Carbon.parse('2024-01-20');

      expect(a.compareTo(b), lessThan(0));
      expect(b.compareTo(a), greaterThan(0));
    });
  });

  group('Carbon Copy', () {
    test('copy() creates independent copy', () {
      final original = Carbon.parse('2024-01-15');
      final copied = original.copy();

      expect(copied.day, original.day);
      expect(identical(original, copied), isFalse);
    });
  });
}
