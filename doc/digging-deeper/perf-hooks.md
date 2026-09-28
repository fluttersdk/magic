# Perf Hooks

`MagicPerfHooks.sink` is the one seam a diagnostic reads magic's runtime activity through: which controller repainted and why, what a repository merged, how long a query reload, an action or an event dispatch took, which casts ran, which timers fired and which realtime messages arrived. Magic depends on no tooling package; the tool assigns the sink.

- [Introduction](#introduction)
- [Installing a Sink](#installing-a-sink)
- [Event Kinds](#event-kinds)
- [Notification Causes](#notification-causes)
- [Pairing HTTP Requests](#pairing-http-requests)
- [Cost and Failure Modes](#cost-and-failure-modes)

<a name="introduction"></a>
## Introduction

A frame profile says a frame was slow; it does not say that a `Countdown` tick made three controllers repaint, or that a broadcast storm re-cast the same `json` attribute two hundred times. The sink reports those facts as typed `MagicPerfEvent` values so a tool can attribute a frame to the magic activity inside it.

<a name="installing-a-sink"></a>
## Installing a Sink

```dart
MagicPerfHooks.sink = (MagicPerfEvent event) {
  switch (event) {
    case ControllerNotified(:final controller, :final cause):
      record('${controller.runtimeType}', cause.name);
    case QueryReloaded(:final type, :final startUs, :final endUs):
      span('reload $type', startUs, endUs);
    default:
      break;
  }
};

// Uninstall.
MagicPerfHooks.sink = null;
```

`MagicPerfEvent` is sealed, so a `switch` over it is exhaustive. Every timestamp is `FlutterTimeline.now`, in microseconds on the clock the engine stamps frame timings with.

<a name="event-kinds"></a>
## Event Kinds

| Event | Fields | Reported when |
|---|---|---|
| `ControllerNotified` | `controller`, `cause` | `MagicController.refreshUI()` notifies (every `setState` helper and `ValidatesRequests` go through it). |
| `RepositoryUpserted` | `type`, `count` | `Repository.upsertFromList` or `upsertFromShow` merged rows; `type` is the model type. |
| `QueryReloaded` | `type`, `startUs`, `endUs`, `fromCache` | A `RepositoryQuery.reload()` settled; `fromCache` is `true` when `ensureFresh()` joined a first load already in flight instead of sending its own request. |
| `ActionRan` | `type`, `startUs`, `endUs`, `outcome` | `RunsActions.runAction` ran an action to `ActionSucceeded` or `ActionFailed`. A refused re-entry never runs and is not reported. |
| `EventDispatched` | `type`, `listenerCount`, `startUs`, `endUs` | The event dispatcher delivered an event to its typed and wildcard listeners. |
| `AttributeCast` | `castType` | `Model.getAttribute` computed a cast. A memoised `datetime`/`bool`/`int`/`double` read is not reported; `json` is cast, and reported, on every read. A `CastsAttributes` instance reports its runtime type name. |
| `TimerTicked` | `ownerType` | A `Countdown` tick, a `Debouncer` fire or a `Poll` read. |
| `BroadcastReceived` | `event` | `BroadcastListeners` fanned out one realtime message. |

<a name="notification-causes"></a>
## Notification Causes

`ControllerNotified.cause` is a `MagicNotifyCause`, read from a static "current cause" each instrumented path sets synchronously around the callback it invokes:

| Cause | Set around |
|---|---|
| `setState` | `MagicStateMixin.setState`, so every `setSuccess`, `setError`, `setLoading`, `setEmpty` |
| `repositoryQuery` | a `RepositoryQuery` notifying its listeners |
| `timerTick` | a `Countdown` `onTick`, a `Debouncer` callback, a `Poll` read |
| `broadcast` | a `BroadcastListeners` fan-out |
| `direct` | nothing: the app called `refreshUI()` on its own |

The outermost cause wins. A `setSuccess` called from a `Countdown.onTick` reports `timerTick`, because the tick is why the state moved. The cause is synchronous only: work that resumes after an `await` inside one of those callbacks runs outside it and reports whatever path it resumes in.

<a name="pairing-http-requests"></a>
## Pairing HTTP Requests

`DioNetworkDriver` stamps every request with a process-unique id before any interceptor runs. `MagicRequest.id`, `MagicResponse.id` and `MagicError.id` carry the same value for the same request, so an interceptor can pair concurrent requests with their answers even when a slow first request completes last:

```dart
class TimingInterceptor extends MagicNetworkInterceptor {
  final Map<int, int> _startedUs = {};

  @override
  dynamic onRequest(MagicRequest request) {
    final int? id = request.id;
    if (id != null) _startedUs[id] = FlutterTimeline.now;
    return request;
  }

  @override
  dynamic onResponse(MagicResponse response) {
    final int? startUs = _startedUs.remove(response.id);
    // ...
    return response;
  }
}
```

A request built by hand, and every response `Http.fake` answers, carries a `null` id.

<a name="cost-and-failure-modes"></a>
## Cost and Failure Modes

- With no sink installed, each instrumented site costs one null check and constructs no event object.
- A sink that throws is reported through `debugPrint` and ignored. It runs before the notification it observes, so an unguarded throw would stop the screen repainting; a broken observer costs its own numbers, never the app's frames.
- The sink is process-wide. A test that installs one resets it to `null` in `tearDown`.
