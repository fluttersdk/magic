import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// The same minimal remote model `repository_test.dart` uses.
class _TestRow extends Model {
  @override
  String get table => 'rows';

  @override
  String get resource => 'rows';

  @override
  List<String> get fillable => <String>['id', 'name'];

  static _TestRow fromMap(Map<String, dynamic> map) {
    return _TestRow()
      ..fill(map)
      ..exists = true;
  }
}

class _TestRepository extends Repository<_TestRow> {
  @override
  String get resource => 'rows';

  @override
  _TestRow Function(Map<String, dynamic>) get fromMap => _TestRow.fromMap;
}

/// One cursor-paginated `GET /rows` body.
MagicResponse _page(List<Map<String, dynamic>> rows, {String? next}) {
  return Http.response(<String, dynamic>{
    'data': rows,
    'meta': <String, dynamic>{'next_cursor': next},
  }, 200);
}

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  tearDown(Http.unfake);

  group('RepositoryQuery paging', () {
    test(
      'reload fills items from the repository and reports more to come',
      () async {
        final _TestRepository repo = _TestRepository();
        Http.fake((MagicRequest request) {
          final Object? cursor = request.queryParameters?['cursor'];

          return cursor == null
              ? _page(<Map<String, dynamic>>[
                  <String, dynamic>{'id': '1', 'name': 'a'},
                  <String, dynamic>{'id': '2', 'name': 'b'},
                ], next: 'c2')
              : _page(<Map<String, dynamic>>[
                  <String, dynamic>{'id': '3', 'name': 'c'},
                ]);
        });

        final RepositoryQuery<_TestRow> query = RepositoryQuery<_TestRow>(
          repository: repo,
          perPage: 2,
        );

        expect(query.isFirstLoad, isTrue);

        await query.reload();

        expect(
          query.items.map((_TestRow r) => r.getAttribute('name')),
          <String>['a', 'b'],
        );
        expect(query.hasMore, isTrue);
        expect(query.isFirstLoad, isFalse);

        await query.loadMore();

        expect(
          query.items.map((_TestRow r) => r.getAttribute('name')),
          <String>['a', 'b', 'c'],
        );
        expect(query.hasMore, isFalse);

        // Every fetched row lands in the repository too, not only the query.
        expect(repo.all, hasLength(3));
      },
    );

    test('a reload racing a loadMore does not strand isLoadingMore', () async {
      // Mirrors depools' product_controller_test.dart:46-81: a reset landing
      // while a next page is in flight must not leave the footer's flag
      // stuck forever. MagicPaginator.fetcher already guards this; the test
      // proves the guard survives being wrapped by RepositoryQuery.
      final _TestRepository repo = _TestRepository();
      Http.fake((MagicRequest request) {
        final Object? cursor = request.queryParameters?['cursor'];

        return cursor != null
            ? _page(<Map<String, dynamic>>[
                <String, dynamic>{'id': '2', 'name': 'b'},
              ])
            : _page(<Map<String, dynamic>>[
                <String, dynamic>{'id': '1', 'name': 'a'},
              ], next: 'c2');
      });

      final RepositoryQuery<_TestRow> query = RepositoryQuery<_TestRow>(
        repository: repo,
      );
      await query.reload();

      expect(query.hasMore, isTrue);
      expect(query.isLoadingMore, isFalse);

      final Future<void> inFlight = query.loadMore();
      await query.reload();
      await inFlight;

      expect(
        query.isLoadingMore,
        isFalse,
        reason: 'an abandoned page must not leave the flag stuck',
      );

      // And the proof that it is not merely a flag: another page can still
      // be asked for.
      await query.loadMore();
    });

    test(
      'ensureFresh joins an in-flight first load with a single GET',
      () async {
        final _TestRepository repo = _TestRepository();
        final FakeNetworkDriver fake = Http.fake(
          (_) => _page(<Map<String, dynamic>>[
            <String, dynamic>{'id': '1', 'name': 'a'},
          ]),
        );

        final RepositoryQuery<_TestRow> query = RepositoryQuery<_TestRow>(
          repository: repo,
        );

        final Future<void> first = query.reload();
        await query.ensureFresh();
        await first;

        fake.assertSentCount(1);
      },
    );

    test('setFilters resets to the first page with the new filter', () async {
      final _TestRepository repo = _TestRepository();
      final FakeNetworkDriver fake = Http.fake(
        (_) => _page(<Map<String, dynamic>>[
          <String, dynamic>{'id': '1', 'name': 'a'},
        ]),
      );

      final RepositoryQuery<_TestRow> query = RepositoryQuery<_TestRow>(
        repository: repo,
      );
      await query.reload();

      await query.setFilters(<String, dynamic>{'status': 'down'});

      fake.assertSent(
        (MagicRequest r) => r.queryParameters?['status'] == 'down',
      );
      expect(query.items, hasLength(1));
    });

    test('meta is read from the response envelope', () async {
      final _TestRepository repo = _TestRepository();
      Http.fake(
        (_) => Http.response(<String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{'id': '1', 'name': 'a'},
          ],
          'meta': <String, dynamic>{'next_cursor': null, 'total': 42},
        }, 200),
      );

      final RepositoryQuery<_TestRow> query = RepositoryQuery<_TestRow>(
        repository: repo,
      );
      await query.reload();

      expect(query.meta['total'], 42);
    });
  });

  group('RepositoryQuery.loadFailed', () {
    test(
      'a 2xx whose data is not a list is a failed read, not an empty page',
      () async {
        final _TestRepository repo = _TestRepository();
        bool unreadable = false;
        Http.fake((_) {
          if (unreadable) return Http.response(<String, dynamic>{}, 200);

          return _page(<Map<String, dynamic>>[
            <String, dynamic>{'id': '1', 'name': 'a'},
          ]);
        });
        final RepositoryQuery<_TestRow> query = RepositoryQuery<_TestRow>(
          repository: repo,
        );
        await query.reload();

        unreadable = true;
        await query.reload();

        // The rows the operator was reading survive a body nobody can read.
        expect(query.items.map((_TestRow r) => r.id), <Object?>['1']);
      },
    );

    test('is true only when the failed read left nothing to show', () async {
      final _TestRepository repo = _TestRepository();
      Http.fake((_) => Http.response(<String, dynamic>{}, 500));

      final RepositoryQuery<_TestRow> query = RepositoryQuery<_TestRow>(
        repository: repo,
      );
      await query.reload();

      expect(query.loadFailed, isTrue);
    });

    test('stays false when a failed reload leaves rows on screen', () async {
      final _TestRepository repo = _TestRepository();
      bool fail = false;
      Http.fake((_) {
        if (fail) return Http.response(<String, dynamic>{}, 500);

        return _page(<Map<String, dynamic>>[
          <String, dynamic>{'id': '1', 'name': 'a'},
        ]);
      });

      final RepositoryQuery<_TestRow> query = RepositoryQuery<_TestRow>(
        repository: repo,
      );
      await query.reload();

      fail = true;
      await query.reload();

      expect(query.loadFailed, isFalse);
      expect(query.items, isNotEmpty);
    });
  });

  group('RepositoryQuery notification timing', () {
    test(
      'reload() delivers no notification synchronously, so a view initState may call it',
      () async {
        final _TestRepository repo = _TestRepository();
        Http.fake(
          (_) => _page(<Map<String, dynamic>>[
            <String, dynamic>{'id': '1', 'name': 'a'},
          ]),
        );
        final RepositoryQuery<_TestRow> query = RepositoryQuery<_TestRow>(
          repository: repo,
        );
        int calls = 0;
        query.addListener(() => calls++);

        // A listener notified inside this call would mark another mounted
        // widget dirty while the tree is building.
        final Future<void> pending = query.reload();
        expect(calls, 0);

        await pending;
        expect(calls, greaterThan(0));
        expect(query.items, isNotEmpty);
      },
    );
  });

  group('RepositoryQuery reads through the repository live', () {
    test('a repository patch shows in items without a refetch', () async {
      final _TestRepository repo = _TestRepository();
      Http.fake(
        (_) => _page(<Map<String, dynamic>>[
          <String, dynamic>{'id': '1', 'name': 'a'},
        ]),
      );
      final RepositoryQuery<_TestRow> query = RepositoryQuery<_TestRow>(
        repository: repo,
      );
      await query.reload();

      repo.patch('1', <String, dynamic>{'name': 'patched'});

      expect(query.items.single.getAttribute('name'), 'patched');
    });

    test('a repository evict removes the row from items', () async {
      final _TestRepository repo = _TestRepository();
      Http.fake(
        (_) => _page(<Map<String, dynamic>>[
          <String, dynamic>{'id': '1', 'name': 'a'},
        ]),
      );
      final RepositoryQuery<_TestRow> query = RepositoryQuery<_TestRow>(
        repository: repo,
      );
      await query.reload();

      repo.evict('1');

      expect(query.items, isEmpty);
    });

    test('notifies its own listeners when the repository changes', () async {
      final _TestRepository repo = _TestRepository();
      Http.fake(
        (_) => _page(<Map<String, dynamic>>[
          <String, dynamic>{'id': '1', 'name': 'a'},
        ]),
      );
      final RepositoryQuery<_TestRow> query = RepositoryQuery<_TestRow>(
        repository: repo,
      );
      await query.reload();

      bool notified = false;
      query.addListener(() => notified = true);

      repo.patch('1', <String, dynamic>{'name': 'b'});

      expect(notified, isTrue);
    });

    test('dispose stops forwarding repository notifications', () async {
      final _TestRepository repo = _TestRepository();
      Http.fake(
        (_) => _page(<Map<String, dynamic>>[
          <String, dynamic>{'id': '1', 'name': 'a'},
        ]),
      );
      final RepositoryQuery<_TestRow> query = RepositoryQuery<_TestRow>(
        repository: repo,
      );
      await query.reload();
      query.dispose();

      // Must not throw: a disposed query removed itself as a listener before
      // this point, so the repository notifying is a no-op for it.
      repo.patch('1', <String, dynamic>{'name': 'b'});
    });
  });

  group('RepositoryQuery session scope', () {
    test('a repository reset clears a live query too', () async {
      final _TestRepository repo = _TestRepository();
      Http.fake(
        (_) => _page(<Map<String, dynamic>>[
          <String, dynamic>{'id': '1', 'name': 'a'},
        ], next: 'c2'),
      );
      final RepositoryQuery<_TestRow> query = RepositoryQuery<_TestRow>(
        repository: repo,
      );
      await query.reload();

      expect(query.items, isNotEmpty);
      expect(query.hasMore, isTrue);

      await repo.resetForSession();

      expect(query.items, isEmpty);
      expect(query.isFirstLoad, isTrue);
      expect(query.hasMore, isFalse);
    });

    test(
      'a page that lands after a session reset writes nothing into the new session',
      () async {
        final _TestRepository repo = _TestRepository();
        Http.fake(
          (_) => _page(<Map<String, dynamic>>[
            <String, dynamic>{'id': '1', 'name': 'previous tenant'},
          ]),
        );
        final RepositoryQuery<_TestRow> query = RepositoryQuery<_TestRow>(
          repository: repo,
        );

        // The read is in flight when the identity changes: its answer belongs
        // to the session that asked, not to the one that exists when it lands.
        final Future<void> pending = query.reload();
        repo.resetForSession();
        await pending;

        expect(repo.find('1'), isNull);
        expect(query.items, isEmpty);
        expect(query.isFirstLoad, isTrue);
      },
    );
  });
}
