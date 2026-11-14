import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// An in-memory [LocalModelStore] that records every call it receives.
class _FakeStore implements LocalModelStore {
  final Map<String, Map<dynamic, Map<String, dynamic>>> rows = {};
  final List<String> calls = [];
  int _nextId = 1;

  void seed(String table, Map<String, dynamic> row) {
    rows.putIfAbsent(table, () => {})[row['id']] = Map.of(row);
  }

  @override
  Future<Map<String, dynamic>?> find(
    String table,
    String primaryKey,
    dynamic id,
  ) async {
    calls.add('find:$table:$id');
    final Map<String, dynamic>? row = rows[table]?[id];

    return row == null ? null : Map.of(row);
  }

  @override
  Future<List<Map<String, dynamic>>> all(String table) async {
    calls.add('all:$table');

    return [
      for (final Map<String, dynamic> row in rows[table]?.values ?? [])
        Map.of(row),
    ];
  }

  @override
  Future<dynamic> insert(String table, Map<String, dynamic> data) async {
    calls.add('insert:$table');
    final dynamic id = data['id'] ?? _nextId++;
    rows.putIfAbsent(table, () => {})[id] = {...data, 'id': id};

    return id;
  }

  @override
  Future<void> update(
    String table,
    String primaryKey,
    dynamic id,
    Map<String, dynamic> data,
  ) async {
    calls.add('update:$table:$id');
    rows[table]![id] = Map.of(data);
  }

  @override
  Future<void> delete(String table, String primaryKey, dynamic id) async {
    calls.add('delete:$table:$id');
    rows[table]?.remove(id);
  }

  @override
  Future<void> upsert(
    String table,
    String primaryKey,
    dynamic id,
    Map<String, dynamic> data,
  ) async {
    calls.add('upsert:$table:$id');
    rows.putIfAbsent(table, () => {})[id] = Map.of(data);
  }
}

class _LocalNote extends Model with InteractsWithPersistence {
  @override
  String get table => 'notes';

  @override
  String get resource => 'notes';

  @override
  List<String> get fillable => ['title'];

  @override
  bool get useLocal => true;

  @override
  bool get useRemote => false;

  static Future<_LocalNote?> find(dynamic id) =>
      InteractsWithPersistence.findById<_LocalNote>(id, _LocalNote.new);

  static Future<List<_LocalNote>> all() =>
      InteractsWithPersistence.allModels<_LocalNote>(_LocalNote.new);
}

class _HybridNote extends Model with InteractsWithPersistence {
  @override
  String get table => 'notes';

  @override
  String get resource => 'notes';

  @override
  bool get useLocal => true;

  @override
  bool get useRemote => true;

  static Future<_HybridNote?> find(dynamic id) =>
      InteractsWithPersistence.findById<_HybridNote>(id, _HybridNote.new);

  static Future<List<_HybridNote>> all() =>
      InteractsWithPersistence.allModels<_HybridNote>(_HybridNote.new);
}

_LocalNote _existingNote() {
  return _LocalNote()
    ..setRawAttributes({'id': 1, 'title': 'Stored'}, sync: true)
    ..exists = true;
}

final Matcher _throwsMissingStore = throwsA(
  isA<StateError>().having(
    (StateError error) => error.message,
    'message',
    contains('magic_local_storage'),
  ),
);

