import 'package:flutter/foundation.dart';

import '../database/eloquent/model.dart';
import '../facades/http.dart';
import '../network/magic_response.dart';
import '../session/session_scope.dart';
import '../session/session_scoped.dart';

/// An id-keyed cache of one remote resource's rows (Eloquent's identity map).
///
/// Subclass with the three pieces that describe the resource:
///
/// ```dart
/// class MonitorRepository extends Repository<Monitor> {
///   static MonitorRepository instance = MonitorRepository();
///
///   @override
///   String get resource => 'monitors';
///
///   @override
///   Monitor Function(Map<String, dynamic>) get fromMap => Monitor.fromMap;
///
///   @override
///   Set<String> get showOnlyKeys => const {'uptime_24h'};
/// }
/// ```
///
/// One row is held per id, so a list read and a show read of the SAME row
/// merge into one cached copy rather than each screen keeping its own: a
/// [RepositoryQuery] built over this repository writes every page it fetches
/// in here, and reads its own `items` back out live, so a [patch] or an
/// [evict] shows up in every query without a refetch.
///
/// [resetForSession] drops every cached row on a login or a team switch (see
/// [SessionScoped]); the constructor registers this repository with
/// [SessionScope] so that reset actually reaches it, and [dispose]
/// unregisters it.
abstract class Repository<T extends Model> extends ChangeNotifier
    implements SessionScoped {
  /// Registers this repository with [SessionScope] so a later identity
  /// change clears it; see [resetForSession].
  Repository() {
    SessionScope.register(this);
  }

  /// The REST path this repository's rows are read from (e.g. `monitors`).
  String get resource;

  /// Maps one row of a `GET` response into [T].
  T Function(Map<String, dynamic>) get fromMap;

  /// Attributes a list endpoint never measures, so a list refetch must not
  /// null them out even when the row it sent carries no value for them.
  ///
  /// A key OUTSIDE this set is authoritative from every source: a null the
  /// list sends for it really does clear the cached value. Only a key IN
  /// this set falls back to the cached row when the list's copy is null; see
  /// [upsertFromList]. A [upsertFromShow] read is authoritative for every
  /// key regardless, since the show endpoint is the one that measures them.
  Set<String> get showOnlyKeys => const <String>{};

  /// Cached rows, keyed by [Model.id] converted to a string.
  final Map<String, T> _rows = <String, T>{};

  /// Reset hooks a [RepositoryQuery] built over this repository registers, so
  /// [resetForSession] clears its cursor and flags along with the rows it
  /// reads. Not for application code to call.
  final List<VoidCallback> _resetHooks = <VoidCallback>[];

  bool _disposed = false;

  int _epoch = 0;

  /// Bumped by every [resetForSession]. A read captures it before its request
  /// and drops its answer when it moved, because an answer that lands after
  /// the identity changed belongs to the previous tenant.
  int get epoch => _epoch;

  /// The row cached for [id], or null when nothing has been fetched for it.
  T? find(String id) => _rows[id];

  /// Every row currently cached, in no particular order.
  Iterable<T> get all => _rows.values;

  /// Merges a list read's [rows] into the cache.
  ///
  /// A row is authoritative for every attribute it carries EXCEPT the ones
  /// named in [showOnlyKeys]: for those, a null in [rows] keeps whatever the
  /// cache already holds (typically from a prior [upsertFromShow]) instead of
  /// erasing it, because the list endpoint never measured it in the first
  /// place. A field outside [showOnlyKeys] that [rows] sends as null DOES
  /// become null; the list is the source of truth for it.
  void upsertFromList(List<T> rows) {
    for (final T row in rows) {
      final String key = '${row.id}';
      final T? cached = _rows[key];

      if (cached != null) {
        for (final String showOnlyKey in showOnlyKeys) {
          if (row.getAttribute(showOnlyKey) != null) continue;

          final Object? preserved = cached.getAttribute(showOnlyKey);
          if (preserved != null) row.setAttribute(showOnlyKey, preserved);
        }
      }

      _rows[key] = row;
    }

    _notify();
  }

  /// Replaces the cached row for [row]'s id with [row], authoritative for
  /// every field: a show endpoint measures everything [showOnlyKeys] names,
  /// so nothing needs carrying forward here.
  void upsertFromShow(T row) {
    _rows['${row.id}'] = row;
    _notify();
  }

  /// Re-reads [id] from `GET $resource/$id` and updates the cache.
  ///
  /// A 404 means the row is gone: it is evicted and this answers null. Any
  /// other failure (a timeout, a 500) is a fault of ours, not a verdict about
  /// the row, so the cached copy stands and is handed back rather than
  /// losing it to a transient outage.
  Future<T?> refresh(String id) async {
    final int asked = _epoch;
    final MagicResponse response = await Http.show(resource, id);
    if (asked != _epoch) return null;

    if (response.notFound) {
      evict(id);
      return null;
    }

    if (!response.successful) {
      return find(id);
    }

    final Map<String, dynamic>? payload = _unwrapShow(response.data);
    if (payload == null) return find(id);

    final T row = fromMap(payload);
    upsertFromShow(row);
    return row;
  }

  /// Merges [attributes] onto the row cached for [id]. A no-op when nothing
  /// is cached for [id]: there is nothing to patch onto, and manufacturing a
  /// row from a partial patch would fabricate fields nobody fetched.
  void patch(String id, Map<String, dynamic> attributes) {
    final T? row = find(id);
    if (row == null) return;

    for (final MapEntry<String, dynamic> entry in attributes.entries) {
      row.setAttribute(entry.key, entry.value);
    }

    _notify();
  }

  /// Drops the cached row for [id], if any.
  void evict(String id) {
    if (_rows.remove(id) == null) return;

    _notify();
  }

  /// Registers [hook] to run on [resetForSession]; called from a
  /// [RepositoryQuery]'s constructor, never by application code directly.
  void addResetHook(VoidCallback hook) => _resetHooks.add(hook);

  /// Reverses [addResetHook]; called from a [RepositoryQuery]'s dispose.
  void removeResetHook(VoidCallback hook) => _resetHooks.remove(hook);

  /// Drops every cached row and clears every live [RepositoryQuery] built
  /// over this repository, for the identity change [SessionScoped] describes.
  ///
  /// Deliberately does not refetch: that is the owning controller's job in
  /// ITS OWN [SessionScoped.resetForSession], the same way
  /// `MonitorController.resetForSession` clears then calls `reload()` itself.
  @override
  Future<void> resetForSession() async {
    _epoch++;
    _rows.clear();

    // Snapshotted first: a hook that rebuilds its paginator must not mutate
    // this list while it is being walked.
    for (final VoidCallback hook in List<VoidCallback>.of(_resetHooks)) {
      hook();
    }

    _notify();
  }

  /// Unwraps a `GET show` payload, matching the `{data: {...}}` envelope most
  /// endpoints send while still accepting a bare object.
  Map<String, dynamic>? _unwrapShow(Object? data) {
    if (data is! Map<String, dynamic>) return null;

    final Object? nested = data['data'];
    return nested is Map<String, dynamic> ? nested : data;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    SessionScope.unregister(this);
    super.dispose();
  }
}
