import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:sqlite3/sqlite3.dart';

class TestMigration extends Migration {
  @override
  String get name => '2024_01_01_000000_create_items_table';

  @override
  Future<void> up() async {
    Schema.create('items', (table) {
      table.id();
      table.string('name');
    });
  }

  @override
  Future<void> down() async {
    Schema.dropIfExists('items');
  }
}

void main() {
  group('Migrator', () {
    late Database db;
    late Migrator migrator;

    setUp(() {
      db = sqlite3.openInMemory();
      DatabaseManager().setConnection(db);
      migrator = Migrator();
    });

    tearDown(() {
      DatabaseManager().dispose();
    });

    test('creates migrations table if not exists', () async {
      await migrator.run([]);
      final hasTable = await Schema.hasTable('magic_migrations');
      expect(hasTable, isTrue);
    });

    test('runs migrations', () async {
      final migration = TestMigration();
      await migrator.run([migration]);

      // Check if table created
      expect(await Schema.hasTable('items'), isTrue);

      // Check if logged in migrations table
      final logs = await DB.table('magic_migrations').get();
      expect(logs.length, 1);
      expect(logs.first['migration'], '2024_01_01_000000_create_items_table');
    });

    test('does not run already run migrations', () async {
      final migration = TestMigration();

      // Run twice
      await migrator.run([migration]);
      await migrator.run([migration]);

      final logs = await DB.table('magic_migrations').get();
      expect(logs.length, 1);
    });
  });
}
