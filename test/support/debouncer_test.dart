import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/support/debouncer.dart';

/// What this pins: [Debouncer.run] coalesces repeated calls under the same
/// key into a single delayed run of the LAST callback given, and
/// [Debouncer.cancelAll] drops every pending run without firing any of them.
void main() {
  group('Debouncer.run', () {
    test('three calls inside the window coalesce into one run', () async {
      int fired = 0;
      final Debouncer debouncer = Debouncer();

      debouncer.run('reload', const Duration(milliseconds: 30), () => fired++);
      debouncer.run('reload', const Duration(milliseconds: 30), () => fired++);
      debouncer.run('reload', const Duration(milliseconds: 30), () => fired++);

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(fired, equals(1));
    });

    test('the last call wins over the ones it superseded', () async {
      final List<String> fired = [];
      final Debouncer debouncer = Debouncer();

      debouncer.run(
        'reload',
        const Duration(milliseconds: 30),
        () => fired.add('first'),
      );
      debouncer.run(
        'reload',
        const Duration(milliseconds: 30),
        () => fired.add('second'),
      );

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(fired, equals(['second']));
    });

    test('different keys debounce independently', () async {
      final List<String> fired = [];
      final Debouncer debouncer = Debouncer();

      debouncer.run(
        'a',
        const Duration(milliseconds: 20),
        () => fired.add('a'),
      );
      debouncer.run(
        'b',
        const Duration(milliseconds: 20),
        () => fired.add('b'),
      );

      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(fired, containsAll(<String>['a', 'b']));
      expect(fired, hasLength(2));
    });
  });

  group('Debouncer.cancelAll', () {
    test('drops every pending run without firing it', () async {
      int fired = 0;
      final Debouncer debouncer = Debouncer();

      debouncer.run('reload', const Duration(milliseconds: 20), () => fired++);
      debouncer.cancelAll();

      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(fired, equals(0));
    });
  });
}
