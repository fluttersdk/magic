import 'package:flutter/foundation.dart';

import '../facades/http.dart';
import '../facades/log.dart';
import '../network/magic_response.dart';
import 'sync_ledger.dart';

/// One local row a push owes the server: the wire payload and the local
/// clock that decides how far the push mark may advance.
///
/// The two are separate because they answer different questions. [data] is
/// whatever the feed's own endpoint validates, and [mark] is always this
/// device's epoch millis for the row, which is the unit a feed's own
/// `*ChangedSince` reader compares against.
typedef SyncPushRow = ({Map<String, Object?> data, int mark});

/// What one sync run did, in the terms a caller can act on.
class SyncReport {
  /// Creates a report. [SyncFeed.run] builds one per run; an app's own
  /// wrapper may build one for a run it declined to start.
  const SyncReport({required this.pushed, required this.adopted, this.failure});

  /// Rows this device sent that the server accepted as the newer state.
  final int pushed;

  /// Rows this device adopted from another device.
  final int adopted;

  /// Why the run stopped early, or null when it finished.
  ///
  /// A sync is a background convenience, so a failure is reported and never
  /// thrown.
  final String? failure;

  /// Whether the run finished both halves.
  bool get complete => failure == null;
}

/// The push-then-pull skeleton every feed's sync runs, over one resource.
///
/// ### Wire protocol
///
/// Push request: `POST '$resource/sync'` with `{envelopeKey: [row.data, ...]}`.
/// Push response: whatever the server answers, read the same way a pull page
/// is (`{"data": [...]}`) so a write this device lost adopts the winner here
/// rather than waiting for the next pull.
///
/// Pull request: `GET resource` with query `{scope, cursor}`, `cursor`
/// omitted when there is none yet.
/// Pull response: `{"data": [...], "cursor": <opaque text>, "has_more":
/// bool}`. `cursor` is taken from the body rather than derived from the last
/// row: the pair it encodes is the server's business, and a client that
/// built one would be guessing at a tie-break it cannot see.
///
/// ### Two clocks, and only one of them advances here
///
/// The push mark is a local `updated_at`, this device's own epoch millis,
/// and decides which rows are worth sending. The pull cursor is the
/// server's, opaque text handed straight back. Only the push advances the
/// mark, never the pull: a row adopted from the server carries the
/// ORIGINATING device's clock, so advancing the mark to it would step over a
/// local row written earlier and never sent. The cost is that an adopted row
/// is echoed back to the server exactly once, on the next run, where the
/// server's own `>=` rejects it and the mark then covers it.
///
/// ### Push first, then pull
///
/// The pull runs only after a push with no failure. The push makes the
/// server's answer to the pull already reflect this device's writes, so
/// one round leaves the device consistent; pulling first would leave a
/// device that had just resolved a conflict holding a stale view until the
/// next run. A failed push returns before the pull ever starts, since a
/// pull cursor advanced on top of an unsent push would let the pull outrun
/// what this device still owes the server.
abstract class SyncFeed {
  /// Creates the sync over [ledger].
  const SyncFeed({this.ledger = const SyncLedger()});

  /// Where this feed's bookmarks live.
  @protected
  final SyncLedger ledger;

  /// The `sync_cursors.feed` literal this feed's bookmarks live under.
  @protected
  String get feed;

  /// The API path, under whatever prefix the network driver's base URL
  /// carries. A missing leading slash is normalised by [run]; declare it
  /// with or without one.
  @protected
  String get resource;

  /// The key the push body wraps its rows in.
  @protected
  String get envelopeKey;

  /// How many rows one push batch carries.
  int get batchSize => 500;

  /// How many pull pages one run will walk before giving up.
  int get maxPages => 100;

  /// Everything written locally after [sinceMillis], oldest first, as wire
  /// rows.
  ///
  /// Oldest first is required rather than tidy: the push advances its mark
  /// to the last row of each batch it sends, so a batch that did not end on
  /// its newest row would move the mark past rows it never sent.
  @protected
  Future<List<SyncPushRow>> pending({
    required String account,
    required int sinceMillis,
    required String scope,
  });

  /// Writes one row the server answered with, and says whether it was newer
  /// than what this device already held.
  ///
  /// A row this client cannot read answers false rather than throwing: one
  /// such row must not stop the rest of a page from landing.
  @protected
  Future<bool> adoptRow({
    required String account,
    required Map<String, dynamic> row,
  });

