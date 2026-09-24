import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

class Monitor extends Model {
  @override
  String get table => 'monitors';

  @override
  String get resource => 'monitors';

  @override
  List<String> get fillable => ['name'];
}

class Locked extends Model {
  @override
  String get table => 'locked';

  @override
  String get resource => 'locked';
}

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  tearDown(Model.reguard);

  group('Model.unguarded', () {
    test('fill keeps non-fillable keys inside the callback', () {
      final monitor = Model.unguarded(
        () => Monitor()
          ..fill({
            'id': 1,
            'name': 'API',
            'last_status': 'up',
          }),
      );

      expect(monitor.id, 1);
      expect(monitor.getAttribute('name'), 'API');
      expect(monitor.getAttribute('last_status'), 'up');
    });

    test('fill keeps keys on a model guarded with *', () {
      final locked = Model.unguarded(() => Locked()..fill({'id': 7}));

      expect(locked.id, 7);
    });

    test('fill outside the callback still drops non-fillable keys', () {
      Model.unguarded(() => Monitor()..fill({'id': 1}));

      final monitor = Monitor()..fill({'id': 1, 'name': 'API'});

      expect(monitor.id, isNull);
      expect(monitor.getAttribute('name'), 'API');
    });

    test('strict fill outside the callback still throws', () {
      Model.unguarded(() => Monitor()..fill({'id': 1}));

      expect(
        () => Monitor().fill({'id': 1}, strict: true),
        throwsA(isA<MassAssignmentException>()),
      );
    });

    test('returns the callback result', () {
      expect(Model.unguarded(() => 42), 42);
    });

    test('is unguarded during the callback and guarded after it returns', () {
      expect(Model.isUnguarded, isFalse);

      final during = Model.unguarded(() => Model.isUnguarded);

      expect(during, isTrue);
      expect(Model.isUnguarded, isFalse);
    });

    test('restores the guard when the callback throws', () {
      expect(
        () => Model.unguarded<void>(() => throw StateError('boom')),
        throwsStateError,
      );

      expect(Model.isUnguarded, isFalse);
    });

    test('a nested call leaves the outer call unguarded', () {
      final afterInner = Model.unguarded(() {
        Model.unguarded(() => null);

        return Model.isUnguarded;
      });

      expect(afterInner, isTrue);
      expect(Model.isUnguarded, isFalse);
    });

    test('an async callback fails the assertion and restores the guard', () {
      expect(
        () => Model.unguarded(() async {
          await Future<void>.delayed(Duration.zero);
        }),
        throwsA(isA<AssertionError>()),
      );

      expect(Model.isUnguarded, isFalse);
    });
  });

  group('Model.unguard / reguard', () {
    test('unguard switches the guard off until reguard', () {
      Model.unguard();

      expect(Model.isUnguarded, isTrue);
      expect((Monitor()..fill({'id': 3})).id, 3);

      Model.reguard();

      expect(Model.isUnguarded, isFalse);
      expect((Monitor()..fill({'id': 3})).id, isNull);
    });

    test('unguard(false) switches the guard back on', () {
      Model.unguard();
      Model.unguard(false);

      expect(Model.isUnguarded, isFalse);
    });

    test('unguarded inside a global unguard leaves it unguarded', () {
      Model.unguard();

      Model.unguarded(() => null);

      expect(Model.isUnguarded, isTrue);
    });

    test(
      'unguarded inside a global unguard still fails on an async callback',
      () {
        Model.unguard();

        expect(
          () => Model.unguarded(() async {
            await Future<void>.delayed(Duration.zero);
          }),
          throwsA(isA<AssertionError>()),
        );
      },
    );
  });
}
