import 'dart:async';

import 'package:flutter/foundation.dart';

import '../database/eloquent/model.dart';
import '../facades/http.dart';
import '../http/magic_paginator.dart';
import '../network/magic_response.dart';
import '../perf/magic_perf_hooks.dart';
import 'repository.dart';

/// One ordered, filtered, paginated view over a [Repository].
///
/// The ROWS live in the repository; this only owns the ordering, the cursor
/// and the filters. It uses [MagicPaginator.fetcher] to walk the pages and
/// writes every page it reads into [repository] via [Repository.upsertFromList],
/// then keeps just the ids in the order the server sent them. [items] resolves
/// those ids against [repository] on every read, so a [Repository.patch] or
/// [Repository.evict] shows up here at once, with no refetch.
///
/// ```dart
/// final query = RepositoryQuery<Monitor>(
///   repository: MonitorRepository.instance,
///   perPage: 50,
///   filters: {'status': statusFilter},
/// );
///
/// await query.reload();
/// query.items; // live rows, in server order
/// ```
///
/// Built by the controller that owns it, one per screen; disposed from that
/// controller's `onClose` (`query.dispose()`), which also detaches it from
/// [repository].
class RepositoryQuery<T extends Model> extends ChangeNotifier {
  /// Creates a query over [repository]'s rows.
  ///
  /// [perPage] travels as `per_page`, left off when null so the server's own
  /// default applies. [filters] travels on every page (a status tab, a
  /// search box); change it later with [setFilters].
  RepositoryQuery({
    required this.repository,
    this.perPage,
    Map<String, dynamic> filters = const <String, dynamic>{},
  }) : _filters = Map<String, dynamic>.of(filters) {
    _paginator = _buildPaginator();
    _paginator.addListener(_onPaginatorChanged);
    repository.addListener(_onRepositoryChanged);
    repository.addResetHook(_onSessionReset);
  }

  /// The repository this view reads rows from and writes fetched pages into.
  final Repository<T> repository;

  /// Rows requested per page, sent as `per_page`.
  final int? perPage;

  Map<String, dynamic> _filters;

  late MagicPaginator<T> _paginator;

  /// Ids of the rows this query holds, in the order the server sent them.
  /// The rows themselves are read live from [repository]; see [items].
  final List<String> _ids = <String>[];

  /// The envelope's `meta`, read fresh on every successful page.
  Map<String, dynamic> _meta = const <String, dynamic>{};

  /// Whether [reload] has ever been called and settled.
  bool _resolvedOnce = false;

  /// Whether the very first [reload] has been started, so a later call never
  /// mistakes itself for the first load [ensureFresh] joins.
  bool _startedFirstLoad = false;

  /// The first [reload] while it is still in flight, so a second reader can
  /// JOIN it via [ensureFresh] instead of issuing the same request again.
  Future<void>? _firstLoad;

  bool _disposed = false;

  /// The rows fetched so far, resolved LIVE from [repository]: a patch or
  /// evict there is visible here without a refetch. An id the repository has
  /// evicted is dropped rather than resolving to null.
  List<T> get items =>
      _ids.map(repository.find).whereType<T>().toList(growable: false);

  /// Whether the first page has never resolved, successfully or not.
  bool get isFirstLoad => !_resolvedOnce;

  /// Whether the server reported a page after the one most recently read.
  bool get hasMore => _paginator.hasMore;

  /// Whether the page after the last one read is in flight.
  bool get isLoadingMore => _paginator.isLoadingMore;

  /// The envelope `meta` of the last successful page.
  Map<String, dynamic> get meta => _meta;

  /// Whether this query has nothing to show AND the reason is a failed read.
  ///
  /// A failed page that left rows on screen (see [_fetch]) does not count:
  /// the cache stands, so there is something to show and no reason to say the
  /// read failed.
  bool get loadFailed => _paginator.error != null && items.isEmpty;

  /// Rereads the collection from its first page, replacing what is held.
  Future<void> reload() {
    final int? startUs = MagicPerfHooks.sink == null
        ? null
        : FlutterTimeline.now;
    final int asked = repository.epoch;
    final Future<void>
    result = _deferringStart(_paginator.refresh).whenComplete(() {
      // A reload that straddled a session reset resolved nothing for the new
      // session, which still has to show its first-load skeleton.
      if (asked == repository.epoch) _resolvedOnce = true;
      if (startUs != null) _reportReload(startUs, fromCache: false);
    });

    if (!_startedFirstLoad) {
      _startedFirstLoad = true;

      // Identity-checked rather than an unconditional `_firstLoad = null`:
      // a reset started while this load was in flight (see
      // [_onSessionReset]) may already have let a NEWER first load start and
      // occupy the slot by the time this one settles. Clearing unconditionally
      // would strand that newer load's joiners into firing a request of
      // their own instead of awaiting it.
      Future<void>? firstLoad;
      firstLoad = result.whenComplete(() {
        if (identical(_firstLoad, firstLoad)) _firstLoad = null;
      });
      _firstLoad = firstLoad;
    }

    return result;
  }

  /// Reads the page after the last one, appending its rows. A no-op when
  /// there is nothing more or a page is already in flight.
  Future<void> loadMore() => _deferringStart(_paginator.loadMore);

  /// The read a newly mounted screen should ask for: joins the first
  /// [reload] while it is in flight, otherwise reloads (mirrors
  /// `MonitorController.ensureFresh`).
  Future<void> ensureFresh() {
    final Future<void>? inFlight = _firstLoad;
    if (inFlight == null) return reload();
    if (MagicPerfHooks.sink == null) return inFlight;

    final int startUs = FlutterTimeline.now;
    return inFlight.whenComplete(() => _reportReload(startUs, fromCache: true));
  }

