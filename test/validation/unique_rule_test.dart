import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

void main() {
  group('Unique rule (async)', () {
    test('passes when resolver reports unique', () async {
      final rule = Unique(
        '/validate/unique',
        field: 'slug',
        debounce: Duration.zero,
      ).via((_, _, _) async => true);

      final validator = Validator.make(
        {'slug': 'my-page'},
        {
          'slug': [rule],
        },
      );

      final validated = await validator.validateAsync();
      expect(validated, {'slug': 'my-page'});
    });

    test('fails when resolver reports taken', () async {
      final rule = Unique(
        '/validate/unique',
        field: 'slug',
        debounce: Duration.zero,
      ).via((_, _, _) async => false);

      final validator = Validator.make(
        {'slug': 'taken'},
        {
          'slug': [rule],
        },
      );

      await expectLater(
        validator.validateAsync(),
        throwsA(isA<ValidationException>()),
      );
      expect(validator.errors().keys, contains('slug'));
    });

    test('passes on network error and logs', () async {
      Log.fake();
      final rule = Unique(
        '/validate/unique',
        field: 'slug',
        debounce: Duration.zero,
      ).via((_, _, _) async => throw Exception('boom'));

      final validator = Validator.make(
        {'slug': 'x'},
        {
          'slug': [rule],
        },
      );

      final validated = await validator.validateAsync();
      expect(validated, {'slug': 'x'});
      Log.unfake();
    });

    test('sync rules short-circuit async rules', () async {
      var called = false;
      final unique =
          Unique(
            '/validate/unique',
            field: 'slug',
            debounce: Duration.zero,
          ).via((_, _, _) async {
            called = true;
            return true;
          });

      final validator = Validator.make(
        {'slug': ''},
        {
          'slug': [Required(), unique],
        },
      );

      await expectLater(
        validator.validateAsync(),
        throwsA(isA<ValidationException>()),
      );
      expect(called, isFalse, reason: 'Required must short-circuit Unique');
    });

    test('debounce coalesces rapid calls (stale calls pass)', () async {
      var calls = 0;
      final rule =
          Unique(
            '/validate/unique',
            field: 'slug',
            debounce: const Duration(milliseconds: 50),
          ).via((_, _, value) async {
            calls++;
            return value != 'taken';
          });

      final first = rule.passesAsync('slug', 'a', {});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final second = rule.passesAsync('slug', 'b', {});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final third = rule.passesAsync('slug', 'taken', {});

      final results = await Future.wait([first, second, third]);

      expect(calls, 1, reason: 'Only the last call should reach the resolver');
      expect(results[0], isTrue, reason: 'stale');
      expect(results[1], isTrue, reason: 'stale');
      expect(results[2], isFalse, reason: 'last call resolved with "taken"');
    });

    test('default resolver treats {"unique": true} as pass', () async {
      Http.fake({
        '/validate/unique*': Http.response({'unique': true}),
      });
      final rule = Unique(
        '/validate/unique',
        field: 'slug',
        debounce: Duration.zero,
      );

      expect(await rule.passesAsync('slug', 'available', {}), isTrue);
      Http.unfake();
    });

    test('default resolver treats {"unique": false} as fail', () async {
      Http.fake({
        '/validate/unique*': Http.response({'unique': false}),
      });
      final rule = Unique(
        '/validate/unique',
        field: 'slug',
        debounce: Duration.zero,
      );

      expect(await rule.passesAsync('slug', 'taken', {}), isFalse);
      Http.unfake();
    });
  });
}
