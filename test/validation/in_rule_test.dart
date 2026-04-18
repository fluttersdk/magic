import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/localization/translator.dart';
import 'package:magic/src/localization/contracts/translation_loader.dart';
import 'package:magic/src/validation/rules/in_rule.dart';
import 'package:magic/src/validation/rules/required.dart';
import 'package:magic/src/validation/validator.dart';

enum IncidentSeverity { low, medium, high, critical }

enum ThresholdDirection { highBad, lowBad }

class _MockLoader implements TranslationLoader {
  @override
  Future<Map<String, dynamic>> load(Locale locale) async => {
    'validation.in': 'The :attribute must be one of :values.',
    'validation.required': 'The :attribute field is required.',
  };
}

void main() {
  setUpAll(() async {
    Translator.reset();
    Translator.instance.setLoader(_MockLoader());
    await Translator.instance.load(const Locale('en'));
  });

  tearDownAll(Translator.reset);

  group('In<T>', () {
    test('passes when value is in the whitelist (String)', () {
      final rule = In<String>(['public', 'private']);
      expect(rule.passes('visibility', 'public', {}), isTrue);
      expect(rule.passes('visibility', 'private', {}), isTrue);
    });

    test('fails when value is not in the whitelist (String)', () {
      final rule = In<String>(['public', 'private']);
      expect(rule.passes('visibility', 'unlisted', {}), isFalse);
    });

    test('passes with primitive int whitelist', () {
      final rule = In<int>([1, 2, 3, 5, 8]);
      expect(rule.passes('priority', 5, {}), isTrue);
      expect(rule.passes('priority', 4, {}), isFalse);
    });

    test('null passes (let Required handle null)', () {
      final rule = In<String>(['a', 'b']);
      expect(rule.passes('field', null, {}), isTrue);
    });

    test('type mismatch fails (int value against String whitelist)', () {
      final rule = In<String>(['1', '2']);
      expect(rule.passes('field', 1, {}), isFalse);
    });

    test('message key is validation.in', () {
      expect(In<String>(['a']).message(), 'validation.in');
    });

    test('params expose comma-joined :values', () {
      final rule = In<String>(['public', 'private']);
      expect(rule.params()['values'], 'public, private');
    });

    test('integrates with Validator and resolves :values in message', () {
      final v = Validator.make(
        {'visibility': 'unlisted'},
        {
          'visibility': [
            In<String>(['public', 'private']),
          ],
        },
      );
      expect(v.fails(), isTrue);
      expect(
        v.errors()['visibility'],
        'The visibility must be one of public, private.',
      );
    });

    test('Required runs before In (null short-circuits at Required)', () {
      final v = Validator.make(
        {'visibility': null},
        {
          'visibility': [
            Required(),
            In<String>(['public']),
          ],
        },
      );
      expect(v.errors()['visibility'], contains('required'));
    });
  });

  group('InList<T extends Enum>', () {
    test('passes when inbound string matches an enum .name', () {
      final rule = InList(IncidentSeverity.values);
      expect(rule.passes('severity', 'high', {}), isTrue);
      expect(rule.passes('severity', 'critical', {}), isTrue);
    });

    test('fails when inbound string does not match any enum .name', () {
      final rule = InList(IncidentSeverity.values);
      expect(rule.passes('severity', 'urgent', {}), isFalse);
    });

    test('passes when inbound value is the enum itself', () {
      final rule = InList(IncidentSeverity.values);
      expect(rule.passes('severity', IncidentSeverity.low, {}), isTrue);
    });

    test('case-sensitive by default', () {
      final rule = InList(IncidentSeverity.values);
      expect(rule.passes('severity', 'High', {}), isFalse);
    });

    test('caseInsensitive: true matches regardless of case', () {
      final rule = InList(IncidentSeverity.values, caseInsensitive: true);
      expect(rule.passes('severity', 'HIGH', {}), isTrue);
      expect(rule.passes('severity', 'Critical', {}), isTrue);
    });

    test('wire mapper overrides .name comparison', () {
      final rule = InList<ThresholdDirection>(
        ThresholdDirection.values,
        wire: (d) => switch (d) {
          ThresholdDirection.highBad => 'high_bad',
          ThresholdDirection.lowBad => 'low_bad',
        },
      );
      expect(rule.passes('direction', 'high_bad', {}), isTrue);
      expect(rule.passes('direction', 'low_bad', {}), isTrue);
      expect(rule.passes('direction', 'highBad', {}), isFalse);
    });

    test('wire mapper + caseInsensitive combine', () {
      final rule = InList<ThresholdDirection>(
        ThresholdDirection.values,
        caseInsensitive: true,
        wire: (d) => switch (d) {
          ThresholdDirection.highBad => 'high_bad',
          ThresholdDirection.lowBad => 'low_bad',
        },
      );
      expect(rule.passes('direction', 'HIGH_BAD', {}), isTrue);
    });

    test('null passes (let Required handle null)', () {
      final rule = InList(IncidentSeverity.values);
      expect(rule.passes('severity', null, {}), isTrue);
    });

    test('message key is validation.in', () {
      expect(InList(IncidentSeverity.values).message(), 'validation.in');
    });

    test('params expose :values using .name by default', () {
      final rule = InList(IncidentSeverity.values);
      expect(rule.params()['values'], 'low, medium, high, critical');
    });

    test('params expose :values using wire mapper when provided', () {
      final rule = InList<ThresholdDirection>(
        ThresholdDirection.values,
        wire: (d) => switch (d) {
          ThresholdDirection.highBad => 'high_bad',
          ThresholdDirection.lowBad => 'low_bad',
        },
      );
      expect(rule.params()['values'], 'high_bad, low_bad');
    });

    test('integrates with Validator end-to-end', () {
      final v = Validator.make(
        {'severity': 'urgent'},
        {
          'severity': [InList(IncidentSeverity.values)],
        },
      );
      expect(v.fails(), isTrue);
      expect(
        v.errors()['severity'],
        'The severity must be one of low, medium, high, critical.',
      );
    });
  });
}
