import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../facades/http.dart';

/// How the server addresses the page after this one.
///
/// Decided from the response rather than configured by the caller, so one
/// paginator serves an endpoint that changes its mind, and a consumer does not
/// have to restate a decision the backend already made.
enum PaginationMode {
  /// Laravel `cursorPaginate()`: the next page is a token the server minted.
  cursor,

  /// Laravel `paginate()`: the next page is `current_page + 1`.
  offset,

  /// A bare collection with no meta block. One page, and it has arrived.
  single,
}

/// Accumulates a paginated collection one page at a time.
///
/// Built for the list that is too long to render at once: it holds the rows
/// fetched so far, knows whether the server has more, and appends rather than
/// replaces. Pair it with a lazy list (see `MagicPaginatedListView`) so the
/// widget cost stays proportional to the viewport instead of to the result.
///
/// It is a [ChangeNotifier], so a widget listens to it directly and a
/// controller can hold several without inventing a state enum per list.
///
/// ## Cursor before offset, deliberately
///
/// Both Laravel envelopes are read, but cursor is the one to reach for on data
/// that grows at the head, which is most live data: checks, events, messages.
/// Offset addresses a page by counting from the start, so a row inserted at the
/// top between two requests shifts everything down and page two repeats the
/// last row of page one. A cursor names a position in the ordering, so it
/// cannot drift, and the database answers it without counting past the rows it
/// is skipping.
///
/// ```dart
/// final checks = MagicPaginator<CheckRow>(
///   url: 'monitors/$id/checks',
///   fromMap: CheckRow.fromMap,
///   perPage: 50,
/// );
///
/// await checks.loadFirst();
/// await checks.loadMore();
/// ```
class MagicPaginator<E> extends ChangeNotifier {
  /// Creates a paginator for the collection at [url].
  ///
  /// [fromMap] maps one row. [perPage] travels as `per_page` when set, and is
  /// left off entirely when null so the server's own default applies rather
  /// than a number this class invented.
  MagicPaginator({
    required this.url,
    required this.fromMap,
    this.perPage,
    this.query,
    this.dataKey = 'data',
  });

  /// The collection endpoint, without any pagination parameter.
  final String url;

  /// Maps one row of [dataKey] into the consumer's own type.
  final E Function(Map<String, dynamic>) fromMap;

  /// Rows per page, sent as `per_page`. Null leaves the choice to the server.
  final int? perPage;

  /// Query parameters that belong to every page (filters, sorts, a date range).
  final Map<String, dynamic>? query;

  /// The response key holding the row list.
  final String dataKey;

  final List<E> _items = <E>[];
  late final UnmodifiableListView<E> _itemsView = UnmodifiableListView<E>(
    _items,
  );
  PaginationMode _mode = PaginationMode.single;
  String? _nextCursor;
  int _currentPage = 0;
  int? _lastPage;
  bool _hasMore = false;
  bool _isLoading = false;
  String? _error;
  bool _loaded = false;

  /// Every row fetched so far, oldest page first.
  ///
  /// Unmodifiable: a caller that wants to change the collection changes the
  /// request, and a list mutated behind the paginator's back would disagree
  /// with the cursor it is holding.
  ///
  /// A live [UnmodifiableListView] over the backing list rather than a copy of
  /// it. `List.unmodifiable` allocates a new list on EVERY read, and the widget
  /// reads this once per build, so on the long collections this class exists to
  /// serve that is a full copy per frame while the reader scrolls.
  List<E> get items => _itemsView;

  /// Whether the server reported a page after the one most recently read.
  bool get hasMore => _hasMore;

  /// Whether a request is in flight.
  bool get isLoading => _isLoading;

  /// The message from the last failed request, cleared by the next success.
  String? get error => _error;

  /// Whether a first page has been read and it held nothing.
  ///
  /// False before the first load, so a fresh paginator does not render an
  /// empty state over a list that has not been asked for yet.
  bool get isEmpty => _loaded && _items.isEmpty;

  /// How the server addressed the page after the last one read.
  PaginationMode get mode => _mode;

  /// Reads the first page, discarding anything already held.
  Future<void> loadFirst() => _load(reset: true);

  /// Reads the page after the last one, appending its rows.
  ///
  /// A no-op when there is nothing more or a request is already in flight. The
  /// second half is what makes this safe to call from a scroll callback, which
  /// fires on every frame near the end of the list.
  Future<void> loadMore() async {
    if (!_hasMore || _isLoading) return;

    return _load(reset: false);
  }

  /// Rereads the collection from its first page.
  Future<void> refresh() => _load(reset: true);

  Future<void> _load({required bool reset}) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    final response = await Http.get(url, query: _queryFor(reset: reset));

    if (response.failed) {
      // The rows already on screen stay there. A page that failed to arrive is
      // a reason to offer a retry, not a reason to empty the list the reader
      // was looking at, and `hasMore` is left alone so the retry has a target.
      _error = response.errorMessage ?? 'Failed to load';
      _isLoading = false;
      notifyListeners();

      return;
    }

    if (reset) {
      _items.clear();
      _resetCursorState();
    }

    final Object? payload = response.data;
    if (payload is Map<String, dynamic>) {
      _absorb(payload);
    } else {
      _hasMore = false;
    }

    _loaded = true;
    _isLoading = false;
    notifyListeners();
  }

  /// Appends the rows in [payload] and reads where the next page lives.
  void _absorb(Map<String, dynamic> payload) {
    final Object? rows = payload[dataKey];
    if (rows is List) {
      _items.addAll(rows.whereType<Map<String, dynamic>>().map(fromMap));
    }

    final Object? meta = payload['meta'];
    if (meta is! Map<String, dynamic>) {
      // No envelope at all. Everything the endpoint has is in hand.
      _mode = PaginationMode.single;
      _hasMore = false;

      return;
    }

    // `next_cursor` is present and null on the LAST cursor page, so the KEY
    // identifies the mode and its VALUE decides whether another page exists.
    // Branching on the value alone would leave the last page classified as
    // [PaginationMode.single], which reports the endpoint as unpaginated to
    // anything reading [mode] and is simply untrue of it.
    if (meta.containsKey('next_cursor')) {
      _mode = PaginationMode.cursor;
      _nextCursor = meta['next_cursor'] as String?;
      _hasMore = _nextCursor != null;

      return;
    }

    if (meta.containsKey('current_page')) {
      _mode = PaginationMode.offset;
      _currentPage = (meta['current_page'] as num?)?.toInt() ?? _currentPage;
      _lastPage = (meta['last_page'] as num?)?.toInt();
      _hasMore = _lastPage != null && _currentPage < _lastPage!;

      return;
    }

    _mode = PaginationMode.single;
    _hasMore = false;
  }

  Map<String, dynamic>? _queryFor({required bool reset}) {
    final Map<String, dynamic> parameters = <String, dynamic>{
      ...?query,
      if (perPage != null) 'per_page': perPage,
    };

    if (!reset) {
      switch (_mode) {
        case PaginationMode.cursor:
          if (_nextCursor != null) parameters['cursor'] = _nextCursor;
        case PaginationMode.offset:
          parameters['page'] = _currentPage + 1;
        case PaginationMode.single:
          break;
      }
    }

    return parameters.isEmpty ? null : parameters;
  }

  void _resetCursorState() {
    _nextCursor = null;
    _currentPage = 0;
    _lastPage = null;
    _hasMore = false;
  }
}
