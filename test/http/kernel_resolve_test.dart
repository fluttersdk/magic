import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

class _Allow extends MagicMiddleware {
  @override
  Future<void> handle(void Function() next) async => next();
}

void main() {
  group('Kernel.resolveAll', () {
    setUp(() {
      MagicApp.reset();
      Magic.flush();
      Kernel.flush();
    });

    tearDown(Kernel.flush);

    test('resolves a registered alias', () {
      Kernel.register('auth', _Allow.new);

      expect(Kernel.resolveAll(['auth']), hasLength(1));
    });

    test('resolves a factory and an instance without a registry entry', () {
      final instance = _Allow();

      expect(Kernel.resolveAll([_Allow.new, instance]), hasLength(2));
    });

    test('throws on an alias nothing registered', () {
      // The failure this exists to stop is silent rather than loud: an
      // unresolvable entry used to be dropped by `whereType`, so a route
      // declaring `middleware: ['auth']` against a Kernel that never got an
      // `auth` alias rendered with NO gate at all and said nothing. The
      // consequence of a missing gate is that everybody is let through, which
      // is the one failure mode that must not be quiet.
      expect(
        () => Kernel.resolveAll(['auth']),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('auth'), contains('Kernel.register')),
          ),
        ),
      );
    });

    test('names the unresolvable alias rather than the whole list', () {
      // A list of five with one typo is the realistic case, and a message
      // naming the list leaves the reader to spot it.
      Kernel.register('auth', _Allow.new);

      expect(
        () => Kernel.resolveAll(['auth', 'verified']),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('verified'),
          ),
        ),
      );
    });

    test(
      'throws on an entry that is neither an alias, a factory nor a middleware',
      () {
        expect(() => Kernel.resolveAll([42]), throwsA(isA<StateError>()));
      },
    );
  });
}
