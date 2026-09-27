import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

void main() {
  group('ActionRequestFailed.refusalOf', () {
    test('answers a ValidationException with the first message per field '
        'when errors is non-empty', () {
      final result = ActionRequestFailed.refusalOf('pause', {
        'status': ['must not be paused', 'is invalid'],
        'id': ['is required'],
      });

      expect(result, isA<ValidationException>());
      final validation = result as ValidationException;
      expect(validation.errors['status'], 'must not be paused');
      expect(validation.errors['id'], 'is required');
    });

    test('answers an ActionRequestFailed carrying the response when errors '
        'is empty', () {
      final response = MagicResponse(data: null, statusCode: 500);

      final result = ActionRequestFailed.refusalOf('pause', {}, response);

      expect(result, isA<ActionRequestFailed>());
      final failed = result as ActionRequestFailed;
      expect(failed.action, 'pause');
      expect(failed.response, same(response));
    });
  });

  group('ActionRequestFailed.retryAfterSeconds', () {
    test('reads retry_after_seconds from a 429 response body', () {
      final response = MagicResponse(
        data: {'retry_after_seconds': 42},
        statusCode: 429,
      );
      final failure = ActionRequestFailed('pause', response);

      expect(failure.retryAfterSeconds, 42);
    });

    test('falls back to 1 when the body carries no usable value', () {
      final withoutBody = ActionRequestFailed('pause', null);
      final withNonMapBody = ActionRequestFailed(
        'pause',
        MagicResponse(data: 'not a map', statusCode: 429),
      );
      final withMissingKey = ActionRequestFailed(
        'pause',
        MagicResponse(data: <String, dynamic>{}, statusCode: 429),
      );

      expect(withoutBody.retryAfterSeconds, 1);
      expect(withNonMapBody.retryAfterSeconds, 1);
      expect(withMissingKey.retryAfterSeconds, 1);
    });
  });

  group('ActionRequestFailed.message', () {
    test('withMessage wins over the response message', () {
      final response = MagicResponse(
        data: {'message': 'from the response'},
        statusCode: 500,
      );
      final withMessage = ActionRequestFailed.withMessage(
        'pause',
        'from withMessage',
      );

      expect(withMessage.message, 'from withMessage');
      expect(
        ActionRequestFailed('pause', response).message,
        'from the response',
      );
    });
  });
}
