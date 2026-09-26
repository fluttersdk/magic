# Sync

The sync skeleton is a push-then-pull loop over one resource, for an app that keeps a local store consistent with a server across many devices.

- [Introduction](#introduction)
- [The Wire Protocol](#the-wire-protocol)
- [Writing a Feed](#writing-a-feed)
- [Registering the Ledger's Table](#registering-the-ledgers-table)
- [The Two-Clock Rule](#the-two-clock-rule)
- [The Savepoint Note](#the-savepoint-note)
- [What Stays App-Side](#what-stays-app-side)

<a name="introduction"></a>
## Introduction

`SyncFeed` runs one resource's sync: it pushes everything this device wrote since its last push, then, only when that push had no failure, pulls everything the server has past this device's last pull. It never throws, and answers a `SyncReport` (`pushed`, `adopted`, `failure`), logged through `Log.error` on the way out rather than propagated, because a sync is a convenience layered on top of a local store that already works without it.

```dart
final SyncReport report = await ItemsSyncFeed().run(scope: 'team-42', account: userId);

if (!report.complete) {
  Log.warning('items sync did not finish: ${report.failure}');
}
```

`SyncLedger` is the bookkeeping `SyncFeed` reads and writes between runs, backed by the `sync_cursors` table `CreateSyncCursorsTable` creates.

<a name="the-wire-protocol"></a>
## The Wire Protocol

**Push.** `POST '$resource/sync'` with `{envelopeKey: [row.data, ...]}`, batched at `SyncFeed.batchSize` (default 500) rows per request. The push response is read the same way a pull page is (`{"data": [...]}`), so a write this device lost to a conflicting write elsewhere adopts the winner immediately, without waiting for the next pull.

**Pull.** `GET resource` with query `{scope, cursor}`, `cursor` omitted when there is none yet. The pull response is `{"data": [...], "cursor": <opaque text>, "has_more": bool}`. `cursor` is taken from the body rather than derived from the last row: the pair it encodes is the server's business, and a client that built one would be guessing at a tie-break it cannot see. A run walks pages until `has_more` is false or `SyncFeed.maxPages` (default 100) is reached.

Push runs first, and the pull runs only after a push with no failure: a failed push returns before the pull ever starts. The push makes the server's answer to the pull already reflect this device's own writes, so one round leaves the device consistent. Pulling first would leave a device that had just resolved a conflict holding a stale view until the next run.

<a name="writing-a-feed"></a>
## Writing a Feed

A feed subclasses `SyncFeed` and supplies three things: where its bookmarks live (`feed`), which endpoint it talks to (`resource`, `envelopeKey`), and how to read and write its own rows (`pending`, `adoptRow`).

```dart
import 'package:magic/magic.dart';

class ItemsSyncFeed extends SyncFeed {
  @override
  String get feed => 'items';

  @override
  String get resource => 'items';

  @override
  String get envelopeKey => 'items';

  @override
  Future<List<SyncPushRow>> pending({
    required String account,
    required int sinceMillis,
    required String scope,
  }) async {
    final List<Map<String, dynamic>> rows = DB.select(
      'SELECT * FROM items WHERE scope = ? AND updated_at_ms > ? ORDER BY updated_at_ms ASC',
      <Object?>[scope, sinceMillis],
    );

    return [
      for (final row in rows)
        (data: row, mark: row['updated_at_ms'] as int),
    ];
  }

  @override
  Future<bool> adoptRow({
    required String account,
    required Map<String, dynamic> row,
  }) async {
    final int? remoteMark = Cast.intOrNull(row['updated_at_ms']);
    if (remoteMark == null) return false;

    final List<Map<String, dynamic>> existing = DB.select(
      'SELECT updated_at_ms FROM items WHERE id = ?',
      <Object?>[row['id']],
    );

    if (existing.isNotEmpty && (existing.single['updated_at_ms'] as int) >= remoteMark) {
      return false;
    }

    DB.statement(
      'INSERT OR REPLACE INTO items (id, scope, updated_at_ms, payload) VALUES (?, ?, ?, ?)',
      <Object?>[row['id'], row['scope'], remoteMark, row['payload']],
    );

    return true;
  }
}
```

`pending` answers rows oldest first: the push advances its mark to the last row of each batch it sends, so a batch that did not end on its newest row would move the mark past rows it never sent. `adoptRow` answers `false` for a row this client cannot read (a malformed payload) rather than throwing, so one bad row does not stop the rest of a page from landing. Use `Cast.intOrNull`/`doubleOrNull`/`boolOrNull` inside `adoptRow` when the wire value's exact numeric type (`int` vs `double` on web) is not guaranteed.

<a name="registering-the-ledgers-table"></a>
## Registering the Ledger's Table

`CreateSyncCursorsTable` creates the `sync_cursors` table `SyncLedger` reads and writes by default. Magic has no migration discovery, so list it explicitly alongside the app's own migrations:

```dart
await Migrator().run([
  CreateUsersTable(),
  CreateSyncCursorsTable(),
]);
```

The table carries five columns (`scope`, `feed`, `account`, `pull_cursor`, `push_mark`) with no `id()`, no `timestamps()`, and no unique index: `SyncLedger` upserts by delete-then-insert, so an app that already keeps a table of this shape can point a custom `SyncLedger(table: '...')` at it and skip this migration.

<a name="the-two-clock-rule"></a>
## The Two-Clock Rule

A `SyncFeed` run tracks two clocks, and only one of them advances locally. The push mark is this device's own `updated_at`, epoch millis, deciding which rows are worth sending next time. The pull cursor is the server's, opaque text handed straight back unread.

Only the push mark advances here; the pull cursor never substitutes for it. A row adopted from the server carries the ORIGINATING device's clock, so advancing this device's push mark to that value would step over a local row written earlier and never sent. The cost is small: an adopted row is echoed back to the server exactly once, on the next run, where the server's own `>=` comparison rejects it and the mark then covers it.

<a name="the-savepoint-note"></a>
## The Savepoint Note

`SyncLedger.write` issues its delete-then-insert inside a `SAVEPOINT`/`RELEASE` pair rather than `DB.transaction`, because a bare `BEGIN` does not nest and a feed's own sync run may already be executing inside a caller's outer transaction. A savepoint does nest: opened with no transaction open it behaves like one, and opened inside an existing transaction it joins that transaction and rolls back with it.

That means a caller whose outer transaction fails after this savepoint released loses the bookmark write too. The next run simply resends the tail the server's own `>=` check already absorbs: one extra round trip, never a duplicate write.

<a name="what-stays-app-side"></a>
## What Stays App-Side

The skeleton is deliberately narrow. Three things stay the app's own responsibility:

- **Scope derivation.** `scope` is an opaque string `SyncFeed.run` passes straight through to the ledger and the wire calls; how an app derives it (a team id, a workspace id) is not this package's concern.
- **Salt.** Any value mixed into a feed's own local identifiers or cache keys beyond `scope` and `account` is the app's own.
- **Orchestration.** When and how often a feed runs (on a timer, on reconnect, on app resume) is left to the app; `SyncFeed.run` answers one call, it does not schedule itself.
