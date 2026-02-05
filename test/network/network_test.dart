import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

void main() {
  group('MagicResponse', () {
    test('successful returns true for 2xx status codes', () {
      expect(MagicResponse(data: {}, statusCode: 200).successful, isTrue);
      expect(MagicResponse(data: {}, statusCode: 201).successful, isTrue);
      expect(MagicResponse(data: {}, statusCode: 299).successful, isTrue);
      expect(MagicResponse(data: {}, statusCode: 300).successful, isFalse);
    });

    test('failed returns true for 4xx and 5xx status codes', () {
      expect(MagicResponse(data: {}, statusCode: 400).failed, isTrue);
      expect(MagicResponse(data: {}, statusCode: 404).failed, isTrue);
      expect(MagicResponse(data: {}, statusCode: 500).failed, isTrue);
      expect(MagicResponse(data: {}, statusCode: 200).failed, isFalse);
    });

    test('clientError returns true for 4xx status codes', () {
      expect(MagicResponse(data: {}, statusCode: 400).clientError, isTrue);
      expect(MagicResponse(data: {}, statusCode: 499).clientError, isTrue);
      expect(MagicResponse(data: {}, statusCode: 500).clientError, isFalse);
    });

    test('serverError returns true for 5xx status codes', () {
      expect(MagicResponse(data: {}, statusCode: 500).serverError, isTrue);
      expect(MagicResponse(data: {}, statusCode: 503).serverError, isTrue);
      expect(MagicResponse(data: {}, statusCode: 499).serverError, isFalse);
    });

    test('unauthorized returns true for 401', () {
      expect(MagicResponse(data: {}, statusCode: 401).unauthorized, isTrue);
      expect(MagicResponse(data: {}, statusCode: 403).unauthorized, isFalse);
    });

    test('forbidden returns true for 403', () {
      expect(MagicResponse(data: {}, statusCode: 403).forbidden, isTrue);
      expect(MagicResponse(data: {}, statusCode: 401).forbidden, isFalse);
    });

    test('notFound returns true for 404', () {
      expect(MagicResponse(data: {}, statusCode: 404).notFound, isTrue);
      expect(MagicResponse(data: {}, statusCode: 400).notFound, isFalse);
    });

    test('dataAs casts data to specific type', () {
      final response = MagicResponse(
        data: {'name': 'John', 'age': 30},
        statusCode: 200,
      );

      final map = response.dataAs<Map<String, dynamic>>();
      expect(map['name'], equals('John'));
      expect(map['age'], equals(30));
    });

    test('bracket operator accesses map data', () {
      final response = MagicResponse(
        data: {'id': 123, 'email': 'test@example.com'},
        statusCode: 200,
      );

      expect(response['id'], equals(123));
      expect(response['email'], equals('test@example.com'));
      expect(response['missing'], isNull);
    });

    test('bracket operator returns null for non-map data', () {
      final response = MagicResponse(
        data: 'string data',
        statusCode: 200,
      );

      expect(response['key'], isNull);
    });

    test('toString provides readable output', () {
      final response = MagicResponse(
        data: {'id': 1},
        statusCode: 200,
        message: 'OK',
      );

      expect(response.toString(), contains('200'));
      expect(response.toString(), contains('OK'));
    });
  });

  group('DioNetworkDriver', () {
    late DioNetworkDriver driver;

    setUp(() {
      driver = DioNetworkDriver(
        baseUrl: 'https://jsonplaceholder.typicode.com',
        timeout: 10000,
        defaultHeaders: {'Accept': 'application/json'},
      );
    });

    test('can be instantiated with config', () {
      expect(driver, isA<NetworkDriver>());
    });

    test('addInterceptor accepts MagicNetworkInterceptor', () {
      final interceptor = _TestInterceptor();
      // Should not throw
      driver.addInterceptor(interceptor);
    });
  });
}

class _TestInterceptor extends MagicNetworkInterceptor {
  @override
  dynamic onRequest(options) {
    options.headers['X-Test'] = 'true';
    return options;
  }
}
