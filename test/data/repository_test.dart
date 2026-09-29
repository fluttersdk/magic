import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// A minimal remote model, shaped the way a real resource (`Monitor`,
/// `Product`) is: an id plus a normal field and one field only `show` ever
/// measures.
class _TestRow extends Model {
  @override
  String get table => 'rows';

  @override
  String get resource => 'rows';

  @override
  List<String> get fillable => <String>['id', 'name', 'measured'];

  static _TestRow fromMap(Map<String, dynamic> map) {
    return _TestRow()
      ..fill(map)
      ..exists = true;
  }
}

/// The session user, the same shape `session_scope_test.dart` uses.
class _TestUser extends Model with Authenticatable {
  _TestUser(int id) {
    fill(<String, dynamic>{'id': id});
    exists = true;
  }

  @override
  String get table => 'users';

  @override
  String get resource => 'users';

  @override
  List<String> get fillable => <String>['id'];
}

class _TestRepository extends Repository<_TestRow> {
  @override
  String get resource => 'rows';

  @override
  _TestRow Function(Map<String, dynamic>) get fromMap => _TestRow.fromMap;

  @override
  Set<String> get showOnlyKeys => const <String>{'measured'};
}

/// Counts how many times a session reset actually ran, so a test can prove
/// [Repository.dispose] really stops [SessionScope] from reaching it.
class _CountingRepository extends _TestRepository {
  int resets = 0;

