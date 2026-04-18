import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

class StoreMonitorRequest extends FormRequest {
  StoreMonitorRequest({this.canCreate = true});

  final bool canCreate;

  @override
  bool authorize() => canCreate;

  @override
  Map<String, dynamic> prepared(Map<String, dynamic> data) => {
    ...data,
    'name': (data['name'] as String?)?.trim(),
  };

  @override
  Map<String, List<Rule>> rules() => {
    'name': [Required(), Max(120)],
    'email': [Required(), Email()],
  };
}

void main() {
  group('FormRequest.validate', () {
    test('returns prepared payload when all rules pass', () {
      final request = StoreMonitorRequest();
      final payload = request.validate({
        'name': '  Sentry  ',
        'email': 'ops@example.com',
      });

      expect(payload['name'], 'Sentry');
      expect(payload['email'], 'ops@example.com');
    });

    test('prepared() runs before rules', () {
      final request = StoreMonitorRequest();

      // Without trimming, rules would still pass because Max is inclusive,
      // but prepared() should have normalized whitespace out.
      final payload = request.validate({
        'name': '   Hello   ',
        'email': 'a@b.co',
      });

      expect(payload['name'], 'Hello');
    });

    test('throws AuthorizationException when authorize() returns false', () {
      final request = StoreMonitorRequest(canCreate: false);

      expect(
        () => request.validate({'name': 'x', 'email': 'a@b.co'}),
        throwsA(isA<AuthorizationException>()),
      );
    });

    test('throws ValidationException on rule failure', () {
      final request = StoreMonitorRequest();

      try {
        request.validate({'name': '', 'email': 'not-an-email'});
        fail('expected ValidationException');
      } on ValidationException catch (e) {
        expect(e.errors.containsKey('name'), isTrue);
        expect(e.errors.containsKey('email'), isTrue);
      }
    });

    test('authorize check runs before validation', () {
      // Bad data + unauthorized → authorize wins (short-circuit).
      final request = StoreMonitorRequest(canCreate: false);

      expect(
        () => request.validate({'name': '', 'email': 'bad'}),
        throwsA(isA<AuthorizationException>()),
      );
    });

    test('payload is filtered to the keys declared in rules', () {
      final request = StoreMonitorRequest();
      final payload = request.validate({
        'name': 'ok',
        'email': 'a@b.co',
        'extra': 'dropped',
      });

      expect(payload.containsKey('extra'), isFalse);
    });

    test('default authorize() returns true', () {
      final request = _MinimalRequest();
      expect(() => request.validate({'name': 'ok'}), returnsNormally);
    });
  });
}

class _MinimalRequest extends FormRequest {
  @override
  Map<String, List<Rule>> rules() => {
    'name': [Required()],
  };
}