void main() {
  late _FakeStore store;

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    store = _FakeStore();
  });

  tearDown(() {
    Http.unfake();
    MagicApp.reset();
    Magic.flush();
  });

  group('InteractsWithPersistence against a bound LocalModelStore', () {
    setUp(() {
      MagicApp.instance.setInstance('local_model_store', store);
    });

    test('save inserts a new model and back-fills its id', () async {
      final _LocalNote note = _LocalNote()..fill({'title': 'Fresh'});

      expect(await note.save(), isTrue);
      expect(store.calls, ['insert:notes']);
      expect(note.id, 1);
      expect(note.exists, isTrue);
      expect(store.rows['notes']![1]!['title'], 'Fresh');
    });

    test('save updates an existing model', () async {
      store.seed('notes', {'id': 1, 'title': 'Stored'});
      final _LocalNote note = _existingNote()..fill({'title': 'Edited'});

      expect(await note.save(), isTrue);
      expect(store.calls, ['update:notes:1']);
      expect(store.rows['notes']![1]!['title'], 'Edited');
    });

    test('findById hydrates the stored row', () async {
      store.seed('notes', {'id': 1, 'title': 'Stored'});

      final _LocalNote? note = await _LocalNote.find(1);

      expect(note?.getAttribute('title'), 'Stored');
      expect(note?.exists, isTrue);
      expect(store.calls, ['find:notes:1']);
    });

    test('allModels hydrates every stored row', () async {
      store.seed('notes', {'id': 1, 'title': 'One'});
      store.seed('notes', {'id': 2, 'title': 'Two'});

      final List<_LocalNote> notes = await _LocalNote.all();

      expect(notes.map((_LocalNote note) => note.getAttribute('title')), [
        'One',
        'Two',
      ]);
      expect(store.calls, ['all:notes']);
    });

    test('delete removes the stored row', () async {
      store.seed('notes', {'id': 1, 'title': 'Stored'});
      final _LocalNote note = _existingNote();

      expect(await note.delete(), isTrue);
      expect(note.exists, isFalse);
      expect(store.calls, ['delete:notes:1']);
      expect(store.rows['notes'], isEmpty);
    });

    test('refresh reloads the stored row', () async {
      store.seed('notes', {'id': 1, 'title': 'Changed elsewhere'});
      final _LocalNote note = _existingNote();

      expect(await note.refresh(), isTrue);
      expect(note.getAttribute('title'), 'Changed elsewhere');
      expect(store.calls, ['find:notes:1']);
    });

    test('findById syncs a remote hit into the store', () async {
      Http.fake(
        (MagicRequest request) => Http.response({
          'data': {'id': 5, 'title': 'Remote'},
        }, 200),
      );

      final _HybridNote? note = await _HybridNote.find(5);

      expect(note?.getAttribute('title'), 'Remote');
      expect(store.calls, ['find:notes:5', 'upsert:notes:5']);
      expect(store.rows['notes']![5]!['title'], 'Remote');
    });

    test('allModels syncs every remote row into the store', () async {
      Http.fake(
        (MagicRequest request) => Http.response({
          'data': [
            {'id': 1, 'title': 'One'},
            {'id': 2, 'title': 'Two'},
          ],
        }, 200),
      );

      // An empty local table is still a local answer, so make the local leg
      // fail and let the remote leg run.
      final _FailingAllStore failing = _FailingAllStore();
      MagicApp.instance.setInstance('local_model_store', failing);

      final List<_HybridNote> notes = await _HybridNote.all();

      expect(notes, hasLength(2));
      expect(failing.calls, ['all:notes', 'upsert:notes:1', 'upsert:notes:2']);
    });
  });

  group('InteractsWithPersistence with no LocalModelStore bound', () {
    test('save throws a StateError naming the plugin', () {
      final _LocalNote note = _LocalNote()..fill({'title': 'Fresh'});

      expect(note.save(), _throwsMissingStore);
    });

    test('findById throws a StateError naming the plugin', () {
      expect(_LocalNote.find(1), _throwsMissingStore);
    });

    test('allModels throws a StateError naming the plugin', () {
      expect(_LocalNote.all(), _throwsMissingStore);
    });

    test('delete throws a StateError naming the plugin', () {
      expect(_existingNote().delete(), _throwsMissingStore);
    });

    test('refresh throws a StateError naming the plugin', () {
      expect(_existingNote().refresh(), _throwsMissingStore);
    });

    test('findById on a hybrid model throws before the remote leg', () {
      Http.fake(
        (MagicRequest request) => Http.response({
          'data': {'id': 5, 'title': 'Remote'},
        }, 200),
      );

      expect(_HybridNote.find(5), _throwsMissingStore);
    });

    test('allModels on a hybrid model throws before the remote leg', () {
      Http.fake(
        (MagicRequest request) => Http.response({
          'data': [
            {'id': 1, 'title': 'One'},
          ],
        }, 200),
      );

      expect(_HybridNote.all(), _throwsMissingStore);
    });
  });
}

/// A store whose local read fails, so a hybrid model falls through to remote.
class _FailingAllStore extends _FakeStore {
  @override
  Future<List<Map<String, dynamic>>> all(String table) async {
    calls.add('all:$table');
    throw StateError('local read failed');
  }
}
