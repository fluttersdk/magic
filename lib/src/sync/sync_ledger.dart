import '../database/database_manager.dart';
import '../facades/db.dart';

/// Where a `(scope, feed)` pair had got to in each sync direction.
///
/// The two fields are two different clocks and neither stands in for the
/// other. [pullCursor] is whatever the server handed back last time, kept as
/// the opaque text it arrived as. [pushMark] is this device's own epoch
/// millis for the newest row it has already sent, in the unit a feed's own
/// `*ChangedSince` reader compares against.
typedef SyncBookmarks = ({String? pullCursor, int pushMark});

/// Reads and writes one feed's sync bookmarks.
///
/// [table] carries more than one feed under a shared scope, so every read and
/// write here is keyed by `(scope, feed)` together; reading by [table] and
/// `scope` alone would answer an arbitrary row the moment a second feed wrote
/// under it.
class SyncLedger {
  /// Creates a ledger over [table].
  ///
  /// The default is the table `CreateSyncCursorsTable` creates. An app with
  /// its own table of the same five columns passes its name instead.
  const SyncLedger({this.table = 'sync_cursors'});

  /// The table both [read] and [write] operate on.
  final String table;

  /// The savepoint [write] wraps its delete-then-insert in.
  static const String _savepoint = 'magic_sync_ledger_write';

  /// Answers the bookmarks [scope] and [feed] had got to.
  ///
  /// An unknown pair answers `(pullCursor: null, pushMark: 0)`: a null cursor
  /// tells the next pull to ask for everything, and a zero mark tells the
  /// next push the same in the other direction, because no local write ever
  /// carries a non-positive epoch.
  SyncBookmarks read({required String scope, required String feed}) {
    final List<Map<String, dynamic>> rows = DB.select(
      'SELECT pull_cursor, push_mark FROM $table WHERE scope = ? AND feed = ?',
      <Object?>[scope, feed],
    );

    if (rows.isEmpty) return (pullCursor: null, pushMark: 0);

    final Map<String, dynamic> row = rows.single;

    return (
      pullCursor: row['pull_cursor'] as String?,
      pushMark: row['push_mark'] as int,
    );
  }

  /// Records both bookmarks for [scope] and [feed], replacing any row that
  /// pair already held.
  ///
  /// [table] carries no unique constraint, so a plain `INSERT` would
  /// accumulate rows and a later [read] would pick an arbitrary one among
  /// them; the delete-then-insert here is what makes this an upsert.
  ///
  /// Issued through [DB.statement] inside a `SAVEPOINT`/`RELEASE` rather than
  /// [DB.transaction], because a `BEGIN` does not nest (`DB.transaction`) and
  /// a feed's own sync run may already be executing inside a caller's own
  /// transaction.
  /// A savepoint does nest: opened with no transaction open it behaves like
  /// one, and opened inside an existing transaction it JOINS that
  /// transaction and is rolled back with it. So a caller whose outer
  /// transaction fails after this savepoint released loses the bookmark
  /// write too, and the next run resends the tail the server's own `>=`
  /// already absorbs: one extra round trip, never a duplicate write.
  Future<void> write({
    required String scope,
    required String feed,
    required String account,
    required String? pullCursor,
    required int pushMark,
  }) async {
    DB.statement('SAVEPOINT $_savepoint');

    try {
      DB.statement('DELETE FROM $table WHERE scope = ? AND feed = ?', <Object?>[
        scope,
        feed,
      ]);
      DB.statement(
        'INSERT INTO $table (scope, feed, account, pull_cursor, push_mark) '
        'VALUES (?, ?, ?, ?, ?)',
        <Object?>[scope, feed, account, pullCursor, pushMark],
      );

      DB.statement('RELEASE $_savepoint');
    } catch (_) {
      // `ROLLBACK TO` leaves the savepoint in place; the `RELEASE` after it
      // is what actually discards it. Guarded on `autocommit` because SQLite
      // itself already rolls back the whole transaction on some errors
      // (SQLITE_FULL, IOERR, NOMEM), taking this savepoint with it; issuing
      // `ROLLBACK TO` against a savepoint that no longer exists throws "no
      // such savepoint" and replaces the original error with that one.
      if (!DatabaseManager().connection.autocommit) {
        DB.statement('ROLLBACK TO $_savepoint');
        DB.statement('RELEASE $_savepoint');
      }

      rethrow;
    }
  }
}
