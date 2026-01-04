import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_magic/fluttersdk_magic.dart';
import 'package:sqlite3/sqlite3.dart';

/// A test model for unit testing the Eloquent ORM.
class TestUser extends Model with HasTimestamps, InteractsWithPersistence {
  @override
  String get table => 'test_users';

  @override
  String get resource => 'test_users';

  @override
  List<String> get fillable => ['name', 'email', 'born_at', 'settings'];

  @override
  Map<String, String> get casts => {
        'born_at': 'datetime',
        'settings': 'json',
      };

  // Disable remote for tests
  @override
  bool get useRemote => false;

  // Typed accessors
  String? get name => getAttribute('name') as String?;
  set name(String? value) => setAttribute('name', value);

  String? get email => getAttribute('email') as String?;
  set email(String? value) => setAttribute('email', value);

  Carbon? get bornAt => getAttribute('born_at') as Carbon?;
  set bornAt(dynamic value) => setAttribute('born_at', value);

  Map<String, dynamic>? get settings =>
      getAttribute('settings') as Map<String, dynamic>?;
  set settings(Map<String, dynamic>? value) => setAttribute('settings', value);

  // Static helpers
  static Future<TestUser?> find(dynamic id) =>
      InteractsWithPersistence.findById<TestUser>(id, TestUser.new);

  static Future<List<TestUser>> all() =>
      InteractsWithPersistence.allModels<TestUser>(TestUser.new);
}

