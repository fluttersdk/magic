import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

class _MapLoader implements TranslationLoader {
  _MapLoader(this._sentences);

  final Map<String, dynamic> _sentences;

  @override
  Future<Map<String, dynamic>> load(Locale locale) async =>
      Map<String, dynamic>.from(_sentences);
}

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

  group('FormRequest.attributes', () {
    setUp(() async {
      MagicApp.reset();
      Magic.flush();
      Translator.reset();

      Translator.instance.setLoader(
        _MapLoader(<String, dynamic>{
          'validation.required': 'The :attribute field is required.',
          'attributes.url': 'global url',
        }),
      );

      await Translator.instance.load(const Locale('en'));
    });

    test('default attributes() is empty', () {
      expect(_MinimalRequest().attributes(), isEmpty);
    });

    test('an override names the field in the error message', () {
      try {
        _LabelledRequest().validate({'url': ''});
        fail('expected ValidationException');
      } on ValidationException catch (e) {
        expect(e.errors['url'], 'The Server address field is required.');
      }
    });

    test('the override wins over the global attributes.<key> lookup', () {
      try {
        _LabelledRequest().validate({'url': '', 'name': ''});
        fail('expected ValidationException');
      } on ValidationException catch (e) {
        expect(e.errors['url'], isNot(contains('global url')));
      }
    });

    test('a field without an override falls back to the global name', () {
      try {
        _MapRequest(const <String, String>{}).validate({'url': ''});
        fail('expected ValidationException');
      } on ValidationException catch (e) {
        expect(e.errors['url'], 'The global url field is required.');
      }
    });

    test('a field absent from the override keeps its humanized name', () {
      try {
        _MapRequest(const <String, String>{
          'url': 'Server address',
        }).validate({'url': 'ok', 'display_name': ''});
        fail('expected ValidationException');
      } on ValidationException catch (e) {
        expect(e.errors['display_name'], 'The display name field is required.');
      }
    });
  });
}

class _LabelledRequest extends FormRequest {
  @override
  Map<String, List<Rule>> rules() => {
    'url': [Required()],
    'name': [Required()],
  };

  @override
  Map<String, String> attributes() => {'url': 'Server address'};
}

class _MapRequest extends FormRequest {
  const _MapRequest(this._attributes);

  final Map<String, String> _attributes;

  @override
  Map<String, List<Rule>> rules() => {
    'url': [Required()],
    'display_name': [Required()],
  };

  @override
  Map<String, String> attributes() => _attributes;
}

class _MinimalRequest extends FormRequest {
  @override
  Map<String, List<Rule>> rules() => {
    'name': [Required()],
  };
}
