import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_magic/fluttersdk_magic.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('QueryBuilder', () {
    late Database db;

    setUp(() {
      // Use in-memory database for testing
      db = sqlite3.openInMemory();
      DatabaseManager().setConnection(db);

      // Create a test table
      db.execute('''
        CREATE TABLE users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          email TEXT,
          age INTEGER,
          is_active INTEGER DEFAULT 1
        )
      ''');

      // Seed data
      db.execute(
          "INSERT INTO users (name, email, age) VALUES ('Alice', 'alice@example.com', 25)");
      db.execute(
          "INSERT INTO users (name, email, age) VALUES ('Bob', 'bob@example.com', 30)");
      db.execute(
          "INSERT INTO users (name, email, age) VALUES ('Charlie', null, 35)");
    });

    tearDown(() {
      DatabaseManager().dispose();
    });

    test('selects all rows', () async {
      final users = await DB.table('users').get();
      expect(users.length, 3);
      expect(users[0]['name'], 'Alice');
    });

    test('selects specific columns', () async {
      final users = await DB.table('users').select(['name']).get();
      expect(users[0].keys, ['name']);
      expect(users[0]['name'], 'Alice');
    });

    test('filters with where clause', () async {
      final users = await DB.table('users').where('age', '>=', 30).get();
      expect(users.length, 2); // Bob and Charlie
      expect(users[0]['name'], 'Bob');
    });

    test('filters with whereNull', () async {
      final users = await DB.table('users').whereNull('email').get();
      expect(users.length, 1);
      expect(users[0]['name'], 'Charlie');
    });

    test('orders results', () async {
      final users = await DB.table('users').orderBy('age', 'desc').get();
      expect(users[0]['name'], 'Charlie');
      expect(users[1]['name'], 'Bob');
      expect(users[2]['name'], 'Alice');
    });

    test('limits results', () async {
      final users = await DB.table('users').limit(1).get();
      expect(users.length, 1);
    });

    test('counts rows', () async {
      final count = await DB.table('users').count();
      expect(count, 3);
    });

    test('checks existence', () async {
      final exists = await DB.table('users').where('name', 'Alice').exists();
      expect(exists, isTrue);

      final notExists = await DB.table('users').where('name', 'Dave').exists();
      expect(notExists, isFalse);
    });

    test('inserts records (schema aware)', () async {
      final id = await DB.table('users').insert({
        'name': 'Dave',
        'email': 'dave@example.com',
        'age': 40,
        'unknown_column': 'should be ignored',
      });

      expect(id, 4);
      final count = await DB.table('users').count();
      expect(count, 4);
    });

    test('updates records', () async {
      final affected =
          await DB.table('users').where('name', 'Alice').update({'age': 26});

      expect(affected, 1);
      final alice = await DB.table('users').where('name', 'Alice').first();
      expect(alice!['age'], 26);
    });

    test('deletes records', () async {
      final affected = await DB.table('users').where('name', 'Bob').delete();
      expect(affected, 1);
      final count = await DB.table('users').count();
      expect(count, 2);
    });

    test('truncates table', () async {
      await DB.table('users').truncate();
      final count = await DB.table('users').count();
      expect(count, 0);
    });
  });
}
