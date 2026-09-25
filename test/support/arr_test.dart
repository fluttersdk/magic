import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/support/arr.dart';

/// What this pins: [Arr]'s dot-path semantics match Laravel's `Arr::get` /
/// `has` / `set` / `dot`, including the two precedence rules that are easy to
/// get backwards: an exact key wins over a walked path, and a numeric segment
/// indexes into a [List].
void main() {
  group('Arr.get', () {
    test('walks a dotted path through nested maps and lists', () {
      expect(
        Arr.get(<String, dynamic>{
          'a': <String, dynamic>{
            'b': <int>[10, 20],
          },
        }, 'a.b.1'),
        20,
      );
    });

    test('an exact key containing dots wins over walking the path', () {
      expect(
        Arr.get(<String, dynamic>{
          'a.b': 1,
          'a': <String, dynamic>{'b': 2},
        }, 'a.b'),
        1,
      );
    });

    test('answers the fallback when the path is unreachable', () {
      expect(Arr.get(<String, dynamic>{}, 'x', 'd'), 'd');
    });

    test('answers null fallback by default', () {
      expect(Arr.get(<String, dynamic>{}, 'x'), isNull);
    });

    test('a null path answers the whole map', () {
      final map = <String, dynamic>{'a': 1};
      expect(Arr.get(map, null), same(map));
    });

    test('a null map answers the fallback', () {
      expect(Arr.get(null, 'a', 'd'), 'd');
    });

    test('a non-numeric segment against a List answers the fallback', () {
      expect(
        Arr.get(
          <String, dynamic>{
            'a': <int>[1, 2],
          },
          'a.x',
          'd',
        ),
        'd',
      );
    });
  });

  group('Arr.has', () {
    test('true for a reachable dotted path', () {
      expect(
        Arr.has(<String, dynamic>{
          'a': <String, dynamic>{'b': 1},
        }, 'a.b'),
        isTrue,
      );
    });

    test('false for an unreachable path', () {
      expect(Arr.has(<String, dynamic>{}, 'a.b'), isFalse);
    });

    test('true for a null leaf value that is genuinely present', () {
      expect(
        Arr.has(<String, dynamic>{
          'a': <String, dynamic>{'b': null},
        }, 'a.b'),
        isTrue,
      );
    });
  });

  group('Arr.set', () {
    test('creates nested maps along the path', () {
      final map = <String, dynamic>{};
      Arr.set(map, 'a.b.c', 1);
      expect(map, <String, dynamic>{
        'a': <String, dynamic>{
          'b': <String, dynamic>{'c': 1},
        },
      });
    });

    test('overwrites a non-map value blocking the path', () {
      final map = <String, dynamic>{'a': 1};
      Arr.set(map, 'a.b', 2);
      expect(map, <String, dynamic>{
        'a': <String, dynamic>{'b': 2},
      });
    });

    test('a single-segment path sets the top-level key', () {
      final map = <String, dynamic>{};
      Arr.set(map, 'a', 1);
      expect(map, <String, dynamic>{'a': 1});
    });
  });

  group('Arr.dot', () {
    test('flattens a nested map with dotted keys', () {
      expect(
        Arr.dot(<String, dynamic>{
          'a': <String, dynamic>{'b': 1},
        }),
        <String, dynamic>{'a.b': 1},
      );
    });

    test('prepends a given prefix', () {
      expect(
        Arr.dot(<String, dynamic>{'b': 1}, prepend: 'a.'),
        <String, dynamic>{'a.b': 1},
      );
    });

    test('keeps an empty nested map as a leaf rather than dropping it', () {
      expect(
        Arr.dot(<String, dynamic>{'a': <String, dynamic>{}}),
        <String, dynamic>{'a': <String, dynamic>{}},
      );
    });
  });
}
