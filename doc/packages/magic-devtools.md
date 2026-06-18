# Magic DevTools

Magic DevTools wires a magic app into the FlutterSDK dev-tooling ecosystem (dusk and telescope), and is loaded only under `kDebugMode` so release builds tree-shake it away entirely.

- [Introduction](#introduction)
- [What dusk and telescope give you](#what-dusk-and-telescope-give-you)
    - [Dusk: the E2E driver](#dusk-the-e2e-driver)
    - [Telescope: the passive runtime inspector](#telescope-the-passive-runtime-inspector)
- [Installation](#installation)
    - [Why a regular dependency, not a dev dependency](#why-a-regular-dependency-not-a-dev-dependency)
- [Wiring the integrations](#wiring-the-integrations)
    - [The install order](#the-install-order)
    - [Dusk](#dusk)
    - [Telescope](#telescope)
    - [Both together](#both-together)
- [The kDebugMode guard](#the-kdebugmode-guard)
- [What the Magic watchers capture](#what-the-magic-watchers-capture)
    - [Magic watchers](#magic-watchers)
    - [The HTTP adapter](#the-http-adapter)
- [Release builds load nothing](#release-builds-load-nothing)

<a name="introduction"></a>
## Introduction

`magic_devtools` is the adapter layer that connects a magic app to two FlutterSDK dev-tooling packages: `fluttersdk_dusk` (an end-to-end driver for LLM agents and CI) and `fluttersdk_telescope` (a passive runtime inspector). It enriches what those tools observe with Magic-aware context: forms, navigation, controllers, gates, auth, broadcasting, and HTTP.

Magic core has zero dependency on dusk or telescope. The adapter lives in the separate `magic_devtools` package precisely so the framework carries no dev-tooling production dependency. You opt in by adding `magic_devtools`, and you wire it under `kDebugMode` so it never reaches a release build.

This page covers what each tool gives you, how to install `magic_devtools`, the load-bearing install order, the `kDebugMode` guard that guarantees debug-only loading, and what the Magic watchers capture.

<a name="what-dusk-and-telescope-give-you"></a>
## What dusk and telescope give you

<a name="dusk-the-e2e-driver"></a>
### Dusk: the E2E driver

`fluttersdk_dusk` drives a running Flutter app for LLM agents and CI. It exposes the app's Semantics tree as addressable elements and supports tapping, typing, scrolling, and asserting against them.

`MagicDuskIntegration` registers Magic-aware enrichers into dusk's snapshot pipeline. Each enricher annotates the snapshot with framework context the raw Semantics tree does not carry: the active route, the form field a text input is bound to, server-side validation errors, controller state, the most recent gate result, the active route's middlewares, and the authenticated user. An agent reading a snapshot sees your app the way Magic sees it, not just the way the accessibility tree does.

<a name="telescope-the-passive-runtime-inspector"></a>
### Telescope: the passive runtime inspector

`fluttersdk_telescope` passively records runtime activity (HTTP requests, logs, exceptions, queries, and framework events) into in-memory ring buffers and serves them to agents. It does not change app behavior; it observes.

`MagicTelescopeIntegration` registers Magic watchers and an HTTP adapter into telescope. The watchers subscribe to Magic's model, cache, event, gate, and query activity; the adapter feeds Magic's HTTP traffic into telescope's HTTP buffer. Telescope is read-only: it captures and surfaces telemetry, it never writes back into your app.

<a name="installation"></a>
## Installation

Add `magic_devtools` to your `pubspec.yaml`, plus whichever tooling packages you intend to use:

```yaml
dependencies:
  magic_devtools: ^0.0.1
  fluttersdk_dusk: ^0.0.8        # add if you use dusk
  fluttersdk_telescope: ^0.0.4   # add if you use telescope
```

`magic_devtools` depends on `magic`, `fluttersdk_dusk`, and `fluttersdk_telescope` directly, so the tooling packages resolve through `magic_devtools` rather than transitively through `magic` itself.

<a name="why-a-regular-dependency-not-a-dev-dependency"></a>
### Why a regular dependency, not a dev dependency

`magic_devtools` and the tooling packages go under `dependencies`, not `dev_dependencies`. There are two reasons:

1. You import these packages from `lib/main.dart` (under `kDebugMode`). Because `lib/` imports them, a `dev_dependencies` entry would trip the `depend_on_referenced_packages` lint. Anything imported from `lib/` must be a regular dependency.
2. The `kDebugMode` guard is what keeps these packages out of release builds, not the dependency category. `kDebugMode` is a compile-time constant; the compiler tree-shakes every `if (kDebugMode) { ... }` branch out of a release build, so the imported code is dropped entirely. There is zero production cost even though the package is a regular dependency.

This matches how `fluttersdk_dusk` and `fluttersdk_telescope` are installed on their own.

<a name="wiring-the-integrations"></a>
## Wiring the integrations

You wire both integrations in `lib/main.dart`, inside `kDebugMode` guards. The wiring splits into two phases around `Magic.init()`, and the order between those phases is load-bearing.

<a name="the-install-order"></a>
### The install order

The plugin installs **before** `Magic.init()`, and the Magic integration installs **after** it:

1. **`DuskPlugin.install()` / `TelescopePlugin.install()` run BEFORE `Magic.init()`.** This brings the snapshot pipeline (dusk) and the watcher store (telescope) live during Magic boot, so telescope's exception watcher catches errors thrown while Magic boots.
2. **`MagicDuskIntegration.install()` / `MagicTelescopeIntegration.install()` run AFTER `Magic.init()`.** The Magic integrations resolve Magic primitives through the IoC container: the dusk enrichers read `Magic.controllers`, `MagicRouter.instance`, `Gate.manager`, and `Auth.user()`; the telescope adapter resolves the network driver from the container. Those bindings only exist once the service providers have booted, so the integration must run after `Magic.init()` completes.

Calling either `install()` twice in the same isolate is a no-op after the first call; both are idempotent.

<a name="dusk"></a>
### Dusk

```dart
import 'package:flutter/foundation.dart';
import 'package:magic/magic.dart';
import 'package:magic_devtools/dusk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    DuskPlugin.install();
  }
  await Magic.init(configFactories: [...]);
  if (kDebugMode) {
    MagicDuskIntegration.install();
  }
  runApp(MagicApplication());
}
```

<a name="telescope"></a>
### Telescope

```dart
import 'package:flutter/foundation.dart';
import 'package:magic/magic.dart';
import 'package:magic_devtools/telescope.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    TelescopePlugin.install();
  }
  await Magic.init(configFactories: [...]);
  if (kDebugMode) {
    MagicTelescopeIntegration.install();
  }
  runApp(MagicApplication());
}
```

<a name="both-together"></a>
### Both together

You can wire either integration on its own, or both at once. The rule is the same either way: install each plugin before `Magic.init()`, and each Magic integration after it.

```dart
import 'package:flutter/foundation.dart';
import 'package:magic/magic.dart';
import 'package:magic_devtools/dusk.dart';
import 'package:magic_devtools/telescope.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    DuskPlugin.install();
    TelescopePlugin.install();
  }
  await Magic.init(configFactories: [...]);
  if (kDebugMode) {
    MagicDuskIntegration.install();
    MagicTelescopeIntegration.install();
  }
  runApp(MagicApplication());
}
```

<a name="the-kdebugmode-guard"></a>
## The kDebugMode guard

Every devtools call sits inside `if (kDebugMode) { ... }`. This is the mechanism that guarantees debug-only loading.

`kDebugMode` is a compile-time constant from `package:flutter/foundation.dart`: it is `true` in debug builds and `false` in profile and release builds. Because the value is known at compile time, the compiler eliminates the entire `if (kDebugMode)` branch from a non-debug build. The calls to `DuskPlugin.install()`, `MagicDuskIntegration.install()`, and their telescope counterparts are dropped, and with them the imported `magic_devtools`, `fluttersdk_dusk`, and `fluttersdk_telescope` code is tree-shaken out.

The guard is what makes the regular-dependency choice safe: the package ships in your dependency graph for resolution, but none of its code survives into a release build.

<a name="what-the-magic-watchers-capture"></a>
## What the Magic watchers capture

`MagicTelescopeIntegration.install()` registers five watchers and one HTTP adapter into telescope.

<a name="magic-watchers"></a>
### Magic watchers

| Watcher | Captures |
|---------|----------|
| `MagicModelWatcher` | Model lifecycle events: `ModelCreated`, `ModelSaved`, `ModelDeleted`. |
| `MagicCacheWatcher` | Cache activity. Registered now; it begins recording once the Cache layer emits lifecycle events upstream. |
| `MagicEventWatcher` | The curated set of magic auth, database, and gate-definition events. |
| `MagicGateWatcher` | Authorization checks via `GateAccessChecked` (ability, result, user). |
| `MagicQueryWatcher` | Database queries run through Magic's ORM. |

Each watcher is read-only: it subscribes to Magic activity and records it into telescope's store. None of them writes back into your app.

<a name="the-http-adapter"></a>
### The HTTP adapter

`MagicHttpFacadeAdapter` wraps Magic's network driver with an interceptor that feeds every HTTP request and response into telescope's HTTP buffer. The adapter resolves the network driver from the IoC container, which is why `MagicTelescopeIntegration.install()` must run after `Magic.init()`.

<a name="release-builds-load-nothing"></a>
## Release builds load nothing

There is no production load path. The integrations are reachable only through `if (kDebugMode)` branches in `main()`, and the compiler strips those branches from profile and release builds. A release build loads none of `magic_devtools`, dusk, or telescope: zero enrichers, zero watchers, zero adapters, zero runtime cost. The package is a regular dependency for resolution and lint correctness only; its code never runs in production.
