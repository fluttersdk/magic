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
  List<String> get fillable => ['name', 'joined_at', 'settings'];

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

    test('json reads return the identical decoded map', () {
      final e = _loaded();
      final first = e.getAttribute('settings');
      final second = e.getAttribute('settings');

      expect(first, isA<Map<String, dynamic>>());
      expect(identical(first, second), isTrue);
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
      expect((e.getAttribute('settings') as Map)['theme'], 'dark');

      e.setRawAttributes(<String, dynamic>{
        'id': 1,
        'settings': '{"theme":"light"}',
      }, sync: true);

      expect((e.getAttribute('settings') as Map)['theme'], 'light');
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
