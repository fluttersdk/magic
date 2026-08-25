import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// A related model, materialised from a nested Map by [Model.getRelation].
class _Company extends Model {
  @override
  String get table => 'companies';

  @override
  String get resource => 'companies';

  @override
  List<String> get fillable => ['name'];

  String? get name => getAttribute('name') as String?;
}

/// The parent, carrying one to-one and one to-many relation plus the two
/// casts whose results are recomputed on every read.
class _Employee extends Model {
  @override
  String get table => 'employees';

  @override
  String get resource => 'employees';

  @override
  List<String> get fillable => ['name', 'joined_at', 'settings', 'company'];

  @override
  Map<String, String> get casts => {
    'joined_at': 'datetime',
    'settings': 'json',
  };

  @override
  Map<String, Model Function()> get relations => {
    'company': _Company.new,
    'colleagues': _Company.new,
  };

  _Company? get company => getRelation<_Company>('company');
  List<_Company> get colleagues => getRelations<_Company>('colleagues');
}

_Employee _loaded() {
  final e = _Employee();
  e.setRawAttributes(<String, dynamic>{
    'id': 1,
    'name': 'Ada',
    'joined_at': '2026-08-25T10:00:00',
    'settings': '{"theme":"dark"}',
    'company': <String, dynamic>{'id': 9, 'name': 'Uptizm'},
    'colleagues': <dynamic>[
      <String, dynamic>{'id': 2, 'name': 'Grace'},
      <String, dynamic>{'id': 3, 'name': 'Alan'},
    ],
  }, sync: true);
  e.exists = true;
  return e;
}

