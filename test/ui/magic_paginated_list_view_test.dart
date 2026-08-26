import 'dart:ui' as ui show TextDirection;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// One row of the fake collection.
class _Row {
  const _Row(this.id);

  final int id;

  static _Row fromMap(Map<String, dynamic> map) => _Row(map['id'] as int);
}

Map<String, dynamic> _page(List<int> ids, {String? next}) {
  return <String, dynamic>{
    'data': <Map<String, dynamic>>[
      for (final int id in ids) <String, dynamic>{'id': id},
    ],
    'meta': <String, dynamic>{'next_cursor': next, 'per_page': ids.length},
  };
}

/// Wraps the list in the bounded box a caller is expected to supply, plus the
/// directionality any unwrapped widget test needs.
Widget _host(Widget child, {double height = 300}) {
  return Directionality(
    textDirection: ui.TextDirection.ltr,
    child: Center(
      child: SizedBox(height: height, width: 400, child: child),
    ),
  );
}

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  tearDown(Http.unfake);

  testWidgets('renders one child per row', (WidgetTester tester) async {
    Http.fake((_) => Http.response(_page(<int>[1, 2, 3]), 200));
    final MagicPaginator<_Row> paginator = MagicPaginator<_Row>(
      url: 'rows',
      fromMap: _Row.fromMap,
    );
    await paginator.loadFirst();

    await tester.pumpWidget(
      _host(
        MagicPaginatedListView<_Row>(
          paginator: paginator,
          itemBuilder: (_, _Row row, _) =>
              SizedBox(height: 50, child: Text('row ${row.id}')),
        ),
      ),
    );

    expect(find.text('row 1'), findsOneWidget);
    expect(find.text('row 3'), findsOneWidget);
  });

  testWidgets('builds only what the viewport needs', (
    WidgetTester tester,
  ) async {
    // This is the whole reason the widget exists. The eager alternative (a
    // Column of every row) builds all 500 and pays for them on the first frame;
    // a viewport 300px tall showing 50px rows has room for six.
    Http.fake(
      (_) => Http.response(_page(List<int>.generate(500, (int i) => i)), 200),
    );
    final MagicPaginator<_Row> paginator = MagicPaginator<_Row>(
      url: 'rows',
      fromMap: _Row.fromMap,
    );
    await paginator.loadFirst();
    int built = 0;

    await tester.pumpWidget(
      _host(
        MagicPaginatedListView<_Row>(
          paginator: paginator,
          itemBuilder: (_, _Row row, _) {
            built++;

            return SizedBox(height: 50, child: Text('row ${row.id}'));
          },
        ),
      ),
    );

    expect(paginator.items.length, 500);
    expect(
      built,
      lessThan(30),
      reason: '500 rows must not cost 500 builds; the viewport holds six',
    );
  });

  testWidgets('asks for the next page as the end comes into view', (
    WidgetTester tester,
  ) async {
    int requests = 0;
    Http.fake((MagicRequest request) {
      requests++;

      return request.queryParameters?['cursor'] == null
          ? Http.response(
              _page(List<int>.generate(20, (int i) => i), next: 'cur-2'),
              200,
            )
          : Http.response(
              _page(List<int>.generate(20, (int i) => 100 + i)),
              200,
            );
    });
    final MagicPaginator<_Row> paginator = MagicPaginator<_Row>(
      url: 'rows',
      fromMap: _Row.fromMap,
    );
    await paginator.loadFirst();
    expect(requests, 1);

    await tester.pumpWidget(
      _host(
        MagicPaginatedListView<_Row>(
          paginator: paginator,
          itemBuilder: (_, _Row row, _) =>
              SizedBox(height: 50, child: Text('row ${row.id}')),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();

    expect(requests, 2, reason: 'the tail coming into view is the trigger');
    expect(paginator.items.length, 40);
  });

  testWidgets('a list with nothing more to fetch never asks again', (
    WidgetTester tester,
  ) async {
    int requests = 0;
    Http.fake((_) {
      requests++;

      return Http.response(_page(List<int>.generate(20, (int i) => i)), 200);
    });
    final MagicPaginator<_Row> paginator = MagicPaginator<_Row>(
      url: 'rows',
      fromMap: _Row.fromMap,
    );
    await paginator.loadFirst();

    await tester.pumpWidget(
      _host(
        MagicPaginatedListView<_Row>(
          paginator: paginator,
          itemBuilder: (_, _Row row, _) =>
              SizedBox(height: 50, child: Text('row ${row.id}')),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();

    expect(requests, 1);
  });

  testWidgets('a first page shorter than the viewport still fetches the next', (
    WidgetTester tester,
  ) async {
    // Scroll notifications only fire when the list actually scrolls. A first
    // page that does not fill the viewport is not scrollable, so nothing ever
    // asked for page two and the reader saw a truncated list with no way to
    // extend it. Any perPage smaller than a tall viewport reaches this.
    int requests = 0;
    Http.fake((MagicRequest request) {
      requests++;

      return request.queryParameters?['cursor'] == null
          ? Http.response(_page(<int>[1, 2, 3], next: 'cur-2'), 200)
          : Http.response(
              _page(List<int>.generate(30, (int i) => 100 + i)),
              200,
            );
    });
    final MagicPaginator<_Row> paginator = MagicPaginator<_Row>(
      url: 'rows',
      fromMap: _Row.fromMap,
    );
    await paginator.loadFirst();
    expect(requests, 1);

    await tester.pumpWidget(
      _host(
        MagicPaginatedListView<_Row>(
          paginator: paginator,
          itemBuilder: (_, _Row row, _) =>
              SizedBox(height: 50, child: Text('row ${row.id}')),
        ),
        height: 600,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      requests,
      greaterThan(1),
      reason:
          '150px of rows in a 600px box cannot scroll, so nothing would '
          'have triggered the fetch',
    );
    expect(paginator.items.length, 33);
  });

  testWidgets('a failed page does not retry once per frame', (
    WidgetTester tester,
  ) async {
    // The viewport fill re-arms on every build and a failed loadMore leaves
    // hasMore true on purpose, so the two compose into a fetch per frame
    // against an endpoint that is already failing: build, post-frame, fetch,
    // fail, notify, build. A failure is not an invitation to retry harder.
    int requests = 0;
    Http.fake((MagicRequest request) {
      requests++;

      return request.queryParameters?['cursor'] == null
          ? Http.response(_page(<int>[1, 2, 3], next: 'cur-2'), 200)
          : Http.response(<String, dynamic>{'message': 'Server error'}, 500);
    });
    final MagicPaginator<_Row> paginator = MagicPaginator<_Row>(
      url: 'rows',
      fromMap: _Row.fromMap,
    );
    await paginator.loadFirst();

    await tester.pumpWidget(
      _host(
        MagicPaginatedListView<_Row>(
          paginator: paginator,
          itemBuilder: (_, _Row row, _) =>
              SizedBox(height: 50, child: Text('row ${row.id}')),
        ),
        height: 600,
      ),
    );
    for (int frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(
      requests,
      lessThanOrEqualTo(2),
      reason: 'one first page and at most one attempt at the second',
    );
    expect(paginator.error, isNotNull);
  });

  testWidgets('a page that adds no rows does not retry once per frame', (
    WidgetTester tester,
  ) async {
    // The other shape of the same loop: the server keeps handing back a cursor
    // beside an empty data array, so the rows never grow, the viewport is never
    // filled, and nothing ever says stop.
    int requests = 0;
    Http.fake((MagicRequest request) {
      requests++;

      return request.queryParameters?['cursor'] == null
          ? Http.response(_page(<int>[1, 2, 3], next: 'cur-2'), 200)
          : Http.response(_page(<int>[], next: 'cur-3'), 200);
    });
    final MagicPaginator<_Row> paginator = MagicPaginator<_Row>(
      url: 'rows',
      fromMap: _Row.fromMap,
    );
    await paginator.loadFirst();

    await tester.pumpWidget(
      _host(
        MagicPaginatedListView<_Row>(
          paginator: paginator,
          itemBuilder: (_, _Row row, _) =>
              SizedBox(height: 50, child: Text('row ${row.id}')),
        ),
        height: 600,
      ),
    );
    for (int frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(
      requests,
      lessThanOrEqualTo(2),
      reason: 'a page that added nothing is not worth asking for again',
    );
  });

  testWidgets('an empty result renders the empty state', (
    WidgetTester tester,
  ) async {
    Http.fake(
      (_) => Http.response(<String, dynamic>{'data': <dynamic>[]}, 200),
    );
    final MagicPaginator<_Row> paginator = MagicPaginator<_Row>(
      url: 'rows',
      fromMap: _Row.fromMap,
    );
    await paginator.loadFirst();

    await tester.pumpWidget(
      _host(
        MagicPaginatedListView<_Row>(
          paginator: paginator,
          emptyState: const Text('nothing here'),
          itemBuilder: (_, _Row row, _) => Text('row ${row.id}'),
        ),
      ),
    );

    expect(find.text('nothing here'), findsOneWidget);
  });

  testWidgets('rows appended after the first frame show up', (
    WidgetTester tester,
  ) async {
    // The widget listens to the paginator, so a page that lands later reaches
    // the screen without the caller rebuilding anything.
    Http.fake(
      (MagicRequest request) => request.queryParameters?['cursor'] == null
          ? Http.response(_page(<int>[1], next: 'cur-2'), 200)
          : Http.response(_page(<int>[2]), 200),
    );
    final MagicPaginator<_Row> paginator = MagicPaginator<_Row>(
      url: 'rows',
      fromMap: _Row.fromMap,
    );
    await paginator.loadFirst();

    await tester.pumpWidget(
      _host(
        MagicPaginatedListView<_Row>(
          paginator: paginator,
          itemBuilder: (_, _Row row, _) =>
              SizedBox(height: 50, child: Text('row ${row.id}')),
        ),
      ),
    );
    expect(find.text('row 2'), findsNothing);

    await paginator.loadMore();
    await tester.pump();

    expect(find.text('row 2'), findsOneWidget);
  });
}
