# Repositories

`Repository<T>` is an id-keyed cache of one remote resource's rows, Eloquent's identity map for a client with no query builder; `RepositoryQuery<T>` is one ordered, filtered, paginated view over it.

- [Introduction](#introduction)
- [Writing a Repository](#writing-a-repository)
- [RepositoryQuery](#repositoryquery)
- [showOnlyKeys](#showonlykeys)
- [Reading and Writing a Single Row](#reading-and-writing-a-single-row)
- [Session Resets](#session-resets)
- [Failure Modes](#failure-modes)
- [Generating a Repository](#generating-a-repository)

<a name="introduction"></a>
## Introduction

A list screen and a show screen for the same resource used to keep two separate copies of the same row, one per `MagicStateMixin`; a patch on one never reached the other. `Repository<T>` holds one row per id, and every `RepositoryQuery<T>` built over it reads that row live, so a `patch` or an `evict` shows up everywhere at once, with no refetch.

<a name="writing-a-repository"></a>
## Writing a Repository

Subclass `Repository<T>` with the three pieces that describe the resource:

```dart
class MonitorRepository extends Repository<Monitor> {
  static MonitorRepository instance = MonitorRepository();

  @override
  String get resource => 'monitors';

  @override
  Monitor Function(Map<String, dynamic>) get fromMap => Monitor.fromMap;
}
```

Never register a `Repository` via `Magic.put`/`Magic.findOrPut`: its constructor registers it with `SessionScope` on its own, which is how a session reset reaches it (see [Session Resets](#session-resets)). A plain static singleton, as above, is the right shape.

<a name="repositoryquery"></a>
## RepositoryQuery

`RepositoryQuery<T>` owns the ordering, the cursor, and the filters over a repository; the rows themselves live in the repository. It reuses `MagicPaginator.fetcher` to walk pages, and writes every page it reads into the repository via `Repository.upsertFromList`.

```dart
final query = RepositoryQuery<Monitor>(
  repository: MonitorRepository.instance,
  perPage: 50,
  filters: {'status': statusFilter},
);

await query.ensureFresh(); // joins the first reload if one is already in flight
query.items;               // live rows, in server order
query.hasMore;
query.isLoadingMore;
await query.loadMore();
await query.setFilters({'status': 'down'}); // reloads from the first page
```

Built by the controller that owns it, one per screen; dispose it from that controller's `onClose`:

```dart
class MonitorListController extends MagicController {
  late final query = RepositoryQuery<Monitor>(repository: MonitorRepository.instance);

  @override
  void onClose() {
    query.dispose();
    super.onClose();
  }
}
```

<a name="showonlykeys"></a>
## showOnlyKeys

A list endpoint often does not measure every field a show endpoint does (`uptime_24h`, a computed aggregate). Override `showOnlyKeys` to name those fields: a `null` the list sends for one of them keeps whatever the cache already holds from a prior `upsertFromShow`, instead of erasing it.

```dart
class MonitorRepository extends Repository<Monitor> {
  @override
  Set<String> get showOnlyKeys => const {'uptime_24h'};
}
```

A field outside `showOnlyKeys` that the list sends as `null` DOES become `null`: the list is the source of truth for everything it was not told to leave alone. `upsertFromShow` is authoritative for every field regardless, since the show endpoint measures them all.

<a name="reading-and-writing-a-single-row"></a>
## Reading and Writing a Single Row

| Method | What it does |
|---|---|
| `find(id)` | The cached row for `id`, or `null` |
| `all` | Every cached row, in no particular order |
| `refresh(id)` | Re-reads `GET $resource/$id`; a 404 evicts the row and answers `null`, any other failure hands back the cached copy |
| `patch(id, attributes)` | Merges `attributes` onto the cached row; a no-op when nothing is cached for `id` |
| `evict(id)` | Drops the cached row, if any |

`refresh`'s 404-evicts, other-failure-keeps split matters: a fault of ours (a timeout, a 500) is never a verdict about the row, so only a confirmed "this row is gone" clears the cache.

Every write path notifies its listeners (and so every `RepositoryQuery` over it) only when the cache actually changed: a row that was not cached, an evicted row, or an attribute whose stored value differs, compared deeply and with map keys in any order. A broadcast `patch` that restates what is cached, or a `refresh` that answers the row already held, rebuilds nothing. `upsertFromShow` still stores the answered instance, so `find(id)` is the row `refresh` returned. A controller that needs to repaint once a read settles (to clear its own loading flag) calls its own `refreshUI()` after the `await`; it cannot count on the repository's notify, which a failed read never sent either. A `RepositoryQuery` reload is unaffected: its page landing notifies through the paginator whether or not the rows changed.

<a name="session-resets"></a>
## Session Resets

A `Repository` implements `SessionScoped` and registers itself with `SessionScope` in its own constructor, so a login or a team switch drops every cached row before the owning controller refetches (see `doc/digging-deeper/session-scope.md`). A `RepositoryQuery` built over it registers its own reset hook through `Repository.addResetHook`, clearing its cursor, its filters' resolved ids, and its `isFirstLoad`/`hasMore` flags alongside the rows, so a screen mid-load when the identity changes shows its first-load skeleton for the new session rather than a stale page.

<a name="failure-modes"></a>
## Failure Modes

| Situation | What happens |
|---|---|
| A list page throws mid-fetch | `RepositoryQuery.items` and `.meta` keep what they already held; `loadFailed` is `true` only when `items` is also empty |
| A page lands after a session reset (`repository.epoch` moved) | The page's rows never reach the repository or the query's ids |
| `refresh(id)` gets a 404 | The row is evicted; answers `null` |
| `refresh(id)` gets a 500 or times out | The cached row stands; answers the cached copy |
| `patch(id, ...)` called for an id nothing has fetched | No-op: a partial patch never fabricates a row nobody fetched |

<a name="generating-a-repository"></a>
## Generating a Repository

```bash
dart run magic:artisan make:repository Monitor            # -> MonitorRepository
dart run magic:artisan make:repository MonitorRepository  # Suffix already present
dart run magic:artisan make:repository Monitor --force    # Overwrite existing file
```
