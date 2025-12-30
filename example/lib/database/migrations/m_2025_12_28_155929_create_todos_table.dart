import 'package:fluttersdk_magic/fluttersdk_magic.dart';

/// Migration: 2025_12_28_155929_create_todos_table
///
/// Creates the todos table.
class CreateTodosTable extends Migration {
  @override
  String get name => '2025_12_28_155929_create_todos_table';

  @override
  void up() {
    Schema.create('todos', (Blueprint table) {
      table.id();
      table.string('title');
      table.text('description').nullable();
      table.boolean('is_completed').defaultValue(false);
      table.integer('priority').defaultValue(0); // 0: low, 1: medium, 2: high
      table.timestamps();
    });
  }

  @override
  void down() {
    Schema.dropIfExists('todos');
  }
}
