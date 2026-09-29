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

    test('is null for a transport failure, whatever the driver wrote', () {
      // The driver fills `message` with its own diagnosis ("The connection
      // errored: The XMLHttpRequest onError callback was called...") when it
      // got no readable answer. That is not the backend's word, and a caller that
      // toasts `message ?? its own copy` must fall through to its own copy.
      final response = MagicResponse(
        data: null,
        statusCode: 0,
        message: 'The connection errored: XMLHttpRequest onError.',
      );

      expect(ActionRequestFailed('create', response).message, isNull);
    });
  });

  group('ActionRequestFailed.message reads the body only', () {
    test('ignores the text the driver wrote for a body that is not JSON', () {
      // A native client's 502 HTML page during a deploy: the body is a String,
      // and MagicResponse.errorMessage falls back to the driver's own
      // multi-line "This exception was thrown because the response has a
      // status code of 502..." paragraph, which then landed in a toast.
      final response = MagicResponse(
        data: '<html>502 Bad Gateway</html>',
        statusCode: 502,
        message:
            'This exception was thrown because the response has a status '
            'code of 502 and RequestOptions.validateStatus was configured to '
            'throw for this status code.',
      );

      expect(ActionRequestFailed('create', response).message, isNull);
    });

    test('is null for a blank body message', () {
      // Laravel's `abort(404)` carries no message, so its JSON body is
      // `{"message": ""}`, and a caller toasting `message ?? its own copy`
      // showed an empty toast body.
      final response = MagicResponse(data: {'message': '  '}, statusCode: 404);

      expect(ActionRequestFailed('delete', response).message, isNull);
    });

    test('keeps the driver diagnosis in the log line', () {
      // The toast must not show it, but a status 0 merges connection errors,
      // timeouts and transform failures, and this text is the only thing in a
      // log line that tells them apart.
      final response = MagicResponse(
        data: null,
        statusCode: 0,
        message: 'The connection errored: XMLHttpRequest onError.',
      );

      expect(
        ActionRequestFailed('create', response).toString(),
        contains('The connection errored'),
      );
    });
  });

  group('ActionRequestFailed.isTransportFailure', () {
    test('is true only when the refusing response is status 0', () {
      expect(
        ActionRequestFailed(
          'create',
          MagicResponse(data: null, statusCode: 0),
        ).isTransportFailure,
        isTrue,
      );
      expect(
        ActionRequestFailed(
          'create',
          MagicResponse(data: null, statusCode: 500),
        ).isTransportFailure,
        isFalse,
      );
      expect(
        const ActionRequestFailed('create').isTransportFailure,
        isFalse,
        reason: 'no response is unknown, not proof of a transport failure',
      );
    });

    test('refusalOf carries a status 0 response through to it', () {
      final result = ActionRequestFailed.refusalOf(
        'create',
        const {},
        MagicResponse(data: null, statusCode: 0),
      );

      expect((result as ActionRequestFailed).isTransportFailure, isTrue);
    });
  });
}
