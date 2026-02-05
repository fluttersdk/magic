import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// A mock logger driver that captures all log calls for testing.
class MockLoggerDriver extends LoggerDriver {
  final List<Map<String, dynamic>> logs = [];

  @override
  void log(String level, String message, [dynamic context]) {
    logs.add({
      'level': level,
      'message': message,
      'context': context,
    });
  }

  void clear() => logs.clear();
}

void main() {
  group('LoggerDriver', () {
    late MockLoggerDriver driver;

    setUp(() {
      driver = MockLoggerDriver();
    });

    test('emergency logs at emergency level', () {
      driver.emergency('System down');
      expect(driver.logs.last['level'], equals('emergency'));
      expect(driver.logs.last['message'], equals('System down'));
    });

    test('alert logs at alert level', () {
      driver.alert('Action needed');
      expect(driver.logs.last['level'], equals('alert'));
    });

    test('critical logs at critical level', () {
      driver.critical('Critical error');
      expect(driver.logs.last['level'], equals('critical'));
    });

    test('error logs at error level', () {
      driver.error('Something failed');
      expect(driver.logs.last['level'], equals('error'));
    });

    test('warning logs at warning level', () {
      driver.warning('Deprecated usage');
      expect(driver.logs.last['level'], equals('warning'));
    });

    test('notice logs at notice level', () {
      driver.notice('Significant event');
      expect(driver.logs.last['level'], equals('notice'));
    });

    test('info logs at info level', () {
      driver.info('User logged in');
      expect(driver.logs.last['level'], equals('info'));
    });

    test('debug logs at debug level', () {
      driver.debug('Debug info');
      expect(driver.logs.last['level'], equals('debug'));
    });

    test('logs with context', () {
      driver.info('User action', {'id': 123, 'action': 'login'});
      expect(driver.logs.last['context'], isA<Map>());
      expect(driver.logs.last['context']['id'], equals(123));
    });
  });

  group('StackLoggerDriver', () {
    test('sends logs to all channels', () {
      final driver1 = MockLoggerDriver();
      final driver2 = MockLoggerDriver();
      final stack = StackLoggerDriver([driver1, driver2]);

      stack.info('Test message');

      expect(driver1.logs.length, equals(1));
      expect(driver2.logs.length, equals(1));
      expect(driver1.logs.first['message'], equals('Test message'));
      expect(driver2.logs.first['message'], equals('Test message'));
    });

    test('passes context to all channels', () {
      final driver1 = MockLoggerDriver();
      final driver2 = MockLoggerDriver();
      final stack = StackLoggerDriver([driver1, driver2]);

      stack.error('Error occurred', {'code': 500});

      expect(driver1.logs.first['context']['code'], equals(500));
      expect(driver2.logs.first['context']['code'], equals(500));
    });
  });

  group('ConsoleLoggerDriver', () {
    test('can be instantiated with default level', () {
      final driver = ConsoleLoggerDriver();
      expect(driver, isA<LoggerDriver>());
    });

    test('can be instantiated with custom level', () {
      final driver = ConsoleLoggerDriver(minLevel: 'error');
      expect(driver, isA<LoggerDriver>());
    });

    test('respects minimum log level', () {
      // With minLevel 'error', debug/info should be ignored
      final driver = ConsoleLoggerDriver(minLevel: 'error');
      // This won't throw, just won't print (can't easily test console output)
      driver.debug('Should be ignored');
      driver.error('Should be logged');
    });
  });
}