  /// Runs both halves for [scope] and [account].
  ///
  /// Never throws. An exception from [pending], [adoptRow] or the ledger
  /// arrives as a [SyncReport] carrying [SyncReport.failure] instead,
  /// logged with [Log.error]: every feed here is a convenience on top of a
  /// local store that already works without it.
  Future<SyncReport> run({
    required String scope,
    required String account,
  }) async {
    try {
      // The raw `Http` methods hand the path to the driver untouched, and a
      // base URL with no trailing slash plus a resource with no leading one
      // joins into one word (`/api/v1` + `items` is `/api/v1items`, a path
      // that does not exist); prefixing it here once covers both halves.
      final String path = resource.startsWith('/') ? resource : '/$resource';

      final SyncBookmarks bookmarks = ledger.read(scope: scope, feed: feed);

      final _PushResult push = await _push(
        path: path,
        scope: scope,
        account: account,
        mark: bookmarks.pushMark,
      );

      if (push.failure != null) {
        // The mark still advances over whatever landed before the failure,
        // so a retry resends the tail rather than the whole store. The pull
        // cursor is left exactly as it was: nothing was pulled this run.
        await ledger.write(
          scope: scope,
          feed: feed,
          account: account,
          pullCursor: bookmarks.pullCursor,
          pushMark: push.mark,
        );

        return SyncReport(pushed: push.sent, adopted: 0, failure: push.failure);
      }

      final _PullResult pull = await _pull(
        path: path,
        scope: scope,
        account: account,
        cursor: bookmarks.pullCursor,
      );

      await ledger.write(
        scope: scope,
        feed: feed,
        account: account,
        pullCursor: pull.cursor,
        pushMark: push.mark,
      );

      return SyncReport(
        pushed: push.sent,
        adopted: pull.adopted,
        failure: pull.failure,
      );
    } catch (error, stackTrace) {
      Log.error('sync run failed for feed "$feed"', {
        'error': error.toString(),
        'stackTrace': stackTrace.toString(),
      });

      return SyncReport(pushed: 0, adopted: 0, failure: 'sync failed: $error');
    }
  }

  /// Sends everything written locally since [mark], in [batchSize] slices.
  ///
  /// An empty set sends nothing rather than an empty batch: every one of
  /// these endpoints validates its array as non-empty, so an empty push
  /// would be a 422 and not a no-op.
  Future<_PushResult> _push({
    required String path,
    required String scope,
    required String account,
    required int mark,
  }) async {
    final List<SyncPushRow> changed = await pending(
      account: account,
      sinceMillis: mark,
      scope: scope,
    );

    int reached = mark;
    int sent = 0;

    for (int start = 0; start < changed.length; start += batchSize) {
      final int end = start + batchSize > changed.length
          ? changed.length
          : start + batchSize;
      final List<SyncPushRow> slice = changed.sublist(start, end);

      final MagicResponse response = await Http.post(
        '$path/sync',
        data: <String, Object?>{
          envelopeKey: slice.map((SyncPushRow row) => row.data).toList(),
        },
      );

      if (!response.successful) {
        return _PushResult(
          sent: sent,
          mark: reached,
          failure: _failureOf(response, 'push'),
        );
      }

      // Only past a 2xx: the batch is all or nothing on the server, so a
      // mark advanced on a refused batch would lose every row in it.
      reached = slice.last.mark;
      sent += slice.length;

      await _adopt(account: account, body: response.data);
    }

    return _PushResult(sent: sent, mark: reached, failure: null);
  }

  /// Walks every page the server has past [cursor], writing each row.
  Future<_PullResult> _pull({
    required String path,
    required String scope,
    required String account,
    required String? cursor,
  }) async {
    String? at = cursor;
    int adopted = 0;

    for (int page = 0; page < maxPages; page++) {
      final MagicResponse response = await Http.get(
        path,
        query: <String, Object?>{'scope': scope, 'cursor': ?at},
      );

      if (!response.successful) {
        return _PullResult(
          cursor: at,
          adopted: adopted,
          failure: _failureOf(response, 'pull'),
        );
      }

      final Map<String, dynamic>? body = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : null;

      if (body == null) {
        return _PullResult(
          cursor: at,
          adopted: adopted,
          failure: 'pull answered a body that is not an object',
        );
      }

      adopted += await _adopt(account: account, body: body);

      final Object? next = body['cursor'];
      at = next is String ? next : at;

      if (body['has_more'] != true) {
        return _PullResult(cursor: at, adopted: adopted, failure: null);
      }
    }

    return _PullResult(
      cursor: at,
      adopted: adopted,
      failure: 'pull did not finish in $maxPages pages',
    );
  }

  /// Writes every row in a `{"data": [...]}` body, answering how many were
  /// newer than what this device already held.
  Future<int> _adopt({required String account, required Object? body}) async {
    if (body is! Map<String, dynamic>) return 0;

    final Object? rows = body['data'];

    if (rows is! List) return 0;

    int adopted = 0;

    for (final Object? row in rows) {
      if (row is! Map<String, dynamic>) continue;

      if (await adoptRow(account: account, row: row)) adopted++;
    }

    return adopted;
  }

  /// A failure line carrying the status and nothing from the body.
  ///
  /// The body is not interpolated on purpose: a failure string is the kind
  /// of value that ends up in a log, and a 4xx from a proxy in front of this
  /// API can echo the request.
  String _failureOf(MagicResponse response, String half) =>
      '$half failed with HTTP ${response.statusCode}';
}

/// What one push half produced.
class _PushResult {
  const _PushResult({
    required this.sent,
    required this.mark,
    required this.failure,
  });

  final int sent;
  final int mark;
  final String? failure;
}

/// What one pull half produced.
class _PullResult {
  const _PullResult({
    required this.cursor,
    required this.adopted,
    required this.failure,
  });

  final String? cursor;
  final int adopted;
  final String? failure;
}
