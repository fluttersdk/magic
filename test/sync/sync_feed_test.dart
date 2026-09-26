import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:sqlite3/sqlite3.dart';

/// A minimal [SyncFeed] whose pending rows, adoption outcome, batch size and
/// page bound are all handed in by the test, so one class covers every QA
/// scenario instead of a subclass per test.
class _TestFeed extends SyncFeed {
  _TestFeed({
    required this.resource,
    this.batchSize = 500,
    this.maxPages = 100,
    this.pendingRows = const <SyncPushRow>[],
    Future<bool> Function({
      required String account,
      required Map<String, dynamic> row,
    })?
    onAdoptRow,
  }) : _onAdoptRow = onAdoptRow;

  @override
  final String resource;

  @override
  String get envelopeKey => 'rows';

  @override
  final int batchSize;

  @override
  final int maxPages;

  /// The rows [pending] answers, unconditionally of the arguments it is
  /// called with: no scenario here needs a real `sinceMillis` filter.
  final List<SyncPushRow> pendingRows;

  final Future<bool> Function({
    required String account,
    required Map<String, dynamic> row,
  })?
  _onAdoptRow;

  /// Every row [adoptRow] was asked to write, in call order.
  final List<Map<String, dynamic>> adopted = <Map<String, dynamic>>[];

  @override
  String get feed => 'test-feed';

  @override
  Future<List<SyncPushRow>> pending({
    required String account,
    required int sinceMillis,
    required String scope,
  }) async => pendingRows;

  @override
  Future<bool> adoptRow({
    required String account,
    required Map<String, dynamic> row,
  }) async {
    adopted.add(row);
    if (_onAdoptRow != null) return _onAdoptRow(account: account, row: row);
    return true;
  }
}

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Magic.singleton('log', () => LogManager());
    DatabaseManager().setConnection(sqlite3.openInMemory());
    CreateSyncCursorsTable().up();
  });

  tearDown(DatabaseManager().dispose);

  test(
    "a 2-batch push where the second batch answers 500 advances the stored mark "
    "to the first batch's last mark and reports the failure",
    () async {
      int postCalls = 0;

      Http.fake((MagicRequest request) {
        if (request.method == 'POST') {
          postCalls++;
          if (postCalls == 1) return Http.response({'data': <Object?>[]}, 200);
          return Http.response({'message': 'server error'}, 500);
        }

        return Http.response({'data': <Object?>[], 'has_more': false}, 200);
      });

      final _TestFeed feed = _TestFeed(
        resource: 'items',
        batchSize: 2,
        pendingRows: const <SyncPushRow>[
          (data: {'id': 1}, mark: 100),
          (data: {'id': 2}, mark: 200),
          (data: {'id': 3}, mark: 300),
        ],
      );

      final SyncReport report = await feed.run(
        scope: 'scope-a',
        account: 'acc-1',
      );

      expect(report.complete, isFalse);
      expect(report.failure, contains('push failed with HTTP 500'));
      expect(report.pushed, 2);

      final SyncBookmarks bookmarks = const SyncLedger().read(
        scope: 'scope-a',
        feed: 'test-feed',
      );
      expect(
        bookmarks.pushMark,
        200,
        reason: 'only the first (succeeded) batch may advance the mark',
      );
      expect(
        bookmarks.pullCursor,
        isNull,
        reason: 'a failed push never reaches the pull half',
      );
    },
  );

  test("a pull over 3 pages stores the last page's cursor", () async {
    int getCalls = 0;

    Http.fake((MagicRequest request) {
      if (request.method == 'GET') {
        getCalls++;
        final bool last = getCalls == 3;
        return Http.response({
          'data': <Object?>[],
          'cursor': 'page-$getCalls',
          'has_more': !last,
        }, 200);
      }

      return Http.response({'data': <Object?>[]}, 200);
    });

    final _TestFeed feed = _TestFeed(resource: 'items');

    final SyncReport report = await feed.run(
      scope: 'scope-b',
      account: 'acc-1',
    );

    expect(report.complete, isTrue);
    expect(getCalls, 3);

    final SyncBookmarks bookmarks = const SyncLedger().read(
      scope: 'scope-b',
      feed: 'test-feed',
    );
    expect(bookmarks.pullCursor, 'page-3');
  });

  test('a pull that never ends stops at maxPages with a failure', () async {
    Http.fake((MagicRequest request) {
      if (request.method == 'GET') {
        return Http.response({
          'data': <Object?>[],
          'cursor': 'same',
          'has_more': true,
        }, 200);
      }

      return Http.response({'data': <Object?>[]}, 200);
    });

    final _TestFeed feed = _TestFeed(resource: 'items', maxPages: 3);

    final SyncReport report = await feed.run(
      scope: 'scope-c',
      account: 'acc-1',
    );

    expect(report.complete, isFalse);
    expect(report.failure, contains('3 pages'));
  });

  test(
    'an adoptRow that throws yields a failure report, not a throw',
    () async {
      Http.fake((MagicRequest request) {
        if (request.method == 'GET') {
          return Http.response({
            'data': <Object?>[
              {'id': 1},
            ],
            'has_more': false,
          }, 200);
        }

        return Http.response({'data': <Object?>[]}, 200);
      });

      final _TestFeed feed = _TestFeed(
        resource: 'items',
        onAdoptRow:
            ({
              required String account,
              required Map<String, dynamic> row,
            }) async {
              throw StateError('cannot adopt this row');
            },
      );

      final SyncReport report = await feed.run(
        scope: 'scope-d',
        account: 'acc-1',
      );

      expect(report.complete, isFalse);
      expect(report.failure, isNotNull);
    },
  );

  test(
    'a feed whose resource is "items" requests /items/sync and /items',
    () async {
      final FakeNetworkDriver fake = Http.fake(
        (MagicRequest request) =>
            Http.response({'data': <Object?>[], 'has_more': false}, 200),
      );

      final _TestFeed feed = _TestFeed(
        resource: 'items',
        pendingRows: const <SyncPushRow>[
          (data: {'id': 1}, mark: 1),
        ],
      );

      await feed.run(scope: 'scope-e', account: 'acc-1');

      fake.assertSent(
        (MagicRequest r) => r.method == 'POST' && r.url == '/items/sync',
      );
      fake.assertSent(
        (MagicRequest r) => r.method == 'GET' && r.url == '/items',
      );
    },
  );
}