  void _reportReload(int startUs, {required bool fromCache}) {
    if (MagicPerfHooks.sink == null) return;

    MagicPerfHooks.emit(
      QueryReloaded(T, startUs, FlutterTimeline.now, fromCache),
    );
  }

  /// Replaces [filters] and reloads from the first page: a filter is a
  /// different question about the collection, not a narrowing of the rows
  /// already in hand.
  Future<void> setFilters(Map<String, dynamic> filters) {
    _filters = Map<String, dynamic>.of(filters);
    return reload();
  }

  MagicPaginator<T> _buildPaginator() =>
      MagicPaginator<T>.fetcher(fetch: _fetch);

  /// Reads one page of `GET $resource`, merges its rows into [repository],
  /// and updates [_ids] and [_meta].
  ///
  /// Throws on a non-2xx: the paginator's own catch keeps the rows and ids
  /// already held, since a page that failed to arrive is a reason to offer a
  /// retry, not to empty what is on screen. [_ids] and [_meta] are updated
  /// only after that check, so a failed page never reaches them.
  Future<MagicPage<T>> _fetch(MagicPageRequest request) async {
    final int asked = repository.epoch;
    final MagicResponse response = await Http.index(
      repository.resource,
      filters: <String, dynamic>{
        if (perPage != null) 'per_page': perPage,
        if (request.cursor != null) 'cursor': request.cursor,
        ..._filters,
      },
    );

    // The session changed while this page was in flight: its rows belong to
    // the previous tenant, so none of them may reach the repository or the
    // ids. The paginator that asked has already been replaced.
    if (asked != repository.epoch) {
      return MagicPage<T>(items: <T>[]);
    }

    if (!response.successful) {
      throw Exception(
        response.errorMessage ?? 'Failed to load ${repository.resource}',
      );
    }

    final Object? payload = response.data;
    final Map<String, dynamic> body = payload is Map<String, dynamic>
        ? payload
        : const <String, dynamic>{};

    final Object? rawRows = body['data'];
    // A 2xx the client cannot read is a failed read, not an empty page: an
    // empty page would replace the rows on screen with nothing.
    if (rawRows is! List) {
      throw FormatException(
        'Unreadable ${repository.resource} page: `data` is not a list',
      );
    }
    final List<T> rows = rawRows
        .whereType<Map<String, dynamic>>()
        .map(repository.fromMap)
        .toList(growable: false);

    repository.upsertFromList(rows);

    final List<String> ids = <String>[for (final T row in rows) '${row.id}'];
    if (request.isFirst) {
      _ids
        ..clear()
        ..addAll(ids);
    } else {
      _ids.addAll(ids);
    }

    _meta = body['meta'] is Map<String, dynamic>
        ? body['meta'] as Map<String, dynamic>
        : const <String, dynamic>{};

    final Object? next = _meta['next_cursor'];

    return MagicPage<T>(
      items: rows,
      nextCursor: next is String && next.isNotEmpty ? next : null,
    );
  }

  void _onRepositoryChanged() => _notify();

  /// Forwards a paginator change, one microtask later when it happens inside
  /// the synchronous part of a [reload] or [loadMore] call.
  ///
  /// The paginator notifies SYNCHRONOUSLY when a load starts, and a load is
  /// what a view's `initState` asks for (`RefetchesOnMount`). Forwarding that
  /// inline would notify this query's other listeners (a controller, then a
  /// still-mounted screen below the new route) while the tree is building,
  /// which Flutter refuses. A microtask runs once the current build returns.
  /// Every later change (the page landing) is forwarded at once, so a caller
  /// that awaited the load has already been told by the time it resumes.
  void _onPaginatorChanged() {
    if (!_insideCall) {
      _notify();
      return;
    }
    if (_forwardScheduled) return;
    _forwardScheduled = true;
    scheduleMicrotask(() {
      _forwardScheduled = false;
      _notify();
    });
  }

  bool _forwardScheduled = false;

  bool _insideCall = false;

  /// Runs [start] with the load-start notification deferred (see
  /// [_onPaginatorChanged]).
  Future<void> _deferringStart(Future<void> Function() start) {
    _insideCall = true;
    try {
      return start();
    } finally {
      _insideCall = false;
    }
  }

  /// Clears this query's own state for the identity change [Repository]
  /// describes on [Repository.resetForSession]. Rebuilds the paginator rather
  /// than reusing it, since [MagicPaginator] has no "clear without a fetch"
  /// of its own; nothing here issues a request.
  void _onSessionReset() {
    _paginator.removeListener(_onPaginatorChanged);
    _paginator.dispose();
    _paginator = _buildPaginator();
    _paginator.addListener(_onPaginatorChanged);

    _ids.clear();
    _meta = const <String, dynamic>{};
    _resolvedOnce = false;
    _startedFirstLoad = false;
    _firstLoad = null;

    _notify();
  }

  void _notify() {
    if (_disposed) return;

    if (MagicPerfHooks.sink == null) {
      notifyListeners();
      return;
    }
    MagicPerfHooks.runWithCause(
      MagicNotifyCause.repositoryQuery,
      notifyListeners,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    repository.removeListener(_onRepositoryChanged);
    repository.removeResetHook(_onSessionReset);
    _paginator.removeListener(_onPaginatorChanged);
    _paginator.dispose();
    super.dispose();
  }
}
