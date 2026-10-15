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

Future<void> _loadCatalogue() async {
  Translator.reset();
  Translator.instance.setLoader(
    _MapLoader(<String, dynamic>{
      'validation.required': 'The :attribute field is required.',
    }),
  );
  await Translator.instance.load(const Locale('en'));
}

/// Requires `name` and labels it through [FormRequest.attributes].
class _LabelledNameRequest extends FormRequest {
  const _LabelledNameRequest();

  @override
  Map<String, List<Rule>> rules() => {
    'name': [Required()],
  };

  @override
  Map<String, String> attributes() => {'name': 'Source name'};
}

/// Requires `name`, mirroring the shape a real write path validates against
/// before ever reaching [MagicFormObject.persist].
class _NameRequest extends FormRequest {
  const _NameRequest();

  @override
  Map<String, List<Rule>> rules() => {
    'name': [Required()],
  };
}

/// Minimal [MagicFormObject]: one text field, one client rule, and a
/// [persist] the test controls the outcome of.
class _TestForm extends MagicFormObject {
  _TestForm({this.onPersist, this.formRequest = const _NameRequest()});

  final FormRequest formRequest;

  final Future<bool> Function(Map<String, dynamic> validated)? onPersist;

  bool persistCalled = false;

  @override
  Map<String, dynamic> get initial => {'name': 'Seed', 'email': ''};

  @override
  FormRequest get request => formRequest;

  @override
  Future<bool> persist(Map<String, dynamic> validated) async {
    persistCalled = true;
    if (onPersist != null) return onPersist!(validated);
    return true;
  }
}

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  test('initial seeds data with the declared fields', () {
    final form = _TestForm();

    expect(form.data.get('name'), 'Seed');
    expect(form.data.get('email'), '');

    form.dispose();
  });

  group('submit, client-side rule failure', () {
    test('stops before persist and exposes the error via getError', () async {
      final form = _TestForm();
      form.data.set('name', '');

      final ok = await form.submit();

      expect(ok, isFalse);
      expect(form.persistCalled, isFalse);
      expect(form.getError('name'), isNotNull);

      form.dispose();
    });
  });

  group('submit, FormRequest.attributes', () {
    setUp(_loadCatalogue);

    test('the request\'s attribute name reaches the field error', () async {
      final form = _TestForm(formRequest: const _LabelledNameRequest());
      form.data.set('name', '');

      final ok = await form.submit();

      expect(ok, isFalse);
      expect(form.getError('name'), 'The Source name field is required.');

      form.dispose();
    });
  });

  group('submit, persist', () {
    test(
      'runs persist with the validated payload and returns its result',
      () async {
        Map<String, dynamic>? seen;
        final form = _TestForm(
          onPersist: (validated) async {
            seen = validated;
            return true;
          },
        );

        final ok = await form.submit();

        expect(ok, isTrue);
        expect(form.persistCalled, isTrue);
        expect(seen, containsPair('name', 'Seed'));

        form.dispose();
      },
    );

    test('a ValidationException thrown by persist lands on getError', () async {
      final form = _TestForm(
        onPersist: (_) async =>
            throw ValidationException({'name': 'Already taken.'}),
      );

      final ok = await form.submit();

      expect(ok, isFalse);
      expect(form.getError('name'), 'Already taken.');

      form.dispose();
    });

    test('typing into data clears the field error a 422 left behind', () async {
      final form = _TestForm(
        onPersist: (_) async =>
            throw ValidationException({'name': 'Already taken.'}),
      );

      await form.submit();
      expect(form.getError('name'), isNotNull);

      form.data.set('name', 'x');

      expect(form.getError('name'), isNull);

      form.dispose();
    });
  });

  group('lifecycle', () {
    test(
      'dispose asserts the form was never registered in Magic.controllers',
      () {
        final form = _TestForm();
        Magic.put(form);

        expect(() => form.dispose(), throwsA(isA<AssertionError>()));
      },
    );

    test('a form created per State (never put) disposes cleanly', () {
      final form = _TestForm();

      expect(form.dispose, returnsNormally);
    });
  });
}
