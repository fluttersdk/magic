import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    DatabaseManager().setConnection(sqlite3.openInMemory());
  });

  tearDown(DatabaseManager().dispose);

  group('SyncLedger', () {
    test('read answers the empty bookmarks for an unknown pair', () {
      CreateSyncCursorsTable().up();

      const SyncLedger ledger = SyncLedger();
      final SyncBookmarks bookmarks = ledger.read(
        scope: 'scope-a',
        feed: 'resume',
      );

      expect(bookmarks.pullCursor, isNull);
      expect(bookmarks.pushMark, 0);
    });

    test('write replaces the row for the same scope and feed', () async {
      CreateSyncCursorsTable().up();

      const SyncLedger ledger = SyncLedger();
      await ledger.write(
        scope: 's',
        feed: 'resume',
        account: 'a',
        pullCursor: 'c1',
        pushMark: 10,
      );
      await ledger.write(
        scope: 's',
        feed: 'resume',
        account: 'a',
        pullCursor: 'c2',
        pushMark: 20,
      );

      final SyncBookmarks bookmarks = ledger.read(scope: 's', feed: 'resume');

      expect(bookmarks.pullCursor, 'c2');
      expect(bookmarks.pushMark, 20);
      expect(DB.select('SELECT * FROM sync_cursors'), hasLength(1));
    });

    test('two feeds under one scope keep separate rows', () async {
      CreateSyncCursorsTable().up();

      const SyncLedger ledger = SyncLedger();
      await ledger.write(
        scope: 's',
        feed: 'resume',
        account: 'a',
        pullCursor: 'c1',
        pushMark: 1,
      );
      await ledger.write(
        scope: 's',
        feed: 'favourites',
        account: 'a',
        pullCursor: 'c2',
        pushMark: 2,
      );

      expect(ledger.read(scope: 's', feed: 'resume').pushMark, 1);
      expect(ledger.read(scope: 's', feed: 'favourites').pushMark, 2);
    });

    test('write inside a transaction that rolls back leaves no row', () async {
      CreateSyncCursorsTable().up();

      const SyncLedger ledger = SyncLedger();

      await expectLater(
        DB.transaction(() async {
          await ledger.write(
            scope: 's',
            feed: 'resume',
            account: 'a',
            pullCursor: 'c',
            pushMark: 1,
          );
          throw StateError('rollback');
        }),
        throwsA(isA<StateError>()),
      );

      expect(DB.select('SELECT * FROM sync_cursors'), isEmpty);
    });

    test(
      'write inside a transaction that commits leaves exactly one row',
      () async {
        CreateSyncCursorsTable().up();

        const SyncLedger ledger = SyncLedger();

        await DB.transaction(() async {
          await ledger.write(
            scope: 's',
            feed: 'resume',
            account: 'a',
            pullCursor: 'c',
            pushMark: 1,
          );
        });

        expect(DB.select('SELECT * FROM sync_cursors'), hasLength(1));
      },
    );

    test('CreateSyncCursorsTable then SyncLedger round-trips', () async {
      CreateSyncCursorsTable().up();

      const SyncLedger ledger = SyncLedger();
      await ledger.write(
        scope: 's',
        feed: 'resume',
        account: 'a',
        pullCursor: 'server-cursor',
        pushMark: 42,
      );

      final SyncBookmarks bookmarks = ledger.read(scope: 's', feed: 'resume');

      expect(bookmarks.pullCursor, 'server-cursor');
      expect(bookmarks.pushMark, 42);
    });

    test(
      'SyncLedger also works on an app-owned table whose feed column was added later',
      () async {
        DB.statement('''
        CREATE TABLE IF NOT EXISTS sync_cursors (
          scope TEXT NOT NULL,
          feed TEXT NOT NULL DEFAULT '',
          account TEXT NOT NULL,
          pull_cursor TEXT,
          push_mark INTEGER NOT NULL
        )
      ''');

        const SyncLedger ledger = SyncLedger();
        await ledger.write(
          scope: 's',
          feed: 'resume',
          account: 'a',
          pullCursor: 'c',
          pushMark: 5,
        );

        final SyncBookmarks bookmarks = ledger.read(scope: 's', feed: 'resume');

        expect(bookmarks.pullCursor, 'c');
        expect(bookmarks.pushMark, 5);
      },
    );
  });
}
