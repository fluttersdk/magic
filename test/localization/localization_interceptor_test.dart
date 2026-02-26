import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/localization/localization_interceptor.dart';
import 'package:magic/src/localization/translator.dart';
import 'package:magic/src/network/magic_response.dart';
import 'package:magic/src/support/date_manager.dart';

void main() {
  group('LocalizationInterceptor', () {
    setUp(() {
      Translator.reset();
      DateManager.reset();
    });

    test('should set Accept-Language header from Translator locale', () {
      final interceptor = LocalizationInterceptor();
      final request = MagicRequest(
        url: '/test',
        method: 'GET',
        headers: <String, dynamic>{},
      );

      // Translator defaults to 'en' locale
      final result = interceptor.onRequest(request) as MagicRequest;

      expect(result.headers['Accept-Language'], isNotEmpty);
      expect(
        result.headers['Accept-Language'],
        Translator.instance.locale.languageCode,
      );
    });

    test('should set X-Timezone header from DateManager', () {
      final interceptor = LocalizationInterceptor();
      final request = MagicRequest(
        url: '/test',
        method: 'GET',
        headers: <String, dynamic>{},
      );

      final result = interceptor.onRequest(request) as MagicRequest;

      expect(result.headers['X-Timezone'], isNotEmpty);
      expect(
        result.headers['X-Timezone'],
        DateManager.instance.timezoneName,
      );
    });

    test('should set both headers on every request', () {
      final interceptor = LocalizationInterceptor();
      final request = MagicRequest(
        url: '/users',
        method: 'POST',
        headers: <String, dynamic>{
          'Authorization': 'Bearer token123',
        },
        data: {'name': 'Test'},
      );

      final result = interceptor.onRequest(request) as MagicRequest;

      // Both localization headers present
      expect(result.headers.containsKey('Accept-Language'), isTrue);
      expect(result.headers.containsKey('X-Timezone'), isTrue);

      // Existing headers preserved
      expect(result.headers['Authorization'], 'Bearer token123');
    });

    test('should passthrough response unchanged', () {
      final interceptor = LocalizationInterceptor();
      final response = MagicResponse(
        data: {'success': true},
        statusCode: 200,
        headers: {},
      );

      final result = interceptor.onResponse(response);

      expect(identical(result, response), isTrue);
    });

    test('should passthrough error unchanged', () {
      final interceptor = LocalizationInterceptor();
      final error = MagicError(
        message: 'Not Found',
      );

      final result = interceptor.onError(error);

      expect(identical(result, error), isTrue);
    });
  });
}