void main() {
  group('Model Attributes', () {
    test('can fill and retrieve attributes', () {
      final user = TestUser()
        ..fill({
          'name': 'John Doe',
          'email': 'john@example.com',
        });

      expect(user.name, 'John Doe');
      expect(user.email, 'john@example.com');
    });

    test('can set and get attributes via accessors', () {
      final user = TestUser();
      user.name = 'Jane Doe';
      user.email = 'jane@example.com';

      expect(user.name, 'Jane Doe');
      expect(user.email, 'jane@example.com');
    });

    test('toArray returns all attributes', () {
      final user = TestUser()
        ..fill({
          'name': 'Test User',
          'email': 'test@example.com',
        });

      final array = user.toArray();
      expect(array['name'], 'Test User');
      expect(array['email'], 'test@example.com');
    });

    test('get returns attribute with type', () {
      final user = TestUser()..fill({'name': 'John', 'email': 'john@test.com'});

      expect(user.get<String>('name'), 'John');
      expect(user.get<String>('email'), 'john@test.com');
    });

    test('get returns defaultValue when null', () {
      final user = TestUser();

      expect(user.get<String>('name'), isNull);
      expect(user.get<String>('name', defaultValue: 'Unknown'), 'Unknown');
    });

    test('set sets attribute value', () {
      final user = TestUser();
      user.set('name', 'Jane');
      user.set('email', 'jane@test.com');

      expect(user.get<String>('name'), 'Jane');
      expect(user.get<String>('email'), 'jane@test.com');
    });

    test('has checks attribute existence', () {
      final user = TestUser()..fill({'name': 'John'});

      expect(user.has('name'), isTrue);
      expect(user.has('email'), isFalse);
    });
  });

  group('Model Casting', () {
    test('casts datetime to Carbon', () {
      final user = TestUser();
      user.bornAt = Carbon.parse('2000-01-15T10:30:00');

      final bornAt = user.bornAt;
      expect(bornAt, isA<Carbon>());
      expect(bornAt!.year, 2000);
      expect(bornAt.month, 1);
      expect(bornAt.day, 15);
    });

    test('casts json to Map', () {
      final user = TestUser();
      user.settings = {'theme': 'dark', 'notifications': true};

      final settings = user.settings;
      expect(settings, isA<Map<String, dynamic>>());
      expect(settings!['theme'], 'dark');
      expect(settings['notifications'], true);
    });
  });

  group('Model Dirty Checking', () {
    test('isDirty detects changes', () {
      final user = TestUser()
        ..fill({'name': 'Original'})
        ..syncOriginal();

      expect(user.isDirty(), isFalse);

      user.name = 'Changed';
      expect(user.isDirty(), isTrue);
      expect(user.isDirty('name'), isTrue);
      expect(user.isDirty('email'), isFalse);
    });

    test('getDirty returns changed attributes', () {
      final user = TestUser()
        ..fill({'name': 'Original', 'email': 'original@test.com'})
        ..syncOriginal();

      user.name = 'Changed';

      final dirty = user.getDirty();
      expect(dirty.containsKey('name'), isTrue);
      expect(dirty.containsKey('email'), isFalse);
    });

    test('syncOriginal marks model as clean', () {
      final user = TestUser()
        ..fill({'name': 'Test'})
        ..syncOriginal();

      user.name = 'Changed';
      expect(user.isDirty(), isTrue);

      user.syncOriginal();
      expect(user.isDirty(), isFalse);
    });
  });

  group('HasTimestamps', () {
    test('updateTimestamps sets created_at for new models', () {
      final user = TestUser();
      expect(user.exists, isFalse);

      user.updateTimestamps();

      expect(user.createdAt, isNotNull);
      expect(user.updatedAt, isNotNull);
    });

    test('updateTimestamps only updates updated_at for existing models', () {
      final user = TestUser();
      user.exists = true;
      user.createdAt = Carbon.parse('2020-01-01T00:00:00');

      user.updateTimestamps();

      // created_at should not change
      expect(user.createdAt!.year, 2020);
      // updated_at should be now
      expect(user.updatedAt, isNotNull);
    });

    test('timestamps can be disabled', () {
      // Create a model that disables timestamps
      final user = _NoTimestampsModel();
      user.updateTimestamps();

      expect(user.getAttribute('created_at'), isNull);
      expect(user.getAttribute('updated_at'), isNull);
    });
  });

  group('InteractsWithPersistence', () {
    late Database db;

    setUp(() {
      // Use in-memory database for testing
      db = sqlite3.openInMemory();
      DatabaseManager().setConnection(db);

      // Create test table
      db.execute('''
        CREATE TABLE test_users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          email TEXT,
          born_at TEXT,
          settings TEXT,
          created_at TEXT,
          updated_at TEXT
        )
      ''');
    });

    tearDown(() {
      DatabaseManager().dispose();
    });

    test('save inserts new model', () async {
      final user = TestUser()
        ..fill({
          'name': 'New User',
          'email': 'new@example.com',
        });

      final result = await user.save();

      expect(result, isTrue);
      expect(user.exists, isTrue);
      expect(user.id, isNotNull);
    });

    test('save updates existing model', () async {
      // Insert directly
      db.execute(
          "INSERT INTO test_users (name, email) VALUES ('Original', 'orig@test.com')");

      final user = await TestUser.find(1);
      expect(user, isNotNull);
      expect(user!.name, 'Original');

      user.name = 'Updated';
      await user.save();

      // Verify update
      final updated = await TestUser.find(1);
      expect(updated!.name, 'Updated');
    });

    test('find returns model by id', () async {
      db.execute(
          "INSERT INTO test_users (name, email) VALUES ('Test', 'test@example.com')");

      final user = await TestUser.find(1);

      expect(user, isNotNull);
      expect(user!.name, 'Test');
      expect(user.email, 'test@example.com');
      expect(user.exists, isTrue);
    });

    test('find returns null for non-existent id', () async {
      final user = await TestUser.find(999);
      expect(user, isNull);
    });

    test('all returns all models', () async {
      db.execute(
          "INSERT INTO test_users (name, email) VALUES ('User 1', 'u1@test.com')");
      db.execute(
          "INSERT INTO test_users (name, email) VALUES ('User 2', 'u2@test.com')");

      final users = await TestUser.all();

      expect(users.length, 2);
      expect(users[0].name, 'User 1');
      expect(users[1].name, 'User 2');
    });

    test('delete removes model', () async {
      db.execute(
          "INSERT INTO test_users (name, email) VALUES ('ToDelete', 'del@test.com')");

      final user = await TestUser.find(1);
      expect(user, isNotNull);

      final result = await user!.delete();
      expect(result, isTrue);
      expect(user.exists, isFalse);

      // Verify deletion
      final deleted = await TestUser.find(1);
      expect(deleted, isNull);
    });

    test('refresh reloads model from database', () async {
      db.execute(
          "INSERT INTO test_users (name, email) VALUES ('Original', 'orig@test.com')");

      final user = await TestUser.find(1);
      expect(user!.name, 'Original');

      // Update directly in DB
      db.execute("UPDATE test_users SET name = 'Updated' WHERE id = 1");

      // Refresh
      await user.refresh();
      expect(user.name, 'Updated');
    });
  });

  group('Model Serialization', () {
    test('toMap respects hidden attributes defined in model', () {
      final user = _UserWithHidden()
        ..fill({
          'name': 'John Doe',
          'email': 'john@example.com',
          'password': 'secret123',
          'api_key': 'abc123',
        });

      final map = user.toMap();

      expect(map['name'], 'John Doe');
      expect(map['email'], 'john@example.com');
      expect(map.containsKey('password'), isFalse);
      expect(map.containsKey('api_key'), isFalse);
    });

    test('makeHidden temporarily hides attributes', () {
      final user = TestUser()
        ..fill({
          'name': 'Jane Doe',
          'email': 'jane@example.com',
        });

      final map = user.makeHidden(['email']).toMap();

      expect(map['name'], 'Jane Doe');
      expect(map.containsKey('email'), isFalse);
    });

    test('makeVisible temporarily shows hidden attributes', () {
      final user = _UserWithHidden()
        ..fill({
          'name': 'John',
          'password': 'hidden_password',
        });

      final map = user.makeVisible(['password']).toMap();

      expect(map['name'], 'John');
      expect(map['password'], 'hidden_password');
    });

    test('toMap respects visible attributes defined in model', () {
      final user = _UserWithVisible()
        ..fill({
          'public_name': 'Public Name',
          'secret_field': 'Should be hidden',
        });

      final map = user.toMap();

      expect(map['public_name'], 'Public Name');
      expect(map.containsKey('secret_field'), isFalse);
    });

    test('append adds runtime attributes to serialization', () {
      final user = TestUser()
        ..fill({
          'name': 'John',
          'email': 'john@test.com',
        })
        ..setAttribute('computed_field', 'computed_value');

      final map = user.append(['computed_field']).toMap();

      expect(map['name'], 'John');
      expect(map['computed_field'], 'computed_value');
    });

    test('toJson returns JSON string', () {
      final user = TestUser()
        ..fill({
          'name': 'Test',
          'email': 'test@test.com',
        });

      final json = user.toJson();

      expect(json, contains('"name"'));
      expect(json, contains('"Test"'));
      expect(json, contains('"email"'));
    });

    test('makeHidden and makeVisible are chainable', () {
      final user = _UserWithHidden()
        ..fill({
          'name': 'User',
          'email': 'user@test.com',
          'password': 'secret',
        });

      final map = user.makeVisible(['password']).makeHidden(['email']).toMap();

      expect(map['name'], 'User');
      expect(map['password'], 'secret');
      expect(map.containsKey('email'), isFalse);
    });
  });
}

/// A model with hidden attributes for testing serialization.
class _UserWithHidden extends Model {
  @override
  String get table => 'users';

  @override
  String get resource => 'users';

  @override
  List<String> get fillable => ['name', 'email', 'password', 'api_key'];

  @override
  List<String> get hidden => ['password', 'api_key'];
}

/// A model with visible attributes for testing serialization.
class _UserWithVisible extends Model {
  @override
  String get table => 'users';

  @override
  String get resource => 'users';

  @override
  List<String> get fillable => ['public_name', 'secret_field'];

  @override
  List<String> get visible => ['public_name'];
}

/// A model with timestamps disabled for testing.
class _NoTimestampsModel extends Model with HasTimestamps {
  @override
  String get table => 'no_timestamps';

  @override
  String get resource => 'no_timestamps';

  @override
  bool get timestamps => false;
}
