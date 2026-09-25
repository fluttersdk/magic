import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// Bare [ValidatesRequests] host, nothing else.
class _TestController extends MagicController with ValidatesRequests {}

/// Same host with the opt-in indexed-key collapse layered on top.
class _CollapsingController extends MagicController
    with ValidatesRequests, CollapsesIndexedErrorKeys {}

/// [FormRequest] whose [rules] cover only `name`, so `validateRequest` must
/// return the full payload (including the unruled `extra` key) rather than
/// the filtered map `FormRequest.validate` would produce.
class _TestRequest extends FormRequest {
  const _TestRequest({this.allowed = true});

  final bool allowed;

  @override
  bool authorize() => allowed;

  @override
  Map<String, List<Rule>> rules() => {
    'name': [Required()],
  };
}

/// A [FormRequest] whose [prepared] injects a derived key, so the test can
/// pin that `validateRequest` validates and returns THIS output, not the
/// raw input passed in.
class _PreparingRequest extends FormRequest {
  const _PreparingRequest();

  @override
  Map<String, List<Rule>> rules() => {
    'name': [Required()],
    'slug': [Required()],
  };

  @override
  Map<String, dynamic> prepared(Map<String, dynamic> data) => {
    ...data,
    'slug': (data['name'] as String? ?? '').toLowerCase(),
  };
}

/// An [AsyncRule] double that always fails, so `validateRequestAsync` can be
/// pinned against a rule the synchronous `validate` path would never run.
class _AlwaysFailsAsync extends AsyncRule {
  @override
  Future<bool> passesAsync(
    String attribute,
    dynamic value,
    Map<String, dynamic> data,
  ) async => false;

  @override
  String message() => 'validation.custom_async';
}

/// A [FormRequest] whose only rule is an [AsyncRule], so a sync `validate`
/// call would pass unconditionally (see [AsyncRule.passes]) while
/// `validateRequestAsync` correctly fails it.
class _AsyncRequest extends FormRequest {
  const _AsyncRequest();

  @override
  Map<String, List<Rule>> rules() => {
    'email': [_AlwaysFailsAsync()],
  };
}

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  group('validateRequest', () {
    test('unauthorized request throws AuthorizationException', () {
      final controller = _TestController();

      expect(
        () => controller.validateRequest(const _TestRequest(allowed: false), {
          'name': 'Payment API',
        }),
        throwsA(isA<AuthorizationException>()),
      );
      expect(controller.validationErrors, isEmpty);
    });

    test('a failed rule populates validationErrors and rethrows', () {
      final controller = _TestController();

      expect(
        () => controller.validateRequest(const _TestRequest(), {'name': ''}),
        throwsA(isA<ValidationException>()),
      );
      expect(controller.validationErrors, containsPair('name', isA<String>()));
      expect(controller.validationErrors['name'], isNotEmpty);
    });

    test('success returns the full map, including keys without rules', () {
      final controller = _TestController();

      final result = controller.validateRequest(const _TestRequest(), {
        'name': 'Payment API',
        'extra': 'not covered by any rule',
      });

      expect(result, {
        'name': 'Payment API',
        'extra': 'not covered by any rule',
      });
    });

    test('prepared() output is what gets validated and returned', () {
      final controller = _TestController();

      final result = controller.validateRequest(const _PreparingRequest(), {
        'name': 'Payment API',
      });

      expect(result, {'name': 'Payment API', 'slug': 'payment api'});
    });
  });

  group('validateRequestAsync', () {
    test('unauthorized request throws AuthorizationException', () async {
      final controller = _TestController();

      await expectLater(
        () => controller.validateRequestAsync(
          const _TestRequest(allowed: false),
          {'name': 'Payment API'},
        ),
        throwsA(isA<AuthorizationException>()),
      );
      expect(controller.validationErrors, isEmpty);
    });

    test(
      'a failed AsyncRule populates validationErrors and rethrows',
      () async {
        final controller = _TestController();

        await expectLater(
          () => controller.validateRequestAsync(const _AsyncRequest(), {
            'email': 'someone@example.com',
          }),
          throwsA(isA<ValidationException>()),
        );
        expect(
          controller.validationErrors,
          containsPair('email', isA<String>()),
        );
      },
    );

    test('success returns the full prepared map', () async {
      final controller = _TestController();

      final result = await controller.validateRequestAsync(
        const _PreparingRequest(),
        {'name': 'Payment API'},
      );

      expect(result, {'name': 'Payment API', 'slug': 'payment api'});
    });
  });

  group('setErrorsFromResponse key handling', () {
    test('an indexed key keeps its raw form by default', () {
      final controller = _TestController();
      final response = MagicResponse(
        data: {
          'errors': {
            'items.0.name': ['The items.0.name field is required.'],
          },
        },
        statusCode: 422,
      );

      controller.setErrorsFromResponse(response);

      expect(controller.validationErrors, {
        'items.0.name': 'The items.0.name field is required.',
      });
    });

    test(
      'the same response collapses to the field name through CollapsesIndexedErrorKeys',
      () {
        final controller = _CollapsingController();
        final response = MagicResponse(
          data: {
            'errors': {
              'items.0.name': ['The items.0.name field is required.'],
            },
          },
          statusCode: 422,
        );

        controller.setErrorsFromResponse(response);

        expect(controller.validationErrors, {
          'name': 'The items.0.name field is required.',
        });
      },
    );

    test('an empty error list is skipped', () {
      final controller = _TestController();
      final response = MagicResponse(
        data: {
          'errors': {
            'name': <String>[],
            'email': ['The email field is required.'],
          },
        },
        statusCode: 422,
      );

      controller.setErrorsFromResponse(response);

      expect(controller.validationErrors, {
        'email': 'The email field is required.',
      });
    });

    test(
      'two keys that collapse onto the same field keep the FIRST message',
      () {
        final controller = _CollapsingController();
        final response = MagicResponse(
          data: {
            'errors': {
              'items.0.name': ['first message'],
              'items.1.name': ['second message'],
            },
          },
          statusCode: 422,
        );

        controller.setErrorsFromResponse(response);

        expect(controller.validationErrors, {'name': 'first message'});
      },
    );
  });
}
