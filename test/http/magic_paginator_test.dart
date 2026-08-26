import 'dart:async';

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

  group('MagicPaginator over a fetcher', () {
    test('pages a source that is not a bare url', () async {
      // Not every collection arrives from `Http.get(url)`. A billing history
      // comes through a swappable rail service whose store build throws rather
      // than answering, so pointing a url-based paginator at the endpoint would
      // walk around the abstraction that exists to keep that build honest.
      final List<String?> cursorsSeen = <String?>[];
      final paginator = MagicPaginator<_Row>.fetcher(
        fetch: (MagicPageRequest request) async {
          cursorsSeen.add(request.cursor);

          return request.isFirst
              ? MagicPage<_Row>(
                  items: <_Row>[const _Row(1), const _Row(2)],
                  nextCursor: 'cur-2',
                )
              : MagicPage<_Row>(items: <_Row>[const _Row(3)]);
        },
      );

      await paginator.loadFirst();
      expect(paginator.hasMore, isTrue);

      await paginator.loadMore();

      expect(paginator.items.map((_Row r) => r.id), <int>[1, 2, 3]);
      expect(paginator.hasMore, isFalse);
      expect(cursorsSeen, <String?>[null, 'cur-2']);
    });

    test('a fetcher that throws is an error, not an empty collection', () async {
      // Same rule the url mode follows: the rows in hand stay, and "no answer"
      // is not "no rows". A rail that refuses on this platform throws rather
      // than returning a status code, so the catch is what turns it into state.
      bool broken = false;
      final paginator = MagicPaginator<_Row>.fetcher(
        fetch: (MagicPageRequest request) async {
          // An Exception, deliberately: a rail refusing is a condition, and the
          // Errors (a bad cast, a failed assertion) are this code being wrong
          // and are meant to propagate rather than land in `error`.
          if (broken) throw Exception('rail unavailable');

          return MagicPage<_Row>(
            items: <_Row>[const _Row(1)],
            nextCursor: 'cur-2',
          );
        },
      );
      await paginator.loadFirst();

      broken = true;
      await paginator.loadMore();

      expect(paginator.items.map((_Row r) => r.id), <int>[1]);
      expect(paginator.error, isNotNull);
      expect(paginator.isEmpty, isFalse);
      expect(
        paginator.hasMore,
        isTrue,
        reason: 'the page is still out there, so a retry needs its target',
      );
    });

    test('hasMore can be reported without a cursor', () async {
      // A source that pages by something the paginator never sees (an offset it
      // keeps itself, a page number) still has to be able to say "there is
      // more", so `hasMore` is settable independently of `nextCursor`.
      int calls = 0;
      final paginator = MagicPaginator<_Row>.fetcher(
        fetch: (MagicPageRequest request) async {
          calls++;

          return MagicPage<_Row>(
            items: <_Row>[_Row(calls)],
            hasMore: calls < 3,
          );
        },
      );

      await paginator.loadFirst();
      await paginator.loadMore();
      expect(paginator.hasMore, isTrue);
      await paginator.loadMore();

      expect(paginator.items.map((_Row r) => r.id), <int>[1, 2, 3]);
      expect(paginator.hasMore, isFalse);
      expect(calls, 3);
    });

    test('refresh restarts a fetcher that keeps its own page number', () async {
      // The defect: `reset` was collapsed into the cursor, so a cursorless
      // fetcher received null for BOTH "first page" and "next page" and had no
      // way to tell a refresh from a continuation. Following the pattern this
      // package's own docs recommend (`hasMore: page < last`), a pull-to-refresh
      // therefore cleared the rows and rendered page THREE as the whole list.
      int page = 0;
      final paginator = MagicPaginator<_Row>.fetcher(
        fetch: (MagicPageRequest request) async {
          if (request.isFirst) page = 0;
          page++;

          return MagicPage<_Row>(items: <_Row>[_Row(page)], hasMore: page < 3);
        },
      );

      await paginator.loadFirst();
      await paginator.loadMore();
      expect(paginator.items.map((_Row r) => r.id), <int>[1, 2]);

      await paginator.refresh();

      expect(paginator.items.map((_Row r) => r.id), <int>[
        1,
      ], reason: 'a refresh is the first page again, not the next one');
      expect(paginator.hasMore, isTrue);
    });

    test('a fetcher source reports its own mode, not a borrowed one', () async {
      // `mode` documents how the SERVER addressed the next page. A fetcher
      // paginator does not know: its source might page by token, by number, or
      // not at all. Reporting `cursor` for all of them is the same untruth the
      // url path is careful to avoid.
      final paginator = MagicPaginator<_Row>.fetcher(
        fetch: (MagicPageRequest request) async =>
            MagicPage<_Row>(items: <_Row>[const _Row(1)]),
      );

      await paginator.loadFirst();

      expect(paginator.mode, PaginationMode.fetcher);
    });

    test('disposing mid-fetch on the fetcher path does not throw', () async {
      final paginator = MagicPaginator<_Row>.fetcher(
        fetch: (MagicPageRequest request) async {
          await Future<void>.delayed(Duration.zero);

          return MagicPage<_Row>(items: <_Row>[const _Row(1)]);
        },
      );

      final Future<void> inFlight = paginator.loadFirst();
      paginator.dispose();

      await expectLater(inFlight, completes);
    });

    test('an escaping Error still unwinds the loading state', () async {
      // The wedge this closes. `on Exception` lets an Error propagate, which is
      // the point, but the loading flag was cleared AFTER the try/catch, so it
      // stayed true: `loadMore` then returned immediately on it, `refresh` took
      // the deferred branch and chained onto an already-rejected future whose
      // callback never runs, and the paginator was unusable for the rest of its
      // life while the list view showed a footer that never stopped.
      bool broken = true;
      final paginator = MagicPaginator<_Row>.fetcher(
        fetch: (MagicPageRequest request) async {
          if (broken) throw TypeError();

          return MagicPage<_Row>(items: <_Row>[const _Row(7)]);
        },
      );

      await expectLater(paginator.loadFirst(), throwsA(isA<TypeError>()));
      expect(
        paginator.isLoading,
        isFalse,
        reason: 'the object has to be usable again',
      );

      broken = false;
      await paginator.refresh();

      expect(paginator.items.map((_Row r) => r.id), <int>[7]);
    });

    test('a mapper that throws does not wedge the url path either', () async {
      // Same shape one path over, and not named in review: a consumer `fromMap`
      // that hits an unexpected payload throws out of `_absorb`, which had no
      // handler at all, so the loading flag stayed true there too.
      Http.fake(
        (_) => Http.response(<String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'not-an-int'},
          ],
        }, 200),
      );
      final paginator = MagicPaginator<_Row>(
        url: 'checks',
        fromMap: _Row.fromMap,
      );

      await expectLater(paginator.loadFirst(), throwsA(isA<TypeError>()));
      expect(paginator.isLoading, isFalse);
    });

    test(
      'a reset queued behind a failing page does not poison later ones',
      () async {
        // `_pendingReset` was cleared only on the success continuation, so an
        // in-flight run that REJECTED left a rejected future in the field for
        // good. Every later reset-during-flight then hit the `??=` on that stale
        // value: the deferred reload was never scheduled, and whoever awaited it
        // (a RefreshIndicator, say) got the old error back instead.
        int calls = 0;
        final paginator = MagicPaginator<_Row>.fetcher(
          fetch: (MagicPageRequest request) async {
            calls++;
            await Future<void>.delayed(Duration.zero);
            if (calls == 1) throw TypeError();

            return MagicPage<_Row>(items: <_Row>[_Row(calls)], hasMore: true);
          },
        );

        // The failing first page, with a reset arriving while it is in flight.
        final Future<void> first = paginator.loadFirst();
        final Future<void> queued = paginator.refresh();
        await expectLater(first, throwsA(isA<TypeError>()));
        await queued;

        expect(paginator.items, isNotEmpty, reason: 'the queued reset ran');

        // And the field is usable again: another overlapping reset has to land.
        final int before = calls;
        final Future<void> more = paginator.loadMore();
        final Future<void> again = paginator.refresh();
        await Future.wait(<Future<void>>[more, again]);

        expect(
          calls,
          greaterThan(before + 1),
          reason:
              'the second reset was scheduled, not dropped on a stale future',
        );
      },
    );

    test('a mapper that throws mid-page appends nothing', () async {
      // `_absorb` appended through a LAZY map, so a `fromMap` that threw on row
      // three left rows one and two in the collection with `_nextCursor` unset
      // and `_hasMore` true. The next `loadMore` therefore refetched page one
      // and appended those two a second time: duplicate rows on top of the
      // mapper bug. All or nothing is the only honest answer for a page.
      Http.fake(
        (_) => Http.response(<String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{'id': 1},
            <String, dynamic>{'id': 2},
            <String, dynamic>{'id': 'not-an-int'},
          ],
          'meta': <String, dynamic>{'next_cursor': 'cur-2'},
        }, 200),
      );
      final paginator = MagicPaginator<_Row>(
        url: 'checks',
        fromMap: _Row.fromMap,
      );

      await expectLater(paginator.loadFirst(), throwsA(isA<TypeError>()));

      expect(
        paginator.items,
        isEmpty,
        reason: 'a half-mapped page is not a page',
      );
    });

    test('a reset asked for during the deferred restart is not swallowed', () async {
      // Clearing `_pendingReset` at the END of the chain kept the slot occupied
      // for the whole of the restart's own load, so a refresh arriving in that
      // window hit the `??=` and resolved against a request issued BEFORE it was
      // asked for. Silent: no error, and the indicator retracts over the earlier
      // request's rows. It contradicts this class's own "a reset is not dropped"
      // rule, so the slot is cleared at the top of the restart instead.
      final List<int> observed = <int>[];
      late final MagicPaginator<_Row> paginator;
      int calls = 0;
      paginator = MagicPaginator<_Row>.fetcher(
        fetch: (MagicPageRequest request) async {
          calls++;
          final int call = calls;
          observed.add(call);
          await Future<void>.delayed(Duration.zero);

          // Ask for a reset from inside the restart's own page.
          if (call == 2) unawaited(paginator.refresh());

          return MagicPage<_Row>(items: <_Row>[_Row(call)], hasMore: true);
        },
      );

      final Future<void> first = paginator.loadFirst();
      final Future<void> queued = paginator.refresh();
      await Future.wait(<Future<void>>[first, queued]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        observed,
        containsAllInOrder(<int>[1, 2, 3]),
        reason: 'the reset asked for during the restart has to run',
      );
    });

    test('a programming error is not reported as a failed page', () async {
      // A bad cast inside a fetcher is this code being wrong, not the rail
      // refusing. Swallowing it into `error` puts a TypeError message on screen
      // and throws the stack away, so an Error propagates and an Exception is
      // state.
      final paginator = MagicPaginator<_Row>.fetcher(
        fetch: (MagicPageRequest request) async => throw TypeError(),
      );

      await expectLater(paginator.loadFirst(), throwsA(isA<TypeError>()));
      expect(paginator.error, isNull);
    });

    test('the guards hold in fetcher mode too', () async {
      int calls = 0;
      final paginator = MagicPaginator<_Row>.fetcher(
        fetch: (MagicPageRequest request) async {
          calls++;
          await Future<void>.delayed(Duration.zero);

          return MagicPage<_Row>(items: <_Row>[_Row(calls)], hasMore: true);
        },
      );
      await paginator.loadFirst();

      await Future.wait(<Future<void>>[
        paginator.loadMore(),
        paginator.loadMore(),
        paginator.loadMore(),
      ]);

      expect(calls, 2, reason: 'one first page and one overlapping loadMore');
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
