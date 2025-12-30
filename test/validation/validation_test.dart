import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_magic/src/localization/translator.dart';
import 'package:fluttersdk_magic/src/localization/contracts/translation_loader.dart';
import 'package:fluttersdk_magic/src/validation/contracts/rule.dart';
import 'package:fluttersdk_magic/src/validation/rules/required.dart';
import 'package:fluttersdk_magic/src/validation/rules/email.dart';
import 'package:fluttersdk_magic/src/validation/rules/min.dart';
import 'package:fluttersdk_magic/src/validation/rules/max.dart';
import 'package:fluttersdk_magic/src/validation/rules/confirmed.dart';
import 'package:fluttersdk_magic/src/validation/rules/same.dart';
import 'package:fluttersdk_magic/src/validation/rules/accepted.dart';
import 'package:fluttersdk_magic/src/validation/exceptions/validation_exception.dart';
import 'package:fluttersdk_magic/src/validation/validator.dart';

/// Mock loader for testing with validation messages.
class MockTranslationLoader implements TranslationLoader {
  @override
  Future<Map<String, dynamic>> load(Locale locale) async {
    return {
      'validation.required': 'The :attribute field is required.',
      'validation.email': 'The :attribute must be a valid email address.',
      'validation.min.string':
          'The :attribute must be at least :min characters.',
      'validation.max.string':
          'The :attribute must not be greater than :max characters.',
      'validation.confirmed': 'The :attribute confirmation does not match.',
      'validation.same': 'The :attribute and :other must match.',
      'validation.accepted': 'The :attribute must be accepted.',
    };
  }
}

