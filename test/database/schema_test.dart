import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_magic/fluttersdk_magic.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('Schema', () {
    late Database db;

    setUp(() {
      db = sqlite3.openInMemory();
      DatabaseManager().setConnection(db);
    });

    tearDown(() {
      DatabaseManager().dispose();
    });

    test('creates table with columns', () async {
      Schema.create('products', (table) {
        table.id();
        table.string('name');
        table.integer('price');
        table.timestamps();
      });

      // Verify via sqlite
      final result = db.select("PRAGMA table_info(products)");
      final columns = result.map((row) => row['name']).toList();

      expect(columns,
          containsAll(['id', 'name', 'price', 'created_at', 'updated_at']));
    });

    test('drops table', () async {
      db.execute('CREATE TABLE temp (id INTEGER)');

      Schema.drop('temp');

      // Verify table is gone
      // Catch error or check tables list
      try {
        db.select('SELECT * FROM temp');
        fail('Table should have been dropped');
      } catch (e) {
        // Expected
      }
    });

    test('drops table if exists', () async {
      Schema.dropIfExists('non_existent');
      // Should not throw
    });

    test('checks if table has column', () async {
      db.execute('CREATE TABLE users (id INTEGER, name TEXT)');

      expect(await Schema.hasColumn('users', 'name'), isTrue);
      expect(await Schema.hasColumn('users', 'email'), isFalse);
    });

    test('checks if table has table', () async {
      db.execute('CREATE TABLE users (id INTEGER, name TEXT)');

      expect(await Schema.hasTable('users'), isTrue);
      expect(await Schema.hasTable('non_existent'), isFalse);
    });
  });
}
