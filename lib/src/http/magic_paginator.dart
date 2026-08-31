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

  /// The pages come from a [MagicPageFetcher], so how they are addressed is the
  /// fetcher's business and this paginator does not know.
  ///
  /// Reported instead of guessing one of the three above: a fetcher's source
  /// might page by token, by number, or not at all, and claiming `cursor` for
  /// all of them would make [MagicPaginator.mode] say something untrue.
  fetcher,
}

/// What a [MagicPageFetcher] is being asked for.
@immutable
class MagicPageRequest {
  /// Describes one page request.
  const MagicPageRequest({required this.cursor, required this.isFirst});

  /// The cursor the previous page reported, or null when there is none.
  ///
  /// Null on the first page AND on every page of a source that pages by
  /// something else, which is why [isFirst] exists separately.
  final String? cursor;

  /// Whether this is the collection's first page.
  ///
  /// A source that keeps its own position (a page number, an offset) needs this
  /// to tell a refresh from a continuation. Without it, a cursorless fetcher
  /// sees the same request for both and a pull-to-refresh renders whatever page
  /// it happened to be up to as the whole list.
  final bool isFirst;
}

/// One page, as a [MagicPageFetcher] reports it.
///
/// The fetcher has already decoded its own response, so this says only what the
/// paginator cannot work out for itself: the rows, and whether anything follows
/// them. Supply [nextCursor] when the source pages by token, or [hasMore] when
/// it pages by something the paginator never sees (an offset the source keeps,
/// a page number, a "has_more" flag). A non-null [nextCursor] implies more.
@immutable
class MagicPage<E> {
  /// Creates a page of [items].
  const MagicPage({required this.items, this.nextCursor, bool? hasMore})
    : _hasMore = hasMore;

  /// The rows on this page.
  final List<E> items;

  /// The token that fetches the page after this one, or null when there is none.
  final String? nextCursor;

  final bool? _hasMore;

  /// Whether the source reported a page after this one.
  bool get hasMore => _hasMore ?? nextCursor != null;
}

