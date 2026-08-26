import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// One row of the fake collection, mapped the way a consumer maps its own model.
class _Row {
  const _Row(this.id);

  final int id;

  static _Row fromMap(Map<String, dynamic> map) => _Row(map['id'] as int);
}

/// A cursor-paginated body: Laravel's `cursorPaginate()` envelope.
Map<String, dynamic> _cursorPage(List<int> ids, {String? next}) {
  return <String, dynamic>{
    'data': <Map<String, dynamic>>[
      for (final int id in ids) <String, dynamic>{'id': id},
    ],
    'meta': <String, dynamic>{
      'next_cursor': next,
      'prev_cursor': null,
      'per_page': ids.length,
    },
  };
}

/// An offset-paginated body: Laravel's `paginate()` envelope.
Map<String, dynamic> _offsetPage(
  List<int> ids, {
  required int currentPage,
  required int lastPage,
}) {
  return <String, dynamic>{
    'data': <Map<String, dynamic>>[
      for (final int id in ids) <String, dynamic>{'id': id},
    ],
    'meta': <String, dynamic>{
      'current_page': currentPage,
      'last_page': lastPage,
      'per_page': ids.length,
      'total': ids.length * lastPage,
    },
  };
}

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  tearDown(Http.unfake);

  group('MagicPaginator cursor mode', () {
    test('the first load fills items and reports more to come', () async {
      Http.fake(
        (_) => Http.response(_cursorPage(<int>[1, 2], next: 'cur-2'), 200),
      );
      final paginator = MagicPaginator<_Row>(
        url: 'checks',
        fromMap: _Row.fromMap,
      );

      await paginator.loadFirst();

      expect(paginator.items.map((_Row r) => r.id), <int>[1, 2]);
      expect(paginator.hasMore, isTrue);
      expect(paginator.isLoading, isFalse);
      expect(paginator.error, isNull);
    });

    test('loadMore sends the cursor it was given and APPENDS', () async {
      // The whole point of cursor mode: page two is addressed by the token the
      // server handed back, not by an offset that drifts when a row lands on
      // top of the table between the two requests.
      final fake = Http.fake((MagicRequest request) {
        final Object? cursor = request.queryParameters?['cursor'];

        return cursor == null
            ? Http.response(_cursorPage(<int>[1, 2], next: 'cur-2'), 200)
            : Http.response(_cursorPage(<int>[3, 4]), 200);
      });
      final paginator = MagicPaginator<_Row>(
        url: 'checks',
        fromMap: _Row.fromMap,
      );

      await paginator.loadFirst();
      await paginator.loadMore();

      expect(paginator.items.map((_Row r) => r.id), <int>[
        1,
        2,
        3,
        4,
      ], reason: 'page two is appended, not swapped in');
      expect(
        paginator.hasMore,
        isFalse,
        reason: 'a null next_cursor is the end',
      );
      fake.assertSent(
        (MagicRequest r) => r.queryParameters?['cursor'] == 'cur-2',
      );
    });

    test('the last cursor page still reports cursor mode', () async {
      // On the last page `next_cursor` is present and null. Branching on the
      // value rather than the key would classify that page as unpaginated,
      // which is a false statement about the endpoint to anything reading
      // `mode`, even though `hasMore` lands on false either way.
      Http.fake((_) => Http.response(_cursorPage(<int>[1]), 200));
      final paginator = MagicPaginator<_Row>(
        url: 'checks',
        fromMap: _Row.fromMap,
      );

      await paginator.loadFirst();

      expect(paginator.mode, PaginationMode.cursor);
      expect(paginator.hasMore, isFalse);
    });

    test('loadMore past the end sends nothing', () async {
      final fake = Http.fake((_) => Http.response(_cursorPage(<int>[1]), 200));
      final paginator = MagicPaginator<_Row>(
        url: 'checks',
        fromMap: _Row.fromMap,
      );

      await paginator.loadFirst();
      await paginator.loadMore();

      fake.assertSentCount(1);
    });
  });

  group('MagicPaginator offset mode', () {
    test('reads the page numbers and appends the next page', () async {
      final fake = Http.fake((MagicRequest request) {
        final Object? page = request.queryParameters?['page'];

        return page == null || page == 1
            ? Http.response(
                _offsetPage(<int>[1, 2], currentPage: 1, lastPage: 2),
                200,
              )
            : Http.response(
                _offsetPage(<int>[3, 4], currentPage: 2, lastPage: 2),
                200,
              );
      });
      final paginator = MagicPaginator<_Row>(
        url: 'checks',
        fromMap: _Row.fromMap,
      );

      await paginator.loadFirst();
      expect(paginator.hasMore, isTrue);

      await paginator.loadMore();

      expect(paginator.items.map((_Row r) => r.id), <int>[1, 2, 3, 4]);
      expect(
        paginator.hasMore,
        isFalse,
        reason: 'current_page has reached last_page',
      );
      fake.assertSent((MagicRequest r) => r.queryParameters?['page'] == 2);
    });
  });

  group('MagicPaginator without an envelope', () {
    test('a bare data array is one page and nothing follows it', () async {
      // An endpoint that returns a plain collection has no meta block. That is
      // not an error and not an empty list: it is a complete result.
      final fake = Http.fake(
        (_) => Http.response(<String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{'id': 7},
          ],
        }, 200),
      );
      final paginator = MagicPaginator<_Row>(
        url: 'checks',
        fromMap: _Row.fromMap,
      );

      await paginator.loadFirst();
      await paginator.loadMore();

      expect(paginator.items.single.id, 7);
      expect(paginator.hasMore, isFalse);
      fake.assertSentCount(1);
    });

    test('an empty first page reports empty rather than more', () async {
      Http.fake(
        (_) => Http.response(<String, dynamic>{'data': <dynamic>[]}, 200),
      );
      final paginator = MagicPaginator<_Row>(
        url: 'checks',
        fromMap: _Row.fromMap,
      );

      await paginator.loadFirst();

      expect(paginator.items, isEmpty);
      expect(paginator.isEmpty, isTrue);
      expect(paginator.hasMore, isFalse);
    });
  });

  group('MagicPaginator guards', () {
    test('two overlapping loadMore calls fetch one page', () async {
      // The defect this pins: an infinite-scroll list fires loadMore from a
      // scroll callback, which runs on EVERY frame near the end. Without a
      // guard the same page is requested several times and appended several
      // times, so the list shows each row two or three times.
      final fake = Http.fake((MagicRequest request) {
        final Object? cursor = request.queryParameters?['cursor'];

        return cursor == null
            ? Http.response(_cursorPage(<int>[1], next: 'cur-2'), 200)
            : Http.response(_cursorPage(<int>[2], next: 'cur-3'), 200);
      });
      final paginator = MagicPaginator<_Row>(
        url: 'checks',
        fromMap: _Row.fromMap,
      );
      await paginator.loadFirst();

      await Future.wait(<Future<void>>[
        paginator.loadMore(),
        paginator.loadMore(),
        paginator.loadMore(),
      ]);

      expect(paginator.items.map((_Row r) => r.id), <int>[
        1,
        2,
      ], reason: 'the second page is fetched once and appended once');
      fake.assertSentCount(2);
    });

    test('a failed loadMore keeps the rows already on screen', () async {
      // Losing page one because page two timed out is worse than the timeout.
      final fake = Http.fake((MagicRequest request) {
        final Object? cursor = request.queryParameters?['cursor'];

        return cursor == null
            ? Http.response(_cursorPage(<int>[1, 2], next: 'cur-2'), 200)
            : Http.response(<String, dynamic>{'message': 'Server error'}, 500);
      });
      final paginator = MagicPaginator<_Row>(
        url: 'checks',
        fromMap: _Row.fromMap,
      );
      await paginator.loadFirst();

      await paginator.loadMore();

      expect(paginator.items.map((_Row r) => r.id), <int>[1, 2]);
      expect(paginator.error, isNotNull);
      expect(
        paginator.hasMore,
        isTrue,
        reason: 'the page is still out there; a retry has to remain possible',
      );
      fake.assertSentCount(2);
    });

    test('refresh replaces the rows and starts from the first page', () async {
      final fake = Http.fake((MagicRequest request) {
        final Object? cursor = request.queryParameters?['cursor'];

        return cursor == null
            ? Http.response(_cursorPage(<int>[1], next: 'cur-2'), 200)
            : Http.response(_cursorPage(<int>[2]), 200);
      });
      final paginator = MagicPaginator<_Row>(
        url: 'checks',
        fromMap: _Row.fromMap,
      );
      await paginator.loadFirst();
      await paginator.loadMore();
      expect(paginator.items.length, 2);

      await paginator.refresh();

      expect(paginator.items.map((_Row r) => r.id), <int>[
        1,
      ], reason: 'a refresh is a new first page, not more rows');
      expect(paginator.hasMore, isTrue);
      fake.assertSent((MagicRequest r) => r.queryParameters?['cursor'] == null);
    });

    test('disposing while a page is in flight does not throw', () async {
      // A controller that owns a paginator disposes it in onClose, so any
      // navigate-away during a fetch lands here. `notifyListeners` after the
      // await would throw "used after being disposed" and take the navigation
      // with it.
      Http.fake((_) => Http.response(_cursorPage(<int>[1]), 200));
      final paginator = MagicPaginator<_Row>(
        url: 'checks',
        fromMap: _Row.fromMap,
      );

      final Future<void> inFlight = paginator.loadFirst();
      paginator.dispose();

      await expectLater(inFlight, completes);
    });

    test('a transport failure is an error, not an empty collection', () async {
      // `DioNetworkDriver._handleError` reports a timeout or a dead link as
      // statusCode 0, which is neither `failed` (>= 400) nor `successful`. Read
      // through `failed` it takes the SUCCESS path, so an offline first page
      // renders the empty state and says nothing went wrong.
      Http.fake((_) => Http.response(<String, dynamic>{}, 0));
      final paginator = MagicPaginator<_Row>(
        url: 'checks',
        fromMap: _Row.fromMap,
      );

      await paginator.loadFirst();

      expect(paginator.error, isNotNull, reason: 'nobody answered');
      expect(
        paginator.isEmpty,
        isFalse,
        reason: '"no rows" and "no answer" are different screens',
      );
    });

    test('refresh during an in-flight loadMore still refreshes', () async {
      // Pull-to-refresh while the tail is auto-fetching used to return
      // immediately and do nothing, so the indicator retracted over stale rows.
      int firstPages = 0;
      Http.fake((MagicRequest request) {
        if (request.queryParameters?['cursor'] == null) firstPages++;

        return request.queryParameters?['cursor'] == null
            ? Http.response(_cursorPage(<int>[1], next: 'cur-2'), 200)
            : Http.response(_cursorPage(<int>[2], next: 'cur-3'), 200);
      });
      final paginator = MagicPaginator<_Row>(
        url: 'checks',
        fromMap: _Row.fromMap,
      );
      await paginator.loadFirst();
      expect(firstPages, 1);

      final Future<void> more = paginator.loadMore();
      final Future<void> again = paginator.refresh();
      await Future.wait(<Future<void>>[more, again]);

      expect(firstPages, 2, reason: 'the refresh actually went out');
      expect(paginator.items.map((_Row r) => r.id), <int>[
        1,
      ], reason: 'and it replaced the rows rather than appending to them');
    });

    test('overlapping refreshes collapse into one first page', () async {
      // Each queued reset used to chain onto whatever was in flight when its
      // callback ran, so N refreshes became N sequential first-page fetches. A
      // double-tapped retry button paid for it twice.
      int firstPages = 0;
      Http.fake((MagicRequest request) {
        if (request.queryParameters?['cursor'] == null) firstPages++;

        return request.queryParameters?['cursor'] == null
            ? Http.response(_cursorPage(<int>[1], next: 'cur-2'), 200)
            : Http.response(_cursorPage(<int>[2], next: 'cur-3'), 200);
      });
      final paginator = MagicPaginator<_Row>(
        url: 'checks',
        fromMap: _Row.fromMap,
      );
      await paginator.loadFirst();
      expect(firstPages, 1);

      await Future.wait(<Future<void>>[
        paginator.loadMore(),
        paginator.refresh(),
        paginator.refresh(),
        paginator.refresh(),
      ]);

      expect(
        firstPages,
        2,
        reason: 'the three refreshes are one reload, not three',
      );
    });

    test('reading items twice does not copy the collection', () async {
      // The widget reads `items` once per build, so a copy here is a full copy
      // of the collection on every frame the reader scrolls, in the one class
      // whose whole purpose is not paying per row.
      Http.fake((_) => Http.response(_cursorPage(<int>[1, 2, 3]), 200));
      final paginator = MagicPaginator<_Row>(
        url: 'checks',
        fromMap: _Row.fromMap,
      );
      await paginator.loadFirst();

      expect(identical(paginator.items, paginator.items), isTrue);
      expect(
        () => paginator.items.add(const _Row(9)),
        throwsUnsupportedError,
        reason: 'a live view, but still not writable from outside',
      );
    });

    test('perPage travels as Laravel spells it', () async {
      final fake = Http.fake((_) => Http.response(_cursorPage(<int>[1]), 200));
      final paginator = MagicPaginator<_Row>(
        url: 'checks',
        fromMap: _Row.fromMap,
        perPage: 25,
      );

      await paginator.loadFirst();

      fake.assertSent((MagicRequest r) => r.queryParameters?['per_page'] == 25);
    });

    test('notifies its listeners as the page lands', () async {
      Http.fake((_) => Http.response(_cursorPage(<int>[1]), 200));
      final paginator = MagicPaginator<_Row>(
        url: 'checks',
        fromMap: _Row.fromMap,
      );
      int notifications = 0;
      paginator.addListener(() => notifications++);

      await paginator.loadFirst();

      expect(
        notifications,
        greaterThanOrEqualTo(2),
        reason: 'one for entering loading, one for the result',
      );
    });
  });
}
