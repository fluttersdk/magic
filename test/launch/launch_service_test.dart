import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:magic/src/launch/launch_adapter.dart';
import 'package:magic/src/launch/launch_service.dart';
import 'package:magic/src/logging/contracts/logger_driver.dart';
import 'package:magic/src/logging/log_manager.dart';
import 'package:magic/src/foundation/application.dart';
import 'package:magic/src/foundation/magic.dart';

class MockLaunchAdapter implements LaunchAdapter {
  bool shouldSucceed = true;
  bool shouldThrow = false;
  List<Uri> launchCalls = [];
  List<Uri> canLaunchCalls = [];
  LaunchMode? lastMode;

  @override
  Future<bool> launch(
    Uri url, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) async {
    launchCalls.add(url);
    lastMode = mode;
    if (shouldThrow) {
      throw PlatformException(code: 'test_error', message: 'Launch failed');
    }
    return shouldSucceed;
  }

  @override
  Future<bool> canLaunch(Uri url) async {
    canLaunchCalls.add(url);
    if (shouldThrow) {
      throw PlatformException(code: 'test_error', message: 'Check failed');
    }
    return shouldSucceed;
  }
}

class MockLogDriver implements LoggerDriver {
  List<String> errorMessages = [];

  @override
  void log(String level, String message, [dynamic context]) {
    if (level == 'error') {
      errorMessages.add(message);
    }
  }

  @override
  void emergency(String message, [dynamic context]) =>
      log('error', message, context);
  @override
  void alert(String message, [dynamic context]) =>
      log('error', message, context);
  @override
  void critical(String message, [dynamic context]) =>
      log('error', message, context);
  @override
  void error(String message, [dynamic context]) =>
      log('error', message, context);
  @override
  void warning(String message, [dynamic context]) {}
  @override
  void notice(String message, [dynamic context]) {}
  @override
  void info(String message, [dynamic context]) {}
  @override
  void debug(String message, [dynamic context]) {}
}

class MockLogManager extends LogManager {
  final LoggerDriver mockDriver;
  MockLogManager(this.mockDriver);

  @override
  LoggerDriver driver([String? channel]) => mockDriver;
}