void main() {
  // Global setup for all tests - load translator once
  setUpAll(() async {
    Translator.reset();
    final translator = Translator.instance;
    translator.setLoader(MockTranslationLoader());
    await translator.load(const Locale('en'));
  });

  // Don't reset between tests - only reset at the very end
  tearDownAll(() {
    Translator.reset();
  });

  // ---------------------------------------------------------------------------
  // Rule Tests
  // ---------------------------------------------------------------------------

  group('Required Rule', () {
    late Required rule;

    setUp(() {
      rule = Required();
    });

    test('passes with non-empty string', () {
      expect(rule.passes('name', 'John', {}), isTrue);
    });

    test('fails with null', () {
      expect(rule.passes('name', null, {}), isFalse);
    });

    test('fails with empty string', () {
      expect(rule.passes('name', '', {}), isFalse);
    });

    test('fails with whitespace-only string', () {
      expect(rule.passes('name', '   ', {}), isFalse);
    });

    test('passes with non-empty list', () {
      expect(rule.passes('items', [1, 2, 3], {}), isTrue);
    });

    test('fails with empty list', () {
      expect(rule.passes('items', [], {}), isFalse);
    });

    test('passes with non-empty map', () {
      expect(rule.passes('data', {'key': 'value'}, {}), isTrue);
    });

    test('fails with empty map', () {
      expect(rule.passes('data', {}, {}), isFalse);
    });

    test('passes with boolean true', () {
      expect(rule.passes('active', true, {}), isTrue);
    });

    test('fails with boolean false (like unchecked checkbox)', () {
      expect(rule.passes('active', false, {}), isFalse);
    });

    test('returns correct message key', () {
      expect(rule.message(), 'validation.required');
    });
  });

  group('Email Rule', () {
    late Email rule;

    setUp(() {
      rule = Email();
    });

    test('passes with valid email', () {
      expect(rule.passes('email', 'user@example.com', {}), isTrue);
    });

    test('passes with valid email containing dots', () {
      expect(rule.passes('email', 'user.name@example.co.uk', {}), isTrue);
    });

    test('passes with valid email containing plus', () {
      expect(rule.passes('email', 'user+tag@example.com', {}), isTrue);
    });

    test('fails with invalid email - no @', () {
      expect(rule.passes('email', 'userexample.com', {}), isFalse);
    });

    test('fails with invalid email - no domain', () {
      expect(rule.passes('email', 'user@', {}), isFalse);
    });

    test('fails with invalid email - no TLD', () {
      expect(rule.passes('email', 'user@example', {}), isFalse);
    });

    test('passes with null (let Required handle)', () {
      expect(rule.passes('email', null, {}), isTrue);
    });

    test('passes with empty (let Required handle)', () {
      expect(rule.passes('email', '', {}), isTrue);
    });

    test('fails with non-string', () {
      expect(rule.passes('email', 123, {}), isFalse);
    });

    test('returns correct message key', () {
      expect(rule.message(), 'validation.email');
    });
  });

  group('Min Rule', () {
    test('passes with string at exactly min length', () {
      final rule = Min(5);
      expect(rule.passes('name', 'hello', {}), isTrue);
    });

    test('passes with string above min length', () {
      final rule = Min(5);
      expect(rule.passes('name', 'hello world', {}), isTrue);
    });

    test('fails with string below min length', () {
      final rule = Min(5);
      expect(rule.passes('name', 'hi', {}), isFalse);
    });

    test('passes with number at exactly min value', () {
      final rule = Min(18);
      expect(rule.passes('age', 18, {}), isTrue);
    });

    test('passes with number above min value', () {
      final rule = Min(18);
      expect(rule.passes('age', 25, {}), isTrue);
    });

    test('fails with number below min value', () {
      final rule = Min(18);
      expect(rule.passes('age', 15, {}), isFalse);
    });

    test('passes with list at exactly min count', () {
      final rule = Min(3);
      expect(rule.passes('items', [1, 2, 3], {}), isTrue);
    });

    test('fails with list below min count', () {
      final rule = Min(3);
      expect(rule.passes('items', [1], {}), isFalse);
    });

    test('passes with null (let Required handle)', () {
      final rule = Min(5);
      expect(rule.passes('name', null, {}), isTrue);
    });

    test('passes with empty string (let Required handle)', () {
      final rule = Min(5);
      expect(rule.passes('name', '', {}), isTrue);
    });

    test('returns correct message key and params', () {
      final rule = Min(8);
      expect(rule.message(), 'validation.min.string');
      expect(rule.params(), {'min': 8});
    });
  });

  group('Max Rule', () {
    test('passes with string at exactly max length', () {
      final rule = Max(5);
      expect(rule.passes('name', 'hello', {}), isTrue);
    });

    test('passes with string below max length', () {
      final rule = Max(5);
      expect(rule.passes('name', 'hi', {}), isTrue);
    });

    test('fails with string above max length', () {
      final rule = Max(5);
      expect(rule.passes('name', 'hello world', {}), isFalse);
    });

    test('passes with number at exactly max value', () {
      final rule = Max(100);
      expect(rule.passes('quantity', 100, {}), isTrue);
    });

    test('fails with number above max value', () {
      final rule = Max(100);
      expect(rule.passes('quantity', 150, {}), isFalse);
    });

    test('passes with list at exactly max count', () {
      final rule = Max(3);
      expect(rule.passes('items', [1, 2, 3], {}), isTrue);
    });

    test('fails with list above max count', () {
      final rule = Max(3);
      expect(rule.passes('items', [1, 2, 3, 4], {}), isFalse);
    });

    test('returns correct message key and params', () {
      final rule = Max(20);
      expect(rule.message(), 'validation.max.string');
      expect(rule.params(), {'max': 20});
    });
  });

  group('Confirmed Rule', () {
    late Confirmed rule;

    setUp(() {
      rule = Confirmed();
    });

    test('passes when confirmation matches', () {
      expect(
        rule.passes('password', 'secret', {
          'password': 'secret',
          'password_confirmation': 'secret',
        }),
        isTrue,
      );
    });

    test('fails when confirmation does not match', () {
      expect(
        rule.passes('password', 'secret', {
          'password': 'secret',
          'password_confirmation': 'different',
        }),
        isFalse,
      );
    });

    test('fails when confirmation is missing', () {
      expect(
        rule.passes('password', 'secret', {
          'password': 'secret',
        }),
        isFalse,
      );
    });

    test('passes with null (let Required handle)', () {
      expect(rule.passes('password', null, {}), isTrue);
    });

    test('returns correct message key', () {
      expect(rule.message(), 'validation.confirmed');
    });
  });

  group('Same Rule', () {
    test('passes when fields match', () {
      final rule = Same('email');
      expect(
        rule.passes('email_confirm', 'user@example.com', {
          'email': 'user@example.com',
          'email_confirm': 'user@example.com',
        }),
        isTrue,
      );
    });

    test('fails when fields do not match', () {
      final rule = Same('email');
      expect(
        rule.passes('email_confirm', 'different@example.com', {
          'email': 'user@example.com',
          'email_confirm': 'different@example.com',
        }),
        isFalse,
      );
    });

    test('fails when other field is missing', () {
      final rule = Same('email');
      expect(
        rule.passes('email_confirm', 'user@example.com', {
          'email_confirm': 'user@example.com',
        }),
        isFalse,
      );
    });

    test('passes with null (let Required handle)', () {
      final rule = Same('email');
      expect(rule.passes('email_confirm', null, {}), isTrue);
    });

    test('returns correct message key and params', () {
      final rule = Same('email');
      expect(rule.message(), 'validation.same');
      expect(rule.params(), {'other': 'email'});
    });
  });

  group('Accepted Rule', () {
    late Accepted rule;

    setUp(() {
      rule = Accepted();
    });

    test('passes with boolean true', () {
      expect(rule.passes('terms', true, {}), isTrue);
    });

    test('passes with integer 1', () {
      expect(rule.passes('terms', 1, {}), isTrue);
    });

    test('passes with string "1"', () {
      expect(rule.passes('terms', '1', {}), isTrue);
    });

    test('passes with string "yes"', () {
      expect(rule.passes('terms', 'yes', {}), isTrue);
    });

    test('passes with string "YES" (case-insensitive)', () {
      expect(rule.passes('terms', 'YES', {}), isTrue);
    });

    test('passes with string "on"', () {
      expect(rule.passes('terms', 'on', {}), isTrue);
    });

    test('passes with string "true"', () {
      expect(rule.passes('terms', 'true', {}), isTrue);
    });

    test('fails with boolean false', () {
      expect(rule.passes('terms', false, {}), isFalse);
    });

    test('fails with integer 0', () {
      expect(rule.passes('terms', 0, {}), isFalse);
    });

    test('fails with string "no"', () {
      expect(rule.passes('terms', 'no', {}), isFalse);
    });

    test('fails with null', () {
      expect(rule.passes('terms', null, {}), isFalse);
    });

    test('returns correct message key', () {
      expect(rule.message(), 'validation.accepted');
    });
  });

  // ---------------------------------------------------------------------------
  // Validator Tests
  // ---------------------------------------------------------------------------

  group('Validator', () {
    test('passes() returns true when all rules pass', () {
      final validator = Validator.make({
        'email': 'user@example.com',
        'password': 'secret123',
      }, {
        'email': [Required(), Email()],
        'password': [Required(), Min(6)],
      });

      expect(validator.passes(), isTrue);
      expect(validator.fails(), isFalse);
      expect(validator.errors(), isEmpty);
    });

    test('fails() returns true when any rule fails', () {
      final validator = Validator.make({
        'email': 'invalid-email',
        'password': '123',
      }, {
        'email': [Required(), Email()],
        'password': [Required(), Min(6)],
      });

      expect(validator.fails(), isTrue);
      expect(validator.passes(), isFalse);
      expect(validator.errors(), isNotEmpty);
    });

    test('errors() returns correct messages', () {
      final validator = Validator.make({
        'email': '',
        'password': '123',
      }, {
        'email': [Required()],
        'password': [Required(), Min(8)],
      });

      validator.fails();
      final errors = validator.errors();

      expect(errors['email'], contains('required'));
      expect(errors['password'], contains('8'));
    });

    test('validate() returns validated data when passing', () {
      final validator = Validator.make({
        'email': 'user@example.com',
        'password': 'secret123',
        'extra': 'data',
      }, {
        'email': [Required(), Email()],
        'password': [Required()],
      });

      final validated = validator.validate();

      expect(validated['email'], 'user@example.com');
      expect(validated['password'], 'secret123');
      expect(validated.containsKey('extra'), isFalse);
    });

    test('validate() throws ValidationException when failing', () {
      final validator = Validator.make({
        'email': '',
      }, {
        'email': [Required()],
      });

      expect(
        () => validator.validate(),
        throwsA(isA<ValidationException>()),
      );
    });

    test('only first error per field is recorded', () {
      final validator = Validator.make({
        'email': '',
      }, {
        'email': [Required(), Email()],
      });

      validator.fails();
      final errors = validator.errors();

      expect(errors.length, 1);
      expect(errors['email'], contains('required'));
    });

    test('stops validation on first failure per field', () {
      var emailRuleCalls = 0;

      final validator = Validator.make({
        'email': '',
      }, {
        'email': [
          Required(),
          _CountingRule(() => emailRuleCalls++),
        ],
      });

      validator.fails();

      expect(emailRuleCalls, 0); // Email rule should not be called
    });
  });

  // ---------------------------------------------------------------------------
  // ValidationException Tests
  // ---------------------------------------------------------------------------

  group('ValidationException', () {
    test('contains errors map', () {
      final errors = {'email': 'Invalid email', 'password': 'Too short'};
      final exception = ValidationException(errors);

      expect(exception.errors, errors);
    });

    test('toString() formats errors nicely', () {
      final exception = ValidationException({
        'email': 'Invalid email',
        'password': 'Too short',
      });

      final str = exception.toString();

      expect(str, contains('ValidationException'));
      expect(str, contains('email'));
      expect(str, contains('Invalid email'));
    });

    test('toString() handles empty errors', () {
      final exception = ValidationException({});

      expect(exception.toString(), contains('No errors'));
    });
  });

  // ---------------------------------------------------------------------------
  // Message Resolution Tests
  // ---------------------------------------------------------------------------

  group('Message Resolution', () {
    test('uses Lang translation when key exists', () {
      final validator = Validator.make({
        'email': '',
      }, {
        'email': [Required()],
      });

      validator.fails();
      final errors = validator.errors();

      expect(errors['email'], 'The email field is required.');
    });

    test('uses raw message when key does not exist', () {
      final validator = Validator.make({
        'name': 'invalid',
      }, {
        'name': [_CustomRawRule()],
      });

      validator.fails();
      final errors = validator.errors();

      expect(errors['name'], 'This is a custom raw message for name.');
    });

    test('replaces :attribute placeholder', () {
      final validator = Validator.make({
        'user_email': '',
      }, {
        'user_email': [Required()],
      });

      validator.fails();
      final errors = validator.errors();

      expect(errors['user_email'], contains('user email'));
    });

    test('replaces rule params in message', () {
      final validator = Validator.make({
        'password': 'abc',
      }, {
        'password': [Min(8)],
      });

      validator.fails();
      final errors = validator.errors();

      expect(errors['password'], contains('8'));
    });
  });
}

/// Helper rule that counts calls.
class _CountingRule extends Rule {
  final void Function() onCall;

  _CountingRule(this.onCall);

  @override
  bool passes(String attribute, dynamic value, Map<String, dynamic> data) {
    onCall();
    return true;
  }

  @override
  String message() => 'counting';
}

/// Helper rule that returns a raw message (not a Lang key).
class _CustomRawRule extends Rule {
  @override
  bool passes(String attribute, dynamic value, Map<String, dynamic> data) {
    return false;
  }

  @override
  String message() => 'This is a custom raw message for :attribute.';
}
