# Actions

`MagicAction<I, O>` is a stateless, single-purpose write unit, Fortify's `Actions\*` ported: a subclass takes one input, does one write, and throws on failure instead of answering a bool.

- [Introduction](#introduction)
- [Writing an Action](#writing-an-action)
- [Running an Action from a Controller](#running-an-action-from-a-controller)
- [Failure Modes](#failure-modes)
- [Swapping an Action in Tests](#swapping-an-action-in-tests)
- [Generating an Action](#generating-an-action)

<a name="introduction"></a>
## Introduction

A write scattered across a controller method (validate, call the endpoint, patch the local cache, show a toast, guard against a double-tap) repeats the same shape at every call site. `MagicAction` names the one piece that is genuinely single-purpose (the write itself) and `RunsActions` names the piece every call site already needed (in-flight guarding, error routing) so neither has to be re-typed per screen.

<a name="writing-an-action"></a>
## Writing an Action

Subclass `MagicAction<I, O>` with the input and output types the write needs, and implement `handle`:

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

An action carries no `MagicController` base and nothing to dispose: it is a plain, often `const`, class. Resolve it through `MagicAction.resolve` rather than constructing it directly, so a test can swap the implementation via `MagicAction.bind` without the call site changing:

```dart
await MagicAction.resolve(PauseMonitor.new).handle(monitorId);
```

<a name="running-an-action-from-a-controller"></a>
## Running an Action from a Controller

Mix `RunsActions` onto the controller and call `runAction`, checking the `ActionOutcome` it answers:

```dart
class MonitorController extends MagicController with RunsActions {
  Future<void> pause(String id) async {
    final outcome = await runAction(MagicAction.resolve(PauseMonitor.new), id, key: id);
    if (!outcome.succeeded) return;
  }
}
```

`runAction` answers an `ActionOutcome<O>`, a sealed type with three cases, so a caller can no longer mistake a refused double-tap for a success by checking a `null` result:

- `ActionSucceeded<O>`, carrying `value` (the action's own result), when `handle` ran to completion;
- `ActionFailed<O>`, carrying `error` (the exception `handle` threw), on either failure mode below;
- `ActionRefused<O>`, when `key` (or the shared unkeyed slot) was already running: the action never ran a second time.

`ActionOutcome` also carries two convenience getters usable without a `switch`: `succeeded` (`true` only for `ActionSucceeded`) and `valueOrNull` (the value on success, `null` otherwise).

`runAction`:

- marks `key` (or a shared default slot when `key` is omitted) running for the call's duration, refusing a second call under the same key while the first is still in flight (answers `ActionRefused` without running the action again);
- on a `ValidationException`, paints its errors onto the host when the controller also mixes in `ValidatesRequests`; on a host that does not, there is no error bag to paint it onto, so it falls back to the same feedback the generic-failure case gets;
- on any other failure, calls `onFailure(error)` when given, so the caller owns the feedback (its own toast, a silent cooldown, nothing), and otherwise logs the exception and shows a toast titled `trans('common.error_occurred')` with `failureMessage` (or that same translated fallback, never the exception's own text, which may carry a raw transport message) as the body;
- answers `ActionFailed` on either failure, and `ActionSucceeded` with the action's own result on success.

`isRunning([key])` reads whether a key (or the shared unkeyed slot) is currently running, for gating a button's `isLoading`:

```dart
WButton(
  isLoading: controller.isRunning(monitor.id),
  onTap: () => controller.pause(monitor.id),
)
```

<a name="failure-modes"></a>
## Failure Modes

| What `handle` does | What `runAction` does |
|---|---|
| Throws `ValidationException`, host is `ValidatesRequests` | Paints field errors via `setErrorsFromMap`; answers `ActionFailed` |
| Throws `ValidationException`, host is not `ValidatesRequests` | Falls back to the generic-failure toast below; answers `ActionFailed` |
| Throws anything else | Logs the exception, shows an error toast titled and bodied with `trans('common.error_occurred')` (or `failureMessage` as the body when given); answers `ActionFailed` |
| Runs to completion | Answers `ActionSucceeded` with the action's own result |
| Called again under a key already running | The second call is a no-op; answers `ActionRefused` without invoking `handle` |

`common.error_occurred` ships in every fresh app's `assets/lang/en.json` (from the `magic:install` stub); override the key in your own catalogue to change the wording.

<a name="swapping-an-action-in-tests"></a>
## Swapping an Action in Tests

`MagicAction.bind<A>(factory)` registers the implementation `MagicAction.resolve` returns for `A`; `MagicAction.flush()` clears every override and belongs in `tearDown` (or is covered by `MagicTest.init()`'s own reset):

```dart
setUp(() {
  MagicAction.bind<PauseMonitor>(() => _FakePauseMonitor());
});

tearDown(() {
  MagicAction.flush();
});
```

<a name="generating-an-action"></a>
## Generating an Action

```bash
dart run magic:artisan make:action PauseMonitor            # -> lib/app/actions/pause_monitor.dart
dart run magic:artisan make:action Monitors/PauseMonitor   # Nested path support
dart run magic:artisan make:action PauseMonitor --force    # Overwrite existing file
```
