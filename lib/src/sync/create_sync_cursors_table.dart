import '../database/migrations/migration.dart';
import '../database/schema/blueprint.dart';
import '../facades/schema.dart';

/// Creates the `sync_cursors` table `SyncLedger` reads and writes.
///
/// No `id()`, no `timestamps()`, no unique index: `SyncLedger` needs only the
/// five columns and upserts by delete-then-insert, so an app that already
/// keeps a table of this shape can point `SyncLedger` at it and skip this
/// migration.
///
/// Magic has no migration discovery (`Migrator.run`): an app that wants
/// this table lists it explicitly in its own `Migrator().run([...])` call
/// alongside its other migrations.
class CreateSyncCursorsTable extends Migration {
  @override
  String get name => '2026_09_26_000000_create_sync_cursors_table';

  @override
  void up() {
    Schema.create('sync_cursors', (Blueprint table) {
      table.string('scope');
      table.string('feed');
      table.string('account');
      table.string('pull_cursor').nullable();
      table.integer('push_mark');
    });
  }

  @override
  void down() {
    Schema.dropIfExists('sync_cursors');
  }
}
