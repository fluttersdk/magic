import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Session.reset();
  });

  group('SessionStore flash lifecycle', () {
    test('flash values are not readable until tick', () {
      Session.flash({'email': 'john@test.com'});
      expect(Session.old('email'), isNull);
      Session.tick();
      expect(Session.old('email'), equals('john@test.com'));
    });

    test('flash survives exactly one tick', () {
      Session.flash({'email': 'john@test.com'});
      Session.tick();
      expect(Session.old('email'), equals('john@test.com'));
      Session.tick();
      expect(Session.old('email'), isNull);
    });

    test('old() returns fallback when no flash', () {
      expect(Session.old('missing', 'fallback'), equals('fallback'));
    });

    test('old() distinguishes unset from explicit null', () {
      Session.flash({'name': null});
      Session.tick();
      expect(Session.old('name', 'fallback'), isNull);
      expect(Session.old('missing', 'fallback'), equals('fallback'));
    });

    test('hasError is false when flashed error list is empty', () {
      Session.flashErrors({'email': const <String>[]});
      Session.tick();
      expect(Session.hasError('email'), isFalse);
      expect(Session.error('email'), isNull);
    });

    test('oldRaw preserves original type', () {
      Session.flash({'accept': true, 'age': 42});
      Session.tick();
      expect(Session.oldRaw('accept'), isTrue);
      expect(Session.oldRaw('age'), equals(42));
      expect(Session.old('accept'), equals('true'));
    });

    test('flashErrors surfaces on next frame', () {
      Session.flashErrors({
        'email': ['Invalid email.'],
      });
      expect(Session.error('email'), isNull);
      Session.tick();
      expect(Session.error('email'), equals('Invalid email.'));
      expect(Session.hasError('email'), isTrue);
      expect(Session.errors('email'), equals(['Invalid email.']));
    });

    test('errors() returns empty list for unknown field', () {
      expect(Session.errors('missing'), isEmpty);
    });

    test('hasFlash reflects current bucket', () {
      expect(Session.hasFlash, isFalse);
      Session.flash({'email': 'x'});
      expect(Session.hasFlash, isFalse);
      Session.tick();
      expect(Session.hasFlash, isTrue);
      Session.tick();
      expect(Session.hasFlash, isFalse);
    });

    test('reset wipes both buckets', () {
      Session.flash({'email': 'x'});
      Session.tick();
      Session.flash({'name': 'y'});
      Session.reset();
      expect(Session.hasFlash, isFalse);
      expect(Session.old('email'), isNull);
      Session.tick();
      expect(Session.old('name'), isNull);
    });

    test('top-level old() helper mirrors facade', () {
      Session.flash({'email': 'hi@test.com'});
      Session.tick();
      expect(old('email'), equals('hi@test.com'));
      expect(old('missing', 'fb'), equals('fb'));
    });

    test('top-level error() helper mirrors facade', () {
      Session.flashErrors({
        'email': ['Bad.'],
      });
      Session.tick();
      expect(error('email'), equals('Bad.'));
    });

    test('setStore swaps backing store', () {
      final custom = SessionStore();
      Session.setStore(custom);
      custom.flash({'k': 'v'});
      custom.tick();
      expect(Session.old('k'), equals('v'));
    });
  });

  group('MagicFormData auto-flash integration', () {
    testWidgets('validate() flashes form data on failure', (tester) async {
      final form = MagicFormData({'email': 'not-an-email'});

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MagicForm(
              formData: form,
              child: TextFormField(
                controller: form['email'],
                validator: (v) =>
                    v != null && v.contains('@') ? null : 'Invalid email.',
              ),
            ),
          ),
        ),
      );

      expect(form.validate(), isFalse);
      Session.tick();
      expect(Session.old('email'), equals('not-an-email'));
    });

    testWidgets('validate() does not flash on success', (tester) async {
      final form = MagicFormData({'email': 'ok@test.com'});

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MagicForm(
              formData: form,
              child: TextFormField(
                controller: form['email'],
                validator: (v) =>
                    v != null && v.contains('@') ? null : 'Invalid email.',
              ),
            ),
          ),
        ),
      );

      expect(form.validate(), isTrue);
      Session.tick();
      expect(Session.hasFlash, isFalse);
    });
  });
}
