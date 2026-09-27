# Application Structure

Six primitives divide a magic app's write-heavy screens the way Laravel divides a controller-heavy one: each owns exactly one kind of state, and none of them reaches into another's.

- [Introduction](#introduction)
- [Controllers Own Read State](#controllers-own-read-state)
- [Actions Own Writes](#actions-own-writes)
- [Form Objects Own Form State](#form-objects-own-form-state)
- [Repositories Own Rows](#repositories-own-rows)
- [SessionScope Resets Every Tenant Holder](#sessionscope-resets-every-tenant-holder)
- [Listeners Replace a Central Realtime Dispatcher](#listeners-replace-a-central-realtime-dispatcher)
- [How the Six Compose](#how-the-six-compose)

<a name="introduction"></a>
## Introduction

A controller that also validates, also writes, also owns a paginated collection, and also resubscribes a broadcast channel is not one class doing six jobs well; it is six responsibilities racing each other on one `notifyListeners()`. This page names the six pieces a magic app now has for that: `MagicController` (read state), `MagicAction` (a write), `MagicFormObject` (a screen's form), `Repository`/`RepositoryQuery` (a resource's rows), `SessionScope` (the tenant boundary), and `BroadcastListeners` (the shared channel registry). None of them is new architecture on top of magic; each is the existing primitive from `doc/basics/controllers.md`, `doc/basics/forms.md`, `doc/eloquent/repositories.md`, `doc/digging-deeper/session-scope.md`, and `doc/digging-deeper/broadcasting.md`, read together as one map.

<a name="controllers-own-read-state"></a>
## Controllers Own Read State

A `MagicController` answers "what does this screen show right now": `RxStatus`, a `MagicFormObject`'s field values, a `RepositoryQuery`'s pages. It does not persist a write itself; it runs a `MagicAction` through `RunsActions.runAction` and reacts to the result.

```dart
class MonitorController extends MagicController
    with MagicStateMixin<List<Monitor>>, RunsActions {
  static MonitorController get instance => Magic.findOrPut(MonitorController.new);

  Future<void> pause(String id) async {
    final outcome = await runAction(MagicAction.resolve(PauseMonitor.new), id, key: id);
    if (!outcome.succeeded) return;
  }
}
```

See `doc/basics/controllers.md` for `MagicStateMixin`, fetch helpers, and lifecycle.

<a name="actions-own-writes"></a>
## Actions Own Writes

A `MagicAction<I, O>` is one stateless write, Fortify's `Actions\*` ported: no `MagicController` base, no `notifyListeners`, nothing to dispose. It throws on failure (a `ValidationException` for a 422 or a failed client rule, anything else for a transport fault) rather than answering a bool, because `RunsActions.runAction` is the one place both are already handled.

```dart
class PauseMonitor extends MagicAction<String, void> {
  const PauseMonitor();

  @override
  Future<void> handle(String monitorId) async {
    final response = await Http.update('monitors', monitorId, {'status': 'paused'});
    if (!response.successful) {
      throw Exception(response.errorMessage ?? 'Failed to pause monitor');
    }
  }
}
```

A test swaps the real action for a fake via `MagicAction.bind<PauseMonitor>(() => _FakePauseMonitor())` and clears every override with `MagicAction.flush()` in `tearDown`. See `doc/basics/actions.md`.

<a name="form-objects-own-form-state"></a>
## Form Objects Own Form State

A `MagicFormObject` is a Livewire-style Form object: one field-bound, validated, persistable unit for a single screen's write, created once per `State` and never registered in the container (`onClose` asserts against it). It composes `MagicFormData`, `ValidatesRequests`, and `RunsActions` rather than hand-wiring all three per screen.

```dart
class MonitorFormObject extends MagicFormObject {
  MonitorFormObject({this.editing});

  final Monitor? editing;

  @override
  Map<String, dynamic> get initial => {'name': editing?.name ?? '', 'url': editing?.url ?? ''};

  @override
  FormRequest get request =>
      editing == null ? const StoreMonitorRequest() : const UpdateMonitorRequest();

  @override
  Future<bool> persist(Map<String, dynamic> validated) async {
    final monitor = editing ?? Monitor();
    monitor.fill(validated, strict: true);
    return monitor.save();
  }
}
```

See `doc/basics/forms.md`.

<a name="repositories-own-rows"></a>
## Repositories Own Rows

A `Repository<T>` is an id-keyed cache of one remote resource's rows (Eloquent's identity map); a `RepositoryQuery<T>` is one ordered, filtered, paginated view over it, so a list screen and a show screen reading the same row see the same cached copy without a refetch. Neither owns navigation or form state.

```dart
class MonitorRepository extends Repository<Monitor> {
  static MonitorRepository instance = MonitorRepository();

  @override
  String get resource => 'monitors';

  @override
  Monitor Function(Map<String, dynamic>) get fromMap => Monitor.fromMap;

  @override
  Set<String> get showOnlyKeys => const {'uptime_24h'};
}
```

See `doc/eloquent/repositories.md`.

<a name="sessionscope-resets-every-tenant-holder"></a>
## SessionScope Resets Every Tenant Holder

`SessionScope` is the seam that keeps a login or a team switch from ever showing one tenant's cached rows to another: it resets every `SessionScoped` controller (found via `Magic.controllers`) and every registered `SessionScoped` holder (a `Repository` registers itself in its constructor) on an identity change, in place, never by deleting and recreating the instance.

```dart
@override
Future<void> boot() async {
  SessionScope.identity = () => Auth.check() ? '${Auth.id()}:$teamId' : null;
  SessionScope.attach(); // explicit, and LAST: realtime and polling must already point at the new session
}
```

See `doc/digging-deeper/session-scope.md`.

<a name="listeners-replace-a-central-realtime-dispatcher"></a>
## Listeners Replace a Central Realtime Dispatcher

`BroadcastListeners` owns exactly one `AuthChannelSubscription` per alias, no matter how many controllers listen on it, fanning out to every registered handler instead of one controller's subscription silently dropping another's. A controller declares what it wants via `ListensToBroadcasts.listeners` and never talks to `Echo` directly.

```dart
class MonitorController extends MagicController with ListensToBroadcasts {
  @override
  Map<String, void Function(BroadcastEvent)> get listeners => {
    'team:check.recorded': (event) => MonitorRepository.instance.patch(
      event.data['monitor_id'] as String,
      {'last_status': event.data['status']},
    ),
  };
}
```

See `doc/digging-deeper/broadcasting.md#auth-scoped-subscriptions`.

<a name="how-the-six-compose"></a>
## How the Six Compose

A monitor list screen, put together: `MonitorController` (reads) holds a `RepositoryQuery<Monitor>` over `MonitorRepository.instance` (rows), runs `PauseMonitor` (a write) through `RunsActions`, edits through `MonitorFormObject` (form state), stays correct across a team switch because the repository is `SessionScoped`, and stays live because `MonitorController` mixes in `ListensToBroadcasts` instead of opening its own channel. No primitive here is optional scaffolding: each closes a failure mode the others do not (a write racing itself, a tenant's rows outliving its session, two controllers fighting over one socket) that a single fat controller used to absorb by accident.
