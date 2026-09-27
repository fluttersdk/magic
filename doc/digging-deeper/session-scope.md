# Session Scope

`SessionScope` keeps every cached controller and repository pointed at the identity that is authenticated right now, so a login after a logout, or a team switch by the same user, never leaves a previous tenant's rows on screen.

- [Introduction](#introduction)
- [Why It Exists](#why-it-exists)
- [Attaching](#attaching)
- [The Identity Resolver](#the-identity-resolver)
- [SessionScoped](#sessionscoped)
- [Registering a Non-Controller Holder](#registering-a-non-controller-holder)
- [Failure Modes](#failure-modes)

<a name="introduction"></a>
## Introduction

Magic resolves controllers as Type-keyed singletons and runs `onInit` exactly once per instance lifetime. On a single-tenant app that is the whole point: a controller's first fetch happens once and stays put. On a team-scoped product it is a defect waiting to happen: `MonitorController` boots for team A, caches team A's rows, and a switch to team B (or a logout followed by a different user's login) leaves those rows on screen with nothing that would ever clear them.

<a name="why-it-exists"></a>
## Why It Exists

`SessionScope` is the one seam every scoped controller and repository routes through, rather than each one hand-rolling its own `Auth.stateNotifier` listener. It calls `resetForSession()` on every registered holder whenever the resolved identity changes, and does so **in place**: it never deletes and recreates a controller. A mounted `MagicStatefulViewState` holds its own controller instance directly, so a delete-then-recreate would freeze that view rather than refresh it.

<a name="attaching"></a>
## Attaching

`SessionScope.attach()` is explicit: no core provider calls it, because it must be the LAST `Auth.stateNotifier` listener so realtime, polling, and locale already point at the new session before any scoped holder's data is refetched.

```dart
@override
Future<void> boot() async {
  SessionScope.identity = () => Auth.check() ? '${Auth.id()}:$teamId' : null;
  SessionScope.attach();
}
```

`attach()` is idempotent while already attached, and records the boot identity before subscribing, so the FIRST real change (not the app's own startup) is the first one that resets anything. `detach()` unsubscribes and forgets the recorded identity; registered holders and the `identity` resolver survive it, since they belong to their owners, not to the subscription.

<a name="the-identity-resolver"></a>
## The Identity Resolver

`SessionScope.identity` defaults to the authenticated user id. A team-scoped app overrides it to fold the active team in, so a team switch by the same user counts as a change too:

```dart
SessionScope.identity = () => Auth.check() ? '${Auth.id()}:$teamId' : null;
```

A `null` identity means unauthenticated and nothing else. A change TO `null` (a logout) is recorded without triggering a reset: from the login screen a refetch can only 401. The next login resets before any authenticated view renders.

<a name="sessionscoped"></a>
## SessionScoped

Implement `SessionScoped` on a controller or a holder that caches per-tenant rows:

```dart
class MonitorController extends MagicController
    with MagicStateMixin<List<Monitor>>
    implements SessionScoped {
  @override
  Future<void> resetForSession() async {
    setEmpty();
    await loadMonitors();
  }
}
```

`resetForSession` must **clear before it refetches**. Ordinary reload paths are deliberately non-destructive (a transport failure keeps the last-known-good rows on screen), and that is the wrong behaviour across an identity change: a failed refetch here must leave the screen empty, never populated with the previous tenant's data.

A controller implementing `SessionScoped` needs no explicit registration: `SessionScope.sync()` finds it by walking `Magic.controllers.whereType<SessionScoped>()` on every identity change.

<a name="registering-a-non-controller-holder"></a>
## Registering a Non-Controller Holder

A `Repository` is not a controller, so it registers itself explicitly. This already happens in `Repository`'s own constructor; the pattern below is what a hand-rolled `SessionScoped` holder (something other than a `Repository`) does the same way:

```dart
class SearchIndex implements SessionScoped {
  SearchIndex() {
    SessionScope.register(this);
  }

  @override
  Future<void> resetForSession() async {
    _entries.clear();
  }

  void dispose() {
    SessionScope.unregister(this);
  }
}
```

`SessionScope.unregister` must run when the holder is disposed; an unregistered-but-live holder would otherwise be reset forever, even after nothing references it.

<a name="failure-modes"></a>
## Failure Modes

| Situation | What happens |
|---|---|
| Two logins under the same identity in a row | The second `sync()` is a no-op: the identity did not change |
| A `resetForSession()` throws | Logged via `Log.error`, isolated per holder: one holder's throw never stops another's reset |
| A reset resolves another controller mid-iteration | Safe: the scoped set is snapshotted before iterating |
| A controller is also a registered holder (both a `SessionScoped` controller and separately `register`ed) | Resets exactly once: the snapshot is a `Set` |
| `attach()` called twice | The second call is a no-op; only one subscription is ever active |
| A logout | Recorded, never triggers a reset (would only 401) |
