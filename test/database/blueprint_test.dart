import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_magic/src/database/schema/blueprint.dart';

void main() {
  group('Blueprint', () {
    test('generates correct CREATE TABLE SQL for basic columns', () {
      final blueprint = Blueprint('users');
      blueprint.id();
      blueprint.string('name');
      blueprint.string('email').unique();
      blueprint.boolean('is_active').defaultValue(true);
      blueprint.timestamps();

      final sql = blueprint.toSql();

      expect(sql, contains('CREATE TABLE IF NOT EXISTS users'));
      expect(sql, contains('id INTEGER PRIMARY KEY AUTOINCREMENT'));
      expect(sql, contains('name TEXT NOT NULL'));
      expect(sql, contains('email TEXT NOT NULL UNIQUE'));
      expect(sql, contains('is_active INTEGER NOT NULL DEFAULT 1'));
      expect(sql, contains('created_at TEXT'));
      expect(sql, contains('updated_at TEXT'));
    });

    test('generates nullable columns correctly', () {
      final blueprint = Blueprint('posts');
      blueprint.id();
      blueprint.string('title');
      blueprint.text('content').nullable();

      final sql = blueprint.toSql();

      expect(sql, contains('title TEXT NOT NULL'));
      expect(sql, contains('content TEXT')); // No NOT NULL
      expect(sql, isNot(contains('content TEXT NOT NULL')));
    });

    test('generates default values correctly', () {
      final blueprint = Blueprint('settings');
      blueprint.id();
      blueprint.string('key');
      blueprint.string('value').defaultValue('default_value');
      blueprint.integer('priority').defaultValue(0);
      blueprint.boolean('enabled').defaultValue(false);

      final sql = blueprint.toSql();

      expect(sql, contains("value TEXT NOT NULL DEFAULT 'default_value'"));
      expect(sql, contains('priority INTEGER NOT NULL DEFAULT 0'));
      expect(sql, contains('enabled INTEGER NOT NULL DEFAULT 0'));
    });

    test('generates real (float) columns', () {
      final blueprint = Blueprint('products');
      blueprint.id();
      blueprint.string('name');
      blueprint.real('price');

      final sql = blueprint.toSql();

      expect(sql, contains('price REAL NOT NULL'));
    });

    test('generates blob columns', () {
      final blueprint = Blueprint('files');
      blueprint.id();
      blueprint.string('filename');
      blueprint.blob('data');

      final sql = blueprint.toSql();

      expect(sql, contains('data BLOB NOT NULL'));
    });
  });

  group('ColumnDefinition', () {
    test('can chain modifiers', () {
      final blueprint = Blueprint('test');
      final column = blueprint.string('optional_value');

      // Chain multiple modifiers
      column.nullable().defaultValue('none');

      final sql = blueprint.toSql();

      expect(sql, contains("optional_value TEXT DEFAULT 'none'"));
      expect(sql, isNot(contains('NOT NULL')));
    });

    test('unique constraint is applied', () {
      final blueprint = Blueprint('test');
      blueprint.string('unique_field').unique();

      final sql = blueprint.toSql();

      expect(sql, contains('unique_field TEXT NOT NULL UNIQUE'));
    });
  });
}
