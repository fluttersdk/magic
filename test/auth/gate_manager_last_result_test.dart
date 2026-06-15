import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// Tests for [GateManager.lastResult] + the bounded MRU cache it backs
/// (Plan Step 17, sub-change b-ii through b-v).
///
/// Contract:
/// - `lastResult(ability)` returns null when the ability was never checked.
/// - After a single `allows`/`denies` call, `lastResult` returns the
///   corresponding [GateResult].
/// - The cache is bounded at 64 entries; on overflow, the least-recently
///   written ability is evicted.
/// - Within a single microtask cycle two synchronous checks update the
///   cache in call order (the second overwrites the first per ability).
class _CacheUser extends Model with Authenticatable {
  @override
  String get table => 'users';
  @override
  String get resource => 'users';
  @override
  List<String> get fillable => ['id', 'name'];
}

_CacheUser _user({int id = 1, String name = 'Alice'}) {
  final u = _CacheUser();
  u.fill({'id': id, 'name': name});
  u.exists = true;
  return u;
}

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Gate.manager.flush();
  });

  tearDown(() {
    Auth.unfake();
    Gate.manager.flush();
  });

  group('GateManager.lastResult', () {
    test('returns null when the ability has never been checked', () {
      Auth.fake(user: _user());

      expect(Gate.manager.lastResult('never-checked'), isNull);
    });

    test('returns a populated GateResult after a single allows() call', () {
      Auth.fake(user: _user());
      Gate.define('view-dashboard', (user, _) => true);

      final before = DateTime.now();
      final allowed = Gate.allows('view-dashboard');
      final after = DateTime.now();

      expect(allowed, isTrue);

      final cached = Gate.manager.lastResult('view-dashboard');
      expect(cached, isNotNull);
      expect(cached!.ability, 'view-dashboard');
      expect(cached.allowed, isTrue);
      expect(cached.argumentType, isNull);
      // checkedAt is wall-clock; assert it falls inside the call window.
      expect(
        cached.checkedAt.isBefore(before),
        isFalse,
        reason: 'checkedAt must not predate the call',
      );
      expect(
        cached.checkedAt.isAfter(after),
        isFalse,
        reason: 'checkedAt must not be in the future of the call window',
      );
    });

    test('records argumentType when an argument is supplied', () {
      Auth.fake(user: _user());
      Gate.define('edit-string', (user, value) => true);

      Gate.allows('edit-string', 'a-string-arg');

      final cached = Gate.manager.lastResult('edit-string');
      expect(cached, isNotNull);
      expect(cached!.argumentType, String);
    });

    test('records denial via denies() (inverse of allows)', () {
      Auth.fake(user: _user());
      Gate.define('admin-only', (user, _) => false);

      final denied = Gate.denies('admin-only');

      expect(denied, isTrue);
      final cached = Gate.manager.lastResult('admin-only');
      expect(cached, isNotNull);
      expect(cached!.allowed, isFalse);
    });

    test(
      'MRU eviction at cap (writing 65 distinct abilities drops the first)',
      () {
        Auth.fake(user: _user());

        // Define 65 distinct abilities and check each one once.
        for (var i = 1; i <= 65; i++) {
          final name = 'ability-$i';
          Gate.define(name, (user, _) => true);
          Gate.allows(name);
        }

        // Ability #1 is the oldest write → evicted.
        expect(Gate.manager.lastResult('ability-1'), isNull);

        // Ability #2 is the new oldest → still present.
        expect(Gate.manager.lastResult('ability-2'), isNotNull);

        // Ability #65 is the most recent → present.
        expect(Gate.manager.lastResult('ability-65'), isNotNull);
      },
    );

    test('re-writing an ability touches its slot (no eviction of itself)', () {
      Auth.fake(user: _user());

      // Fill the cache with 64 abilities, then re-check #1 to "touch" it,
      // then add #65. Ability #2 should be evicted instead of #1.
      for (var i = 1; i <= 64; i++) {
        final name = 'ability-$i';
        Gate.define(name, (user, _) => true);
        Gate.allows(name);
      }

      // Touch ability-1 → moves it to MRU end.
      Gate.allows('ability-1');

      Gate.define('ability-65', (user, _) => true);
      Gate.allows('ability-65');

      expect(Gate.manager.lastResult('ability-1'), isNotNull);
      expect(Gate.manager.lastResult('ability-2'), isNull);
      expect(Gate.manager.lastResult('ability-65'), isNotNull);
    });

    test('two synchronous checks update the cache in call order', () {
      Auth.fake(user: _user());
      var allowFlag = true;
      Gate.define('toggle', (user, _) => allowFlag);

      // First check: allowed.
      Gate.allows('toggle');
      expect(Gate.manager.lastResult('toggle')!.allowed, isTrue);

      // Flip the predicate and check again in the same microtask.
      allowFlag = false;
      Gate.allows('toggle');

      // Second write overwrites the first → cache reflects the most
      // recent outcome.
      expect(Gate.manager.lastResult('toggle')!.allowed, isFalse);
    });

    test('flush() clears the lastResult cache', () {
      Auth.fake(user: _user());
      Gate.define('view', (user, _) => true);
      Gate.allows('view');

      expect(Gate.manager.lastResult('view'), isNotNull);

      Gate.manager.flush();

      expect(Gate.manager.lastResult('view'), isNull);
    });
  });
}