void main() {
  // Required by .claude/rules/tests.md: MagicApp.reset() alone leaves
  // Magic._controllers populated.
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  group('reading a relation does not make the model dirty', () {
    test('a freshly loaded model is clean', () {
      expect(_loaded().isDirty(), isFalse);
    });

    test('getRelation leaves the model clean', () {
      // `getRelation` materialises the nested Map into a `_Company` and caches
      // it back into the attribute map. Dirty tracking compares that map
      // against the original snapshot, which still holds the raw Map, so a
      // pure READ used to report the model as modified.
      final e = _loaded();
      expect(e.company?.name, 'Uptizm');

      expect(
        e.isDirty('company'),
        isFalse,
        reason: 'materialising a relation is not a modification',
      );
      expect(e.isDirty(), isFalse);
      expect(e.getDirty(), isEmpty);
    });

    test('getRelations leaves the model clean', () {
      final e = _loaded();
      expect(e.colleagues.map((c) => c.name), <String>['Grace', 'Alan']);

      expect(e.isDirty('colleagues'), isFalse);
      expect(e.isDirty(), isFalse);
      expect(e.getDirty(), isEmpty);
    });

    test('a real write still reports dirty after a relation was read', () {
      // The guard above must not be bought by making dirty tracking blind.
      final e = _loaded();
      e.company;
      e.setAttribute('name', 'Ada Lovelace');

      expect(e.isDirty(), isTrue);
      expect(e.isDirty('name'), isTrue);
      expect(e.getDirty().keys, contains('name'));
      expect(e.getDirty().keys, isNot(contains('company')));
    });

    test('assigning a different relation value is still a change', () {
      final e = _loaded();
      e.company;
      e.setAttribute('company', <String, dynamic>{'id': 10, 'name': 'Other'});

      expect(e.isDirty('company'), isTrue);
    });
  });

  group('the fill() path keeps storage values in the dirty map', () {
    test('a relation read on a filled model does not leak a Model into '
        'getDirty', () async {
      // A model built with fill() has an empty original snapshot, so it is
      // legitimately dirty. What must not happen is the dirty map carrying a
      // materialised `_Company` where every other value is a storage
      // primitive: that is what a save would try to send.
      final e = _Employee();
      e.fill(<String, dynamic>{
        'name': 'Ada',
        'company': <String, dynamic>{'id': 9, 'name': 'Uptizm'},
      });

      expect(e.company?.name, 'Uptizm');

      expect(e.isDirty('company'), isTrue, reason: 'nothing was ever synced');
      expect(
        e.getDirty()['company'],
        isA<Map<String, dynamic>>(),
        reason: 'the dirty map holds storage values, not model instances',
      );
      expect(e.getDirty()['company'], isNot(isA<Model>()));
    });

    test('reading a relation twice returns the same instance', () {
      final e = _loaded();
      expect(identical(e.company, e.company), isTrue);
    });

    test('toMap still serialises a read relation through its model', () {
      final e = _loaded();
      e.company;

      final map = e.toMap();
      expect(map['company'], isA<Map<String, dynamic>>());
      expect((map['company'] as Map)['name'], 'Uptizm');
    });

    test('replacing the raw value drops the materialised relation', () {
      final e = _loaded();
      expect(e.company?.name, 'Uptizm');

      e.setAttribute('company', <String, dynamic>{'id': 10, 'name': 'Other'});

      expect(
        e.company?.name,
        'Other',
        reason:
            'a stale relation is worse '
            'than none: the getter would keep answering with the old company',
      );
    });
  });

  group('a cast is computed once per raw value', () {
    test('datetime reads return the identical instance', () {
      // `Carbon.parse` on every read is the cost this memo removes. Identity
      // is the assertion because equality would pass on a fresh parse.
      final e = _loaded();
      final first = e.getAttribute('joined_at');
      final second = e.getAttribute('joined_at');

      expect(first, isA<Carbon>());
      expect(
        identical(first, second),
        isTrue,
        reason: 'the second read must not re-parse the string',
      );
    });

    test('json reads return a FRESH map every time, on purpose', () {
      // `json` is deliberately not memoised. A decoded Map is mutable, so
      // handing out the same instance would make
      // `u.settings['theme'] = 'light'` stick for every later read while the
      // raw attribute still held the old JSON, so `isDirty()` stayed false and
      // a save sent the pre-mutation value. The mutation was always lost; the
      // memo would only have made losing it silent instead of visible on the
      // next read.
      final e = _loaded();
      final first = e.getAttribute('settings') as Map<String, dynamic>;
      first['theme'] = 'light';
      final second = e.getAttribute('settings') as Map<String, dynamic>;

      expect(identical(first, second), isFalse);
      expect(second['theme'], 'dark', reason: 'the mutation is visibly lost');
    });

    test('the memo is dropped when the raw value is replaced', () {
      // A stale memo would be worse than no memo: the getter would keep
      // answering with the old date after the attribute was overwritten.
      final e = _loaded();
      final before = e.getAttribute('joined_at') as Carbon;
      expect(before.year, 2026);

      e.setAttribute('joined_at', '2020-01-02T03:04:05');
      final after = e.getAttribute('joined_at') as Carbon;

      expect(after.year, 2020);
      expect(identical(before, after), isFalse);
    });

    test('the memo is dropped when raw attributes are replaced wholesale', () {
      final e = _loaded();
      final before = e.getAttribute('joined_at') as Carbon;
      expect(before.year, 2026);

      e.setRawAttributes(<String, dynamic>{
        'id': 1,
        'joined_at': '2020-01-02T03:04:05',
      }, sync: true);

      expect((e.getAttribute('joined_at') as Carbon).year, 2020);
    });

    test('memoising a cast does not make the model dirty', () {
      // The memo must not land in the attribute map, which is what dirty
      // tracking reads.
      final e = _loaded();
      e.getAttribute('joined_at');
      e.getAttribute('settings');

      expect(e.isDirty(), isFalse);
      expect(e.getDirty(), isEmpty);
    });

    test('toMap still emits the raw storage value, not the memo', () {
      final e = _loaded();
      e.getAttribute('joined_at');

      final map = e.toMap();
      expect(map['joined_at'], isA<String>());
    });
  });
}