/// Fetches one page.
typedef MagicPageFetcher<E> =
    Future<MagicPage<E>> Function(MagicPageRequest request);

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
    required String this.url,
    required E Function(Map<String, dynamic>) this.fromMap,
    this.perPage,
    this.query,
    this.dataKey = 'data',
  }) : fetch = null;

  /// Creates a paginator over a source that is not a bare endpoint.
  ///
  /// Reach for this when the collection arrives through something other than a
  /// url: a rail or driver behind a swappable contract, a local store, a
  /// query that needs assembling. Pointing the url constructor at the endpoint
  /// such a service wraps walks around the abstraction, and the abstraction is
  /// usually there for a reason (a platform where the service refuses, a fake
  /// the tests install).
  ///
  /// [fetch] receives a [MagicPageRequest]: the cursor the previous page
  /// reported, plus `isFirst`, which a source keeping its own position needs to
  /// tell a refresh from a continuation. Everything else (the accumulation, the
  /// in-flight and disposal guards, keeping the rows when a page fails) is the
  /// same as the url mode.
  ///
  /// ```dart
  /// MagicPaginator<Invoice>.fetcher(
  ///   fetch: (MagicPageRequest request) async {
  ///     final page = await Payments.getInvoices(cursor: request.cursor);
  ///
  ///     return MagicPage<Invoice>(
  ///       items: page.invoices,
  ///       nextCursor: page.nextCursor,
  ///     );
  ///   },
  /// )
  /// ```
  MagicPaginator.fetcher({required MagicPageFetcher<E> this.fetch})
    : url = null,
      fromMap = null,
      perPage = null,
      query = null,
      dataKey = 'data';

  /// The collection endpoint, or null in fetcher mode.
  final String? url;

  /// Maps one row of [dataKey], or null in fetcher mode.
  final E Function(Map<String, dynamic>)? fromMap;

  /// Reads one page, or null in url mode.
  final MagicPageFetcher<E>? fetch;

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
  int? _total;
  int _loadedPages = 0;
  bool _hasMore = false;
  bool _isLoading = false;
  bool _isReset = true;
  String? _error;
  bool _loaded = false;
  bool _disposed = false;
  Future<void>? _inFlight;
  Future<void>? _pendingReset;
  int _generation = 0;

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

  /// Whether the collection is being rebuilt from its first page UNDER rows it
  /// is already holding.
  ///
  /// A list has three loading states and one flag cannot carry them: a first
  /// load shows a skeleton, a refresh keeps the rows the reader is looking at
  /// and says more is coming, and a next page puts a footer under the last row.
  /// Read [isLoading] alone and the second and third are indistinguishable, so
  /// a refresh grows a "loading more" footer it has not earned and a screen that
  /// blanks itself on [isLoading] flashes its skeleton on every filter change.
  ///
  /// False on the first load, because there is nothing on screen to preserve.
  bool get isRefreshing => _isLoading && _isReset && _items.isNotEmpty;

  /// Whether the page AFTER the last one read is in flight.
  ///
  /// The state a footer belongs to. See [isRefreshing] for why the three are
  /// separate.
  bool get isLoadingMore => _isLoading && !_isReset;

  /// The message from the last failed request, cleared by the next success.
  String? get error => _error;

  /// Whether a first page has been read and it held nothing.
  ///
  /// False before the first load, so a fresh paginator does not render an
  /// empty state over a list that has not been asked for yet.
  bool get isEmpty => _loaded && _items.isEmpty;

  /// How the page after the last one read is addressed.
  ///
  /// On the url path that is the server's decision, read from its envelope.
  /// On the fetcher path it is [PaginationMode.fetcher], because the source
  /// is behind a callback and this class does not know.
  PaginationMode get mode => _mode;

  /// How many rows MATCH on the server, or null when nothing has said.
  ///
  /// Read from `meta.total`, so it is the count of the whole collection rather
  /// than of the pages in hand: `items.length` answers "how much have I
  /// fetched", and a header saying "11 of 240" needs the other number. Null on
  /// a cursor collection, because Laravel's `cursorPaginate()` deliberately
  /// does not count, and null is the honest answer there rather than a total
  /// invented from the page that happens to be loaded.
  ///
  /// A page that omits the key leaves the last known value alone, so a
  /// paginated endpoint that only sends the count on page one keeps it.
  int? get total => _total;

  /// How many pages are currently held.
  ///
  /// Of what is HELD, not of requests made: a refresh rebuilds the collection
  /// from its first page and puts this back to one, and a failed page counts
  /// nothing. A screen that writes its position into a URL wants this rather
  /// than the cursor, because a cursor names a position in ONE ordered result:
  /// shared, it drops the reader into the middle of a list with nothing above
  /// it, and points nowhere once that row is renamed or deleted. A count
  /// re-fetches pages one to N, which is the same rows with the top intact.
  int get loadedPages => _loadedPages;

  /// Increments each time the collection is rebuilt from its first page.
  ///
  /// A view that throttles itself on "the page I asked for added no rows" needs
  /// to tell that apart from "a fresh first page that happens to be the same
  /// length", and a row count alone cannot: [refresh] clears the rows and
  /// refills them, so the count can land exactly where the previous attempt
  /// stopped. Compare this beside the count and a reset re-arms whatever the
  /// count had disarmed. [MagicPaginatedListView] does precisely that.
  int get generation => _generation;

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

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Notifies unless this paginator is already gone.
  ///
  /// Every notify here happens after an `await`, and a controller that owns a
  /// paginator disposes it in `onClose`, so any navigate-away mid-request lands
  /// on a disposed notifier. This is the house rule `MagicController.refreshUI`
  /// implements for the same reason.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Starts a load, or defers it behind the one already running.
  ///
  /// A `loadMore` during a request is dropped: it is fired from a scroll
  /// callback and the page it wants is already on its way. A RESET is not
  /// dropped, because the caller asked for fresh data and a pull-to-refresh
  /// that silently did nothing would retract its indicator over stale rows. It
  /// waits for the in-flight page to land and then starts over.
  ///
  /// Overlapping resets share one deferred reload rather than queueing one
  /// each. Without that they chained, so three taps on a retry button became
  /// three sequential first-page fetches.
  Future<void> _load({required bool reset}) {
    if (_isLoading) {
      if (!reset) return Future<void>.value();

      // `onError` as well as the success arm, and the field cleared in
      // `whenComplete` rather than inside either. Cleared only on success it
      // kept a rejected future for good once an in-flight page had thrown, so
      // every later reset-during-flight hit the `??=` on that stale value: the
      // deferred reload was never scheduled and whoever awaited it got the old
      // error back. The error itself is not swallowed, it is simply not
      // re-reported here: it already reached the caller whose page failed, and
      // this is a different call asking for fresh data.
      Future<void> restart(Object? _) {
        // Cleared HERE, at the top, and not at the end of the chain. Held for
        // the whole chain it stayed occupied for the restart's own load too, so
        // a reset arriving in that window hit the `??=` and resolved against a
        // request issued BEFORE it was asked for: silent, no error, and the
        // indicator retracts over the earlier request's rows. That contradicts
        // the rule above. Cleared here it covers both arms, since `restart` runs
        // on either outcome, and the window closes.
        _pendingReset = null;

        return _disposed ? Future<void>.value() : _load(reset: true);
      }

      return _pendingReset ??= _inFlight!.then<void>(restart, onError: restart);
    }

    final Future<void> run = _run(reset: reset);
    _inFlight = run;

    return run;
  }

  Future<void> _run({required bool reset}) async {
    _isLoading = true;
    // Set with the flag rather than derived afterwards, because `isRefreshing`
    // and `isLoadingMore` are read from the notification below, while the
    // request is still in flight. That is the only moment they can be read at
    // all: by the time a caller can await the future, all three are false.
    _isReset = reset;
    _error = null;
    _notify();

    try {
      if (fetch != null) {
        await _runFetcher(reset: reset);

        return;
      }

      await _runUrl(reset: reset);
    } finally {
      // Unwound HERE rather than at each exit, so nothing thrown past this point
      // can leave the paginator loading for the rest of its life. Two throws
      // reach it: an Error out of a fetcher, which `_runFetcher` deliberately
      // does not catch, and a consumer `fromMap` that meets an unexpected
      // payload, which had no handler on the url path at all. Wedged, the object
      // refuses every later `loadMore` on the flag and chains every later
      // `refresh` onto an already-rejected future, while the list view shows a
      // footer that never stops and no error to retry from.
      if (!_disposed) {
        _isLoading = false;
        _notify();
      }
    }
  }

  Future<void> _runUrl({required bool reset}) async {
    final response = await Http.get(url!, query: _queryFor(reset: reset));

    if (_disposed) return;

    // NOT `response.failed`, which is `statusCode >= 400`. A transport failure
    // (a timeout, a dead link, no connectivity) reaches here as statusCode 0
    // from `DioNetworkDriver._handleError`, so it is neither failed nor
    // successful; read through `failed` it took the success path, and a first
    // page that never arrived rendered as an empty collection. "No rows" and
    // "nobody answered" are different screens.
    if (!response.successful) {
      // The rows already on screen stay there. A page that failed to arrive is
      // a reason to offer a retry, not a reason to empty the list the reader
      // was looking at, and `hasMore` is left alone so the retry has a target.
      _error = response.errorMessage ?? 'Failed to load';

      return;
    }

    if (reset) {
      _items.clear();
      _resetCursorState();
      _generation++;
    }

    final Object? payload = response.data;
    if (payload is Map<String, dynamic>) {
      _absorb(payload);
    } else {
      _hasMore = false;
    }

    _loaded = true;
    _loadedPages++;
  }

  /// Runs one page through [fetch].
  ///
  /// A fetcher reports failure by THROWING, where an endpoint reports it with a
  /// status code, so the catch here is what the `!response.successful` branch
  /// is in url mode: the rows already in hand stay, `hasMore` is left alone so
  /// a retry has a target, and the reader is told rather than shown an empty
  /// collection.
  Future<void> _runFetcher({required bool reset}) async {
    try {
      final MagicPage<E> page = await fetch!(
        MagicPageRequest(cursor: reset ? null : _nextCursor, isFirst: reset),
      );

      if (_disposed) return;

      if (reset) {
        _items.clear();
        _resetCursorState();
        _generation++;
      }

      _items.addAll(page.items);
      _mode = PaginationMode.fetcher;
      _nextCursor = page.nextCursor;
      _hasMore = page.hasMore;
      _loaded = true;
      _loadedPages++;
    } on Exception catch (error) {
      // `on Exception`, not a bare catch. An Error out of a fetcher (a bad cast,
      // a failed assertion) is THIS CODE being wrong rather than the source
      // refusing, and turning it into a user-facing `error` string would put a
      // TypeError message on screen and lose the stack. It propagates instead.
      //
      // Nothing is logged here, which matches the layer: neither this file's
      // url path nor `MagicController.fetchList` logs a failed read either. The
      // failure becomes state, and the caller that renders it is the one with
      // the context to decide whether it is worth a log line.
      if (_disposed) return;
      _error = error.toString();
    }
  }

  /// Appends the rows in [payload] and reads where the next page lives.
  void _absorb(Map<String, dynamic> payload) {
    final Object? rows = payload[dataKey];
    if (rows is List) {
      // Mapped to a list BEFORE appending, so a `fromMap` that throws part way
      // through appends nothing rather than half a page. Appending the lazy
      // iterable left the rows before the throw in place with the cursor unset,
      // so the next `loadMore` refetched page one and appended them again:
      // duplicate rows on top of the mapper bug.
      final List<E> mapped = rows
          .whereType<Map<String, dynamic>>()
          .map(fromMap!)
          .toList(growable: false);

      _items.addAll(mapped);
    }

    final Object? meta = payload['meta'];
    if (meta is! Map<String, dynamic>) {
      // No envelope at all. Everything the endpoint has is in hand.
      _mode = PaginationMode.single;
      _hasMore = false;

      return;
    }

    // Read before the mode branches, because it is not a property of either
    // one: `paginate()` sends it, `cursorPaginate()` does not, and a fetcher's
    // source may or may not. `containsKey` rather than a plain read, so a page
    // that says nothing about the count leaves the last known one alone instead
    // of erasing it, which is what an endpoint sending the total on page one
    // only would otherwise do on page two.
    if (meta.containsKey('total')) {
      _total = (meta['total'] as num?)?.toInt();
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
        // Unreachable: this builds a query for the url mode, and only
        // `_runFetcher` ever sets `fetcher`. Listed because the switch is
        // exhaustive, and a query parameter would mean nothing to a fetcher.
        case PaginationMode.fetcher:
          break;
      }
    }

    return parameters.isEmpty ? null : parameters;
  }

  void _resetCursorState() {
    _nextCursor = null;
    _currentPage = 0;
    _lastPage = null;
    // Cleared with the rows rather than kept: a reset is usually a different
    // QUESTION (a filter changed, a search narrowed), so the previous count is
    // about a collection that no longer exists. The next page writes the new
    // one, and until it lands the honest answer is that nothing has said.
    _total = null;
    _loadedPages = 0;
    _hasMore = false;
  }
}