void main() {
  group('LaunchService', () {
    late LaunchService service;
    late MockLaunchAdapter adapter;
    late MockLogDriver logDriver;

    setUp(() async {
      MagicApp.reset();
      Magic.flush();

      // Initialize mocked environment
      adapter = MockLaunchAdapter();
      logDriver = MockLogDriver();

      await Magic.init(configs: [
        {
          'app': {'name': 'Test'}
        }
      ]);

      // Inject LogManager mock
      MagicApp.instance.setInstance('log', MockLogManager(logDriver));

      // Instantiate our target class
      service = LaunchService(adapter: adapter);
      MagicApp.instance.setInstance('launch', service);
    });

    group('url()', () {
      test('returns true for successful URL launch', () async {
        final result = await service.url('https://flutter.dev');

        expect(result, isTrue);
        expect(adapter.launchCalls.length, 1);
        expect(adapter.launchCalls.first.toString(), 'https://flutter.dev');
        expect(adapter.lastMode, LaunchMode.externalApplication);
        expect(logDriver.errorMessages.isEmpty, isTrue);
      });

      test('returns false when adapter returns false', () async {
        adapter.shouldSucceed = false;
        final result = await service.url('https://flutter.dev');

        expect(result, isFalse);
        expect(adapter.launchCalls.length, 1);
      });

      test('passes custom LaunchMode to adapter', () async {
        final result = await service.url(
          'https://flutter.dev',
          mode: LaunchMode.inAppWebView,
        );

        expect(result, isTrue);
        expect(adapter.lastMode, LaunchMode.inAppWebView);
      });

      test('returns false for malformed URL', () async {
        final result = await service.url('h t t p://bad url');

        expect(result, isFalse);
        expect(adapter.launchCalls.isEmpty, isTrue);
        expect(logDriver.errorMessages.length, 1);
        expect(logDriver.errorMessages.first, contains('Invalid URL format'));
      });

      test('returns false for empty URL', () async {
        final result = await service.url('');

        expect(result, isFalse);
        expect(adapter.launchCalls.isEmpty, isTrue);
        expect(logDriver.errorMessages.isEmpty, isTrue);
      });

      test('returns false when adapter throws PlatformException', () async {
        adapter.shouldThrow = true;
        final result = await service.url('https://flutter.dev');

        expect(result, isFalse);
        expect(adapter.launchCalls.length, 1);
        expect(logDriver.errorMessages.length, 1);
        expect(logDriver.errorMessages.first, contains('Launch failed'));
      });
    });

    group('email()', () {
      test('calls adapter with mailto URI', () async {
        final result = await service.email('test@example.com');

        expect(result, isTrue);
        expect(adapter.launchCalls.length, 1);
        expect(adapter.launchCalls.first.scheme, 'mailto');
        expect(adapter.launchCalls.first.path, 'test@example.com');
      });

      test('includes subject and body in URI query params', () async {
        final result = await service.email(
          'test@example.com',
          subject: 'Hello',
          body: 'World',
        );

        expect(result, isTrue);
        final uri = adapter.launchCalls.first;
        expect(uri.queryParameters['subject'], 'Hello');
        expect(uri.queryParameters['body'], 'World');
      });

      test('encodes special characters in subject', () async {
        final result = await service.email(
          'test@example.com',
          subject: 'Hello & Welcome = %20',
        );

        expect(result, isTrue);
        final uri = adapter.launchCalls.first;
        expect(uri.queryParameters['subject'], 'Hello & Welcome = %20');
      });

      test('returns false for empty address', () async {
        final result = await service.email('');

        expect(result, isFalse);
        expect(adapter.launchCalls.isEmpty, isTrue);
      });
    });

    group('phone()', () {
      test('calls adapter with tel URI', () async {
        final result = await service.phone('+1234567890');

        expect(result, isTrue);
        expect(adapter.launchCalls.length, 1);
        expect(adapter.launchCalls.first.scheme, 'tel');
        expect(adapter.launchCalls.first.path, '+1234567890');
      });

      test('returns false for empty number', () async {
        final result = await service.phone('');

        expect(result, isFalse);
        expect(adapter.launchCalls.isEmpty, isTrue);
      });
    });

    group('sms()', () {
      test('calls adapter with sms URI without body', () async {
        final result = await service.sms('+1234567890');

        expect(result, isTrue);
        expect(adapter.launchCalls.length, 1);
        expect(adapter.launchCalls.first.scheme, 'sms');
        expect(adapter.launchCalls.first.path, '+1234567890');
        expect(adapter.launchCalls.first.queryParameters.isEmpty, isTrue);
      });

      test('includes body in sms URI query params', () async {
        final result = await service.sms('+1234567890', body: 'Hello Text');

        expect(result, isTrue);
        final uri = adapter.launchCalls.first;
        expect(uri.scheme, 'sms');
        expect(uri.queryParameters['body'], 'Hello Text');
      });

      test('returns false for empty number', () async {
        final result = await service.sms('');

        expect(result, isFalse);
        expect(adapter.launchCalls.isEmpty, isTrue);
      });
    });

    group('canLaunch()', () {
      test('returns true when adapter returns true', () async {
        final result = await service.canLaunch('https://flutter.dev');

        expect(result, isTrue);
        expect(adapter.canLaunchCalls.length, 1);
        expect(adapter.canLaunchCalls.first.toString(), 'https://flutter.dev');
      });

      test('returns false when adapter returns false', () async {
        adapter.shouldSucceed = false;
        final result = await service.canLaunch('https://flutter.dev');

        expect(result, isFalse);
      });

      test('returns false for malformed URL', () async {
        final result = await service.canLaunch('h t t p://bad url');

        expect(result, isFalse);
        expect(adapter.canLaunchCalls.isEmpty, isTrue);
        expect(logDriver.errorMessages.length, 1);
      });

      test('returns false when adapter throws', () async {
        adapter.shouldThrow = true;
        final result = await service.canLaunch('https://flutter.dev');

        expect(result, isFalse);
        expect(logDriver.errorMessages.length, 1);
      });
    });
  });
}