  @override
  Future<void> resetForSession() {
    resets++;
    return super.resetForSession();
  }
}

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  tearDown(() {
    Http.unfake();
    SessionScope.detach();
  });

  group('Repository.upsertFromList', () {
    test('a normal field is cleared by a null the list sends', () {
      final _TestRepository repo = _TestRepository();
      repo.upsertFromList(<_TestRow>[
        _TestRow.fromMap(<String, dynamic>{
          'id': '1',
          'name': 'first',
          'measured': 10,
        }),
      ]);

      repo.upsertFromList(<_TestRow>[
        _TestRow.fromMap(<String, dynamic>{
          'id': '1',
          'name': null,
          'measured': null,
        }),
      ]);

      expect(repo.find('1')!.getAttribute('name'), isNull);
    });

    test('a showOnlyKeys field survives a list null', () {
      final _TestRepository repo = _TestRepository();
      repo.upsertFromList(<_TestRow>[
        _TestRow.fromMap(<String, dynamic>{
          'id': '1',
          'name': 'first',
          'measured': 10,
        }),
      ]);

      repo.upsertFromList(<_TestRow>[
        _TestRow.fromMap(<String, dynamic>{
          'id': '1',
          'name': 'second',
          'measured': null,
        }),
      ]);

      final _TestRow row = repo.find('1')!;
      expect(row.getAttribute('name'), 'second');
      expect(row.getAttribute('measured'), 10);
    });

    test('a showOnlyKeys field the list DOES send is authoritative', () {
      final _TestRepository repo = _TestRepository();
      repo.upsertFromList(<_TestRow>[
        _TestRow.fromMap(<String, dynamic>{
          'id': '1',
          'name': 'first',
          'measured': 10,
        }),
      ]);

      repo.upsertFromList(<_TestRow>[
        _TestRow.fromMap(<String, dynamic>{
          'id': '1',
          'name': 'first',
          'measured': 20,
        }),
      ]);

      expect(repo.find('1')!.getAttribute('measured'), 20);
    });

    test('an unseen row is added rather than requiring a prior show', () {
      final _TestRepository repo = _TestRepository();
      repo.upsertFromList(<_TestRow>[
        _TestRow.fromMap(<String, dynamic>{'id': '9', 'name': 'new'}),
      ]);

      expect(repo.find('9')!.getAttribute('name'), 'new');
      expect(repo.all, hasLength(1));
    });
  });

  group('Repository.refresh', () {
    test('a show that lands after a session reset writes nothing', () async {
      final _TestRepository repo = _TestRepository();
      Http.fake(
        (_) => Http.response(<String, dynamic>{
          'data': <String, dynamic>{'id': '1', 'name': 'previous tenant'},
        }, 200),
      );

      final Future<_TestRow?> pending = repo.refresh('1');
      repo.resetForSession();
      final _TestRow? row = await pending;

      expect(row, isNull);
      expect(repo.find('1'), isNull);
    });

    test('a 404 that lands after a session reset evicts nothing new', () async {
      final _TestRepository repo = _TestRepository();
      Http.fake((_) => Http.response(<String, dynamic>{}, 404));

      final Future<_TestRow?> pending = repo.refresh('1');
      repo.resetForSession();
      repo.upsertFromShow(
        _TestRow.fromMap(<String, dynamic>{'id': '1', 'name': 'new tenant'}),
      );
      await pending;

      expect(repo.find('1')?.getAttribute('name'), 'new tenant');
    });

    test('a 404 evicts the row and answers null', () async {
      final _TestRepository repo = _TestRepository();
      repo.upsertFromShow(
        _TestRow.fromMap(<String, dynamic>{'id': '1', 'name': 'first'}),
      );

      Http.fake((_) => Http.response(<String, dynamic>{}, 404));

      final _TestRow? result = await repo.refresh('1');

      expect(result, isNull);
      expect(repo.find('1'), isNull);
    });

    test(
      'a non-404 failure keeps the cached row rather than a verdict',
      () async {
        final _TestRepository repo = _TestRepository();
        repo.upsertFromShow(
          _TestRow.fromMap(<String, dynamic>{'id': '1', 'name': 'first'}),
        );

        Http.fake((_) => Http.response(<String, dynamic>{}, 500));

        final _TestRow? result = await repo.refresh('1');

        expect(result, isNotNull);
        expect(repo.find('1'), isNotNull);
      },
    );

    test('a successful show is authoritative for every field', () async {
      final _TestRepository repo = _TestRepository();
      repo.upsertFromShow(
        _TestRow.fromMap(<String, dynamic>{
          'id': '1',
          'name': 'first',
          'measured': 10,
        }),
      );

      Http.fake(
        (_) => Http.response(<String, dynamic>{
          'data': <String, dynamic>{
            'id': '1',
            'name': 'second',
            'measured': null,
          },
        }, 200),
      );

      final _TestRow? result = await repo.refresh('1');

      expect(result!.getAttribute('name'), 'second');
      expect(
        result.getAttribute('measured'),
        isNull,
        reason: 'show is authoritative for every field, showOnlyKeys included',
      );
    });
  });

  group('Repository.patch / evict', () {
    test('patch merges attributes onto the cached row', () {
      final _TestRepository repo = _TestRepository();
      repo.upsertFromShow(
        _TestRow.fromMap(<String, dynamic>{'id': '1', 'name': 'first'}),
      );

      repo.patch('1', <String, dynamic>{'name': 'patched'});

      expect(repo.find('1')!.getAttribute('name'), 'patched');
    });

    test('patch on an unknown id is a no-op', () {
      final _TestRepository repo = _TestRepository();

      repo.patch('missing', <String, dynamic>{'name': 'patched'});

      expect(repo.find('missing'), isNull);
    });

    test('evict drops the row', () {
      final _TestRepository repo = _TestRepository();
      repo.upsertFromShow(
        _TestRow.fromMap(<String, dynamic>{'id': '1', 'name': 'first'}),
      );

      repo.evict('1');

      expect(repo.find('1'), isNull);
    });
  });

  group('Repository notifies only on a real change', () {
    _TestRow row(Map<String, dynamic> map) => _TestRow.fromMap(map);

    ({_TestRepository repo, int Function() count}) seeded() {
      final _TestRepository repo = _TestRepository();
      repo.upsertFromShow(
        row(<String, dynamic>{
          'id': '1',
          'name': 'first',
          'measured': <String, dynamic>{'p50': 10, 'p95': 20},
        }),
      );
      int notifies = 0;
      repo.addListener(() => notifies++);

      return (repo: repo, count: () => notifies);
    }

    test('patch with the values already cached notifies zero times', () {
      final seed = seeded();

      seed.repo.patch('1', <String, dynamic>{
        'name': 'first',
        'measured': <String, dynamic>{'p95': 20, 'p50': 10},
      });

      expect(seed.count(), 0);
    });

    test('patch with one changed value notifies once', () {
      final seed = seeded();

      seed.repo.patch('1', <String, dynamic>{
        'name': 'second',
        'measured': <String, dynamic>{'p50': 10, 'p95': 20},
      });

      expect(seed.count(), 1);
      expect(seed.repo.find('1')!.getAttribute('name'), 'second');
    });

    test('patch that adds a key the row lacked notifies once', () {
      final _TestRepository repo = _TestRepository();
      repo.upsertFromShow(row(<String, dynamic>{'id': '1'}));
      int notifies = 0;
      repo.addListener(() => notifies++);

      repo.patch('1', <String, dynamic>{'name': null});

      expect(notifies, 1, reason: 'an absent key and a null key differ');
    });

    test('upsertFromShow with an identical answer notifies zero times', () {
      final seed = seeded();

      seed.repo.upsertFromShow(
        row(<String, dynamic>{
          'measured': <String, dynamic>{'p95': 20, 'p50': 10},
          'name': 'first',
          'id': '1',
        }),
      );

      expect(seed.count(), 0);
    });

    test('upsertFromShow with a changed nested attribute notifies once', () {
      final seed = seeded();

      seed.repo.upsertFromShow(
        row(<String, dynamic>{
          'id': '1',
          'name': 'first',
          'measured': <String, dynamic>{'p50': 10, 'p95': 21},
        }),
      );

      expect(seed.count(), 1);
    });

    test('upsertFromShow for an unknown id notifies once', () {
      final seed = seeded();

      seed.repo.upsertFromShow(row(<String, dynamic>{'id': '2'}));

      expect(seed.count(), 1);
      expect(seed.repo.find('2'), isNotNull);
    });

    test('an identical upsertFromShow still stores the answered row', () {
      final seed = seeded();
      final _TestRow answer = row(<String, dynamic>{
        'id': '1',
        'name': 'first',
        'measured': <String, dynamic>{'p50': 10, 'p95': 20},
      });

      seed.repo.upsertFromShow(answer);

      expect(identical(seed.repo.find('1'), answer), isTrue);
    });

    test('an unchanged refresh notifies zero times', () async {
      final seed = seeded();
      Http.fake(
        (_) => Http.response(<String, dynamic>{
          'data': <String, dynamic>{
            'id': '1',
            'name': 'first',
            'measured': <String, dynamic>{'p50': 10, 'p95': 20},
          },
        }, 200),
      );

      await seed.repo.refresh('1');

      expect(seed.count(), 0);
    });

    test('upsertFromList with identical rows notifies zero times', () {
      final seed = seeded();

      seed.repo.upsertFromList(<_TestRow>[
        row(<String, dynamic>{'id': '1', 'name': 'first', 'measured': null}),
      ]);

      expect(
        seed.count(),
        0,
        reason: 'the null showOnlyKeys field is carried forward before judging',
      );
    });

    test('upsertFromList with one new row notifies once', () {
      final seed = seeded();

      seed.repo.upsertFromList(<_TestRow>[
        row(<String, dynamic>{'id': '1', 'name': 'first', 'measured': null}),
        row(<String, dynamic>{'id': '2', 'name': 'second'}),
      ]);

      expect(seed.count(), 1);
    });

    test('evict notifies once, and an absent id not at all', () {
      final seed = seeded();

      seed.repo.evict('missing');
      seed.repo.evict('1');

      expect(seed.count(), 1);
    });
  });

  group('Repository session scope', () {
    test(
      'registers itself and clears every row on an identity change',
      () async {
        Auth.fake();
        addTearDown(Auth.unfake);

        await Auth.login(<String, dynamic>{'token': 't1'}, _TestUser(1));
        SessionScope.attach();

        final _TestRepository repo = _TestRepository();
        addTearDown(repo.dispose);
        repo.upsertFromShow(
          _TestRow.fromMap(<String, dynamic>{'id': '1', 'name': 'first'}),
        );
        expect(repo.all, isNotEmpty);

        await Auth.login(<String, dynamic>{'token': 't2'}, _TestUser(2));
        await pumpEventQueue();

        expect(repo.all, isEmpty);
      },
    );

    test('dispose stops SessionScope from reaching it', () async {
      Auth.fake();
      addTearDown(Auth.unfake);

      await Auth.login(<String, dynamic>{'token': 't1'}, _TestUser(1));
      SessionScope.attach();

      final _CountingRepository repo = _CountingRepository();
      repo.dispose();

      await Auth.login(<String, dynamic>{'token': 't2'}, _TestUser(2));
      await pumpEventQueue();

      expect(repo.resets, 0);
    });
  });
}
