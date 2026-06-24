# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Contributing checklist (before merging into `[Unreleased]`)

- [ ] CHANGELOG entry added under the appropriate bucket (BREAKING / Added / Changed / Removed / Fixed / Improvements)
- [ ] `doc/` updated when the change touches public-facing behavior
- [ ] `README.md` updated when the change touches the overview or quick-start
- [ ] `skills/magic-framework/` updated when the change touches APIs the skill documents
- [ ] `example/` updated when the change touches the canonical consumer scaffold
- [ ] `flutter test` green; `dart analyze` clean; `dart format` no diff; `dart pub publish --dry-run` no blocking errors

### Added

- **`magic:install --with-devtools` wires the debug trio in one step.** Installing the optional debug tooling (`magic_devtools` + `fluttersdk_dusk` + `fluttersdk_telescope`) previously meant a manual multi-step bootstrap: add three deps, run `plugin:install` twice, then `dusk:install` + `telescope:install`. The new `--with-devtools` flag does all of it after the core install: it adds the three packages to `dependencies` (regular, not `dev_dependencies`, because `lib/main.dart` imports them and the `kDebugMode` gate tree-shakes the subsystem from release builds, so `dev_dependencies` would trip `depend_on_referenced_packages`) and wires `lib/main.dart` under `kDebugMode` exactly as `dusk:install` / `telescope:install` do: `DuskPlugin.install()` and `TelescopePlugin.install()` (plus `ExceptionWatcher` + `DumpWatcher`) before `Magic.init()`, then `MagicDuskIntegration.install()` and `MagicTelescopeIntegration.install()` after it. The wiring is a pure-functional, idempotent transform (`buildDevtoolsWiring`) over the generated main.dart, and the dep-add rides the same `installer.addDependency` mechanism the install already uses, so re-running `magic:install --with-devtools` never duplicates a wiring block or a dependency entry. Absent the flag, nothing changes for the existing install path. Touches `lib/src/cli/commands/magic_install_command.dart`; adds the `MagicInstallCommand.buildDevtoolsWiring` test group plus a real-FS full-install group to `test/cli/commands/magic_install_command_test.dart`.
- **`MagicMiddleware.redirectTarget(String location)` for pre-build redirect guards.** Redirect-style guards (auth / guest) can now return a redirect target synchronously, evaluated inside the router's `redirect` callback BEFORE any page builds. Previously the only way to redirect was an imperative `MagicRoute.to()` inside `handle()`, which runs post-mount and remounts the destination view, recreating its form state on every mount (the login-double-mount bug). `_handleRedirect` now evaluates every matched route's global + route middleware `redirectTarget` and returns the first non-null target. The default returns `null`, and `handle()` now defaults to `next()`, so a redirect-only guard overrides just `redirectTarget`. Fully backward compatible: existing `handle()`-based guards keep working. Touches `lib/src/http/middleware/magic_middleware.dart`, `lib/src/routing/magic_router.dart`; adds `test/routing/redirect_guard_mount_test.dart` (asserts the destination mounts exactly once, including through a layout ShellRoute).

### Fixed

- **`Pick.saveFile` is source-compatible with file_picker 12.** file_picker 12 made `FilePicker.saveFile`'s `fileName` and `bytes` parameters required and non-null, which broke the analyzer build (`argument_type_not_assignable`) under a fresh `flutter pub get` that resolved the newer file_picker. `Pick.saveFile` keeps its nullable facade surface but now guards both arguments before forwarding, so the call type-checks against file_picker 11 and 12 and a null argument fails with a clear `ArgumentError` instead of an unhelpful type error. Touches `lib/src/facades/pick.dart`.
- **`Crypt` now accepts the `base64:` app key that `key:generate` produces.** `key:generate` writes `APP_KEY=base64:<base64 of 32 random bytes>`, but `EncryptionServiceProvider` required `app.key` to be a raw 32-character string and threw `App Key must be 32 characters for AES-256` on the generated key, so `Crypt.encrypt`/`decrypt` were unusable out of the box. Added `MagicEncrypter.fromAppKey(appKey)` which base64-decodes a `base64:`-prefixed key to its 32 bytes (and still accepts a raw 32-character key); `EncryptionServiceProvider` now binds through it. Touches `lib/src/encryption/magic_encrypter.dart`, `lib/src/encryption/encryption_service_provider.dart`; adds three `fromAppKey` cases to `test/encryption/magic_encrypter_test.dart`.
- **`MagicStatefulView` now calls the controller's `onInit()` lifecycle hook.** `MagicStatefulViewState.initState` listened to the controller and called the VIEW's own `onInit()` hook, but never invoked the CONTROLLER's `onInit()`, despite the documented contract. A controller that bootstraps in `onInit` (initial data load, table creation, subscriptions) silently never ran it when backed by a `MagicStatefulView`, so the screen rendered against uninitialized state (e.g. a query against a table the controller's `onInit` was supposed to create). It now calls `_controller.onInit()` guarded by `MagicController.initialized`, so a `SimpleMagicController` that already initialized in its constructor is not double-initialized and a singleton controller reused across re-mounts initializes exactly once per lifetime. Touches `lib/src/ui/magic_view.dart`; adds `test/ui/magic_view_controller_oninit_test.dart`.
- **Auth no longer warns on every boot of a fresh app.** `AuthServiceProvider.boot()` logged a `userFactory not registered` warning (blaming provider order) whenever no userFactory was set, even for apps with no stored session to restore. It now only warns when a stored session actually exists (`Auth.hasToken()`) but cannot be rebuilt; a fresh app or a logged-out user stays quiet (debug-level). The stored-session check is guarded so a misconfigured Auth (for example, no Vault registered) cannot crash boot from this warning-verbosity path. Touches `lib/src/auth/auth_service_provider.dart`; adds three cases to `test/auth/auth_test.dart`.

### Changed

- **`fluttersdk_wind` constraint bumped to `^1.1.1`.** Picks up wind 1.1.0's Material-free `WInput`/`WText` rewrite plus 1.1.1's two fixes that magic's W-widget UI depends on: `WInput` native text selection restored (mouse drag-select, double-tap word, long-press), and `WText` now inherits an ancestor `DefaultTextStyle` color (the CSS text-color cascade) before falling back to the OS-brightness baseline. The latter fixes invisible labels on magic's W-rendered surfaces (`Magic*View`, `MagicFeedback`, dialog buttons whose color lives on the container) when the app theme disagrees with the OS theme. Touches `pubspec.yaml`.
- **Debug-tooling install guidance corrected to regular `dependencies`.** The `magic:install` post-install message recommended adding `magic_devtools` / `fluttersdk_dusk` / `fluttersdk_telescope` to `dev_dependencies`, but the install commands wire them into `lib/main.dart` (under `kDebugMode`), which trips the `depend_on_referenced_packages` lint. They are now documented as regular `dependencies` (tree-shaken from release via `kDebugMode`), matching dusk/telescope's own install docs. Also bumps the message's stale `fluttersdk_dusk ^0.0.7` to `^0.0.8`. Touches `install.yaml`.

## [0.0.3] - 2026-06-17

### Stabilization (magic-stabilize-dusk-telescope plan)

- **BREAKING: the Dusk + Telescope Magic adapters moved out of magic core into the new sibling `magic_devtools` package.** `MagicDuskIntegration` (14 enrichers), `MagicTelescopeIntegration` (5 watchers + `MagicHttpFacadeAdapter`) and their tests now live in `magic_devtools`; magic core no longer depends on `fluttersdk_dusk` or `fluttersdk_telescope` at all. The class and function names are unchanged; only the import path moves and ownership shifts to a dedicated dev-tooling package. Consumer migration (pre-1.0 clean break, no shim):

  ```dart
  // before (interim sub-barrel, never released):
  import 'package:magic/dusk_integration.dart';
  import 'package:magic/telescope_integration.dart';

  // after — add magic_devtools as a dev_dependency, then:
  import 'package:magic_devtools/dusk.dart';
  import 'package:magic_devtools/telescope.dart';
  // MagicDuskIntegration.install(); / MagicTelescopeIntegration.install();
  ```

  Deletes `lib/src/cli/{dusk,telescope}_integration.dart`, the `lib/{dusk,telescope}_integration.dart` sub-barrels, and `test/cli/{dusk,telescope}_integration_test.dart` from magic; drops the two `fluttersdk_dusk` / `fluttersdk_telescope` dependency lines from `pubspec.yaml`.
- **Granular scaffold + documentation is the default (M1).** The E2E-drivability defaults (`processingListenable` + `MagicBuilder`, stable `ValueKey`, `semanticLabel` on ambiguous interactive widgets) are documented in `.claude/rules/testability.md` and reflected in generated view stubs. Opt-in, no runtime behavior break for existing consumers.
- **Testability rules formalized (M2).** `.claude/rules/testability.md` defines view drivability as the third gate of "done" alongside passing tests and correct appearance, with the three widget-identity rules dusk depends on.
- **`fluttersdk_artisan` constraint bumped `^0.0.7` -> `^0.0.8`.** Drop-in: magic uses no artisan symbol changed between the two versions.

### Fixed (consumer-blocking bugs surfaced by `/tmp` fresh-app E2E test plan)

- **`make:*` commands now work on consumers that pull magic from pub.dev / path: dependency.** `MakeControllerCommand`, `MakeModelCommand`, and the other 12 `make:*` commands used to call `StubLoader.load('controller')` directly, which searches `$ARTISAN_STUBS_DIR` → `$MAGIC_CLI_STUBS_DIR` → `fluttersdk_artisan-<version>/assets/stubs/`. Magic's own stubs live at `<magic>/assets/stubs/`; neither env var was set in typical environments, and the fluttersdk_artisan pub-cache fallback contained only artisan substrate stubs. The 14 generators now load raw stub content via the new `MagicStubLoader` helper (which resolves `<magic>/assets/stubs/<name>.stub` from the consumer's `.dart_tool/package_config.json` magic entry) and pass the content through `getStub()` for `ArtisanGeneratorCommand.buildClass` to consume as a literal template. Adds `lib/src/cli/helpers/magic_stub_loader.dart`; touches `lib/src/cli/commands/make_*.dart` × 14.
- **`magic:install` is now self-registering** — adds magic to `.artisan/plugins.json` before `plugins:refresh` runs, so `MagicArtisanProvider` appears in `lib/app/_plugins.g.dart` automatically. Consumers no longer need a separate `dart run magic:artisan plugin:install magic` step before invoking `make:controller` etc. Touches `lib/src/cli/commands/magic_install_command.dart` (adds `_selfRegisterPlugin`).
- **`plugin:install magic` re-invocations no longer corrupt `lib/config/app.dart`.** The static `install/app_config` publish entry rendered the raw `{{ allImports }}` / `{{ allProviders }}` placeholders when invoked outside `MagicInstallCommand.handle` (where the fluent override would overwrite with the dynamic providers list). Removed `install/app_config: lib/config/app.dart` from `install.yaml` `publish:`; the fluent override is now the sole writer. Touches `install.yaml`.
- **`assets/lang/en.json` is now scaffolded on install.** Adds `install/lang_en: assets/lang/en.json` to `install.yaml` `publish:` with a minimal stub covering `common.welcome`, `common.loading`, …, and a `validation.*` block matching the built-in rule names. Consumers using `Lang.trans('common.welcome')` now resolve out of the box; previously the lang dir was empty until the operator ran `make:lang`. Touches `install.yaml`, adds `assets/stubs/install/lang_en.stub`.

### Fixed (PR #87 code review)

- **Cache hit/miss detection no longer misclassifies.** `CacheManager.get()` decided hit-vs-miss with `value == defaultValue`, which dispatched a `CacheMiss` when the stored value happened to equal the caller's `defaultValue`, or when a stored `null` was read with a `null` default. It now uses `driver().has(key)` for presence. Touches `lib/src/cache/cache_manager.dart`; adds two regression cases to `test/cache/cache_manager_event_dispatch_test.dart`.
- **`KeyGenerateCommand` reuses a single `Random.secure()`** instead of constructing one per byte. Touches `lib/src/cli/commands/key_generate_command.dart`.
- **Removed the unused `yaml_edit` dependency** from `pubspec.yaml` (no `lib/`, `test/`, or `bin/` references), trimming transitive deps and publish surface.
- **Example app shows a real title.** `example/.env` `APP_NAME` is now `"Magic Example"` (was `""`) and `welcome_view.dart` falls back to a non-empty `app.name`, so the example no longer renders a blank title. Touches `example/.env`, `example/lib/resources/views/welcome_view.dart`.

### Improvements (UX)

- **`magic:install` post-install message documents the optional Dusk + Telescope setup chain.** Removed the obsolete sqlite3.wasm warning (the install command auto-fetches sqlite3.wasm 3.3.1 since the artisan-install-command-magic plan). Added a setup recipe pointing operators at the `magic_devtools` dev_dependency (plus `fluttersdk_dusk` / `fluttersdk_telescope`) and the `package:magic_devtools/{dusk,telescope}.dart` adapter imports, so the debug-tooling path is discoverable without consulting the docs. Touches `install.yaml` (`post_install.message`).

### Changed

- **Documentation: CLAUDE.local.md updated to reflect artisan-based CLI.** The stale `magic_cli` companion-project sync protocol (cross-repo stub sync, provider coupling) has been retired. Magic now owns its CLI and generators under `lib/src/cli/` on the `fluttersdk_artisan` substrate. Updated `CLAUDE.local.md` to document the current architecture (command locations, install manifest, stub loading) and deprecation of the legacy magic_cli sync procedure.

### Deferred

- `magic:install --with-debug-tooling` single-command flag that chains the 6-step Dusk + Telescope setup recipe (currently the post_install message documents the recipe; the flag would auto-execute it). Tracking issue: TBD.
- `MainDartSmartMerger` should consolidate the 4 `if (kDebugMode) { ... }` blocks that `dusk:install` + `telescope:install` emit into 2 blocks (pre-`Magic.init()` host plugins + post-`Magic.init()` Magic adapters). Currently each install command writes its own block, producing four single-statement blocks. Tracking issue: TBD.

### Changed (artisan-install-command-magic plan)

- **`magic:install` now delegates canonical Flutter scaffold to artisan's `install` command in-process.** After `stagedInstaller.commit()` returns Success, `delegateArtisanInstall` invokes `InstallCommand.scaffoldInto` (from the artisan public barrel) to write `bin/dispatcher.dart` + barrels + pubspec dep + bin/fsa. Gated inside the existing `if (result is Success)` block so dry-run / Conflict / Error results skip the delegation and atomic-commit semantics are preserved. Magic-specific extras (conditional configs, dynamic `lib/config/app.dart`, `lib/main.dart` smart-merge, sqlite3.wasm) remain magic-side.

### Removed (artisan-install-command-magic plan)

- **`install.yaml` 11th publish entry (`install/consumer_artisan: bin/artisan.dart`) dropped.** Artisan's `install` command now writes the canonical dispatcher to `bin/dispatcher.dart`; magic no longer ships a separate consumer wrapper. Magic-managed consumers reach the same canonical state via the delegation flow.

### Added (dusk-magic-wind enrichment Wave 3 / Wave 4 wiring)

- **`MagicHttpFacadeAdapter.pendingCount` override** (Step 3.4 cross-package).
  Proxies to the file-private `_TelescopeNetworkInterceptor._pending.length`
  (null-guarded pre-install, returns 0). Reads the live in-flight FIFO so
  `TelescopeStore.pendingHttpCount` can sum across registered adapters.
  Powers dusk's `ext.dusk.wait_for_network_idle` end-to-end.
- **Magic-side reader wiring for dusk's telescope-backed tools**
  (Steps 3.4 + 3.5). `MagicTelescopeIntegration.install()` now also
  assigns three function-pointer readers exported from
  `package:fluttersdk_dusk/dusk.dart`:
  - `pendingHttpCountReader = () => TelescopeStore.pendingHttpCount`
  - `recentLogsReader = TelescopeStore.recentLogs(...) → dusk envelope`
    (renames `loggerName` → `logger`, ISO-formats timestamps)
  - `recentExceptionsReader = TelescopeStore.recentExceptions(...) → dusk envelope`
    (renames `exceptionType` → `type`, truncates stackTrace to first
    3 lines as `stackHead`)
  The indirection lives on the dusk side; dusk has no hard dep on
  telescope. Magic is the only crossover point. Dusk hosts that do not
  ship `fluttersdk_telescope` get the default empty-list readers
  (missing-telescope graceful path).
- **New `test/cli/telescope_integration_test.dart`** (6 cases): pre-install
  null-guard, post-install zero, in-flight count, FIFO decrement,
  post-uninstall null-guard, end-to-end via `TelescopeStore.pendingHttpCount`.

### Changed (BREAKING for magic_cli legacy users; non-breaking via legacy fallback)

- **`magic:install` rewrite to PluginInstaller DSL + install.yaml manifest**.
  The command extends `ArtisanInstallCommand` (from fluttersdk_artisan
  ^1.0.0-alpha.1+) and delegates the install.yaml-expressible 60% to
  `ManifestInstaller`. The conditional 40% (per-flag config emission, dynamic
  `lib/main.dart` configFactories list, dynamic `lib/config/app.dart` provider
  list, app name extraction from pubspec.yaml) lives in a fluent override
  hook on `ManifestInstaller.prepare()`. Existing `--without-*` flags map
  1:1 to install.yaml `prompts:` (bool type, default false).

  Backward compat: `dart run :artisan magic:install` continues to work via
  legacy fallback; the new canonical workflow is
  `dart run :artisan plugin:install magic` (auto-detects install.yaml,
  routes through ManifestInstaller in one step).

- **REVERTED**: First install on a fresh `flutter create` app NO LONGER requires `--force`.
  `MagicInstallCommand._resolveMainDartStrategy` calls
  `MainDartScaffoldDetector.isFlutterCreateScaffold` BEFORE the
  ConflictDetector path; when the existing `lib/main.dart` matches the
  flutter create scaffold heuristic, `scaffoldDetected=true` flows into
  `PluginInstaller.commit(force: true)` and bypasses the unmanaged-file
  check silently. Operators now run `dart run magic:artisan magic:install`
  on a fresh `flutter create` app without any flag; customized `lib/main.dart`
  still requires `--force` or `--preserve` explicitly. (CHANGELOG entry from
  an earlier alpha was stale; the scaffold detector landed before alpha-15
  but the entry was not removed.)

- **`sqlite3.wasm` auto-download wired into `magic:install`**. When the
  database feature is enabled (no `--without-database` flag) and the run
  is not a dry-run, `MagicInstallCommand` now fetches the matching
  `sqlite3.wasm` from `simolus3/sqlite3.dart` (pinned to 3.3.1) and
  writes it to `web/sqlite3.wasm` after the install commits. Closes the
  white-screen / `WebAssembly TypeError` failure mode that hit fresh
  Flutter web targets on first run.

### ✨ New Features

- **Dusk enricher expansion** (7 new enrichers + 1 extension):
  - `magicControllerFlagsEnricher` - captures FutureOr status, loading/success/error flags from `MagicStateMixin`
  - `magicRouteParamsEnricher` - emits route parameters (path params + query string)
  - `magicFormErrorsEnricher` (extension) - now quotes per-field error messages to preserve whitespace
  - `magicEchoConnectionEnricher` - reports broadcast connection state (connecting/connected/disconnected/reconnecting)
  - `magicGateResultsAllEnricher` - emits last N gate check results (ability: allowed/denied) from MRU cache
  - `magicRecentHttpEnricher` - emits last 5 HTTP requests (method, URL, status, elapsed time)
  - `magicRecentLogsEnricher` - emits last 5 log entries (level, message, timestamp)
  - `magicRecentExceptionsEnricher` - emits last 5 exceptions (type, message, stack trace truncated to 500 chars)

  All new enrichers guard `kDebugMode` and handle missing dependencies gracefully (telescope-not-installed returns null buffer). Registered by `MagicDuskIntegration.install()`. Combined with existing 7 enrichers (`magicControllerState`, `magicFormErrors`, `magicGateResult`, `magicMiddleware`, `magicAuthUser`, `magicFormField`, `magicRoute`), magic-side surface now totals 14 enrichers. Ships in coordinated bump with fluttersdk_dusk 1.0.0-alpha.3+.

- **Dusk integration**: 5 new snapshot enrichers (`magicControllerState`,
  `magicFormErrors`, `magicGateResult`, `magicMiddleware`, `magicAuthUser`)
  registered by `MagicDuskIntegration.install()` for richer LLM-agent E2E
  context. Combined with the 2 alpha-1 enrichers (`magicFormField`,
  `magicRoute`) this brings the magic-side surface to 7 enrichers; with
  Wind's 6-field `WindClassNameEnricher` the total enricher surface is 8.
  Ships in coordinated bump with fluttersdk_dusk 1.0.0-alpha.2 (see
  `references/fluttersdk_dusk/CHANGELOG.md` for the matching dusk-side
  contract additions: 7 new handlers, 10 new MCP descriptors, 8 new CLI
  commands, actionability gate, `dusk_find` Locator pattern, Chrome
  reaper, `dusk:doctor`). Requires fluttersdk_dusk ^1.0.0-alpha.2 — the
  `DuskSnapshotEnricher` typedef is frozen across both repos for the
  alpha-2 cycle.

- **Cache events**: `CacheHit`, `CacheMiss`, `CachePut`, `CacheForget`,
  `CacheFlush` event classes added under `lib/src/cache/events/cache_events.dart`
  and exported from `package:magic/magic.dart`. `CacheManager.get` /
  `put` / `forget` / `flush` now dispatch the matching event through
  `EventDispatcher.instance` after the underlying store operation
  completes. Enables `fluttersdk_telescope`'s `MagicCacheWatcher` (and
  any user-defined listener) to observe the full cache lifecycle.

- **Test coverage**: new `MagicInstallCommand` exercised by 27 tests using
  InstallContext.test + InMemoryFs + FakePromptDriver + FakeStubDriver
  injection; one test per `--without-X` flag plus first-install `--force`
  + app name extraction edge cases. Coverage: 76.5% (defensive error paths
  not covered; accepted per Risks Accepted in the migration plan).

### 🔧 Improvements

- **Routing**: `MagicRouter.currentRoute` public getter for the currently-resolved
  RouteDefinition.
- **Auth**: `GateManager.lastResult(ability)` accessor backed by an MRU cache
  (64 entries) of the most recent gate-check outcome per ability.

### ✨ New Features
- **Eloquent**: `Model.fill` now accepts a `strict` flag. When `true`, any non-fillable key throws `MassAssignmentException` instead of being silently dropped. Pair with validated request payloads to catch schema drift at the boundary. (#69)
- **Validation**: `FormRequest` — Laravel-style request object that collapses authorize → prepare → validate into a single class. Throws `AuthorizationException` on denied access and `ValidationException` with a field-keyed error map on rule failure. Pairs with `Model.fill(validated, strict: true)`. (#66)
- **HTTP**: `MagicController.authorize(ability, [arguments])`, a Laravel-style controller helper that delegates to `Gate.allows()` and throws `AuthorizationException` on denial. Avoids hand-rolling gate checks in every action. (#72)
- **Auth**: `Gate.allowsAny(abilities, [arguments])` and `Gate.allowsAll(abilities, [arguments])`, short-circuiting sugar for checking multiple abilities at once. (#72)
- **Routing**: `MagicRoute.resource(name, controller, {only, except})` auto-wires up to four canonical routes (index, create, show, edit) to a controller that mixes in `ResourceController`. Controllers declare supported methods via `resourceMethods`; `only` / `except` narrow the set further. Each route gets an auto-assigned `{slug}.{method}` name and title. (#67)
- **Validation**: `AsyncRule` contract plus `Unique(endpoint, field: ...)` rule, an async uniqueness check with per-instance debounce (coalesces rapid calls) and a pluggable `.via()` resolver. Network errors log and pass so they never block submission. `Validator.validateAsync()` runs async rules after sync rules; sync failures short-circuit per field. (#68)
- **Session**: Add `Session` facade with Laravel-style flash data — `Session.flash(data)`, `Session.flashErrors(errors)`, `Session.old(field, [fallback])`, `Session.error(field)`, `Session.errors(field)`, `Session.hasError(field)`, `Session.hasFlash`, `Session.tick()`. Two-bucket store promotes flashed data exactly one navigation hop so forms can repopulate after a failed submit. Top-level helpers `old()` and `error()` mirror Laravel's Blade API
- **UI**: `MagicFormData.validate()` automatically flashes form data on validation failure — downstream views can repopulate via `old('field')` without manual wiring
- **Validation**: `In<T>` rule accepts a primitive whitelist (strings, ints, etc.) and `InList<T extends Enum>` validates enum-backed fields, accepting either the enum instance or a wire string. `InList` supports `caseInsensitive:` and an optional `wire:` mapper for snake_case or custom representations. Both emit the shared `validation.in` message with a comma-joined `:values` parameter. (#81)

## [1.0.0-alpha.13] - 2026-04-16

### ✨ New Features
- **Routing**: Add `currentPath` getter to `MagicRouter` — returns the current route path without query string, complementing the existing `currentLocation` property

### 🐛 Bug Fixes
- **Routing**: Use `GoRouter.pop()` instead of `Navigator.pop()` in `back()` — syncs router state and preserves custom page transitions on reverse animation. Add `StateError` guard when router is not initialized, consistent with `to()` and `replace()`

### 🔧 Improvements
- **Skill**: Optimize `magic-framework` skill for Claude Code progressive disclosure — split frontmatter, extract templates to references, compress sections (669 → 416 lines). Add version frontmatter and source-to-skill mapping in release command
- **Deps**: Bump magic version constraint in example app

## [1.0.0-alpha.12] - 2026-04-09

### ✨ New Features
- **Broadcasting**: Client-side activity monitor — detects silent connection loss using Pusher protocol `activity_timeout` and `pusher:ping`/`pusher:pong`. Automatically reconnects when the server stops responding
- **Broadcasting**: Random jitter (up to 30%) on reconnection backoff delay — prevents thundering herd when many clients reconnect simultaneously after a server restart
- **Broadcasting**: Configurable connection establishment timeout (default 15s) — prevents indefinite hang when server doesn't complete the Pusher handshake. Automatically triggers reconnect on timeout

## [1.0.0-alpha.11] - 2026-04-07

### 🐛 Bug Fixes
- **Routing**: Fix intermittent page title loss on web — Flutter's `Title` widget was overwriting TitleManager's route-level title on `didChangeDependencies()` rebuilds. Use `onGenerateTitle` to keep both in sync

### ⚠️ Breaking Changes
- **file_picker**: Upgrade from `^10.3.10` to `^11.0.2` — migrates to static API (`FilePicker.platform` removed). Consumers using `FilePicker.platform` directly (via `magic.dart` re-export) must switch to static calls (`FilePicker.pickFiles()`, `FilePicker.getDirectoryPath()`, `FilePicker.saveFile()`). Includes Android path traversal security fix (CWE-22) and WASM web support

## [1.0.0-alpha.10] - 2026-04-07

### ✨ New Features
- **Routing**: Route-level page title management with `TitleManager` singleton. Per-route titles via `RouteDefinition.title()`, automatic suffix pattern via `MagicApplication(titleSuffix:)`, declarative `MagicTitle` widget for data-dependent titles, and imperative `MagicRoute.setTitle()` / `MagicRoute.currentTitle` API. Title resolution: MagicTitle > setTitle > RouteDefinition.title > MagicApplication.title. (#49)

### 🔧 Improvements
- **Dependencies**: Bump `magic_cli` to `^0.0.1-alpha.6` (scaffold templates now include `.title()` and `titleSuffix`)

## [1.0.0-alpha.9] - 2026-04-07

### 🐛 Bug Fixes
- **Broadcasting**: Auth failures in private/presence channels now surface via `Log.error()` and interceptor `onError()` chain instead of being silently swallowed. Reconnect resubscribes all channels with `await` — `onReconnect` stream emits only after completion. Per-channel error handling ensures one auth failure does not block other channels. (#45)
- **Database**: `sqlite3.wasm` now loads via absolute URI (`/sqlite3.wasm`) instead of relative — fixes 404s on deep routes when using path URL strategy. (#46)

## [1.0.0-alpha.8] - 2026-04-07

### ✨ Features
- feat: config-driven path URL strategy for Flutter web (#40)

## [1.0.0-alpha.7] - 2026-04-06

### ✨ Features
- **Broadcasting**: `Echo` facade, `BroadcastManager`, `ReverbBroadcastDriver` (Pusher-compatible WebSocket with reconnection, dedup, heartbeat), `NullBroadcastDriver`, `BroadcastInterceptor` pipeline, `FakeBroadcastManager`, `BroadcastServiceProvider`. Laravel Echo equivalent for real-time channels. (#38)
- **Router Observers**: `MagicRouter.instance.addObserver()` enables NavigatorObserver integration for analytics/monitoring (Sentry, Firebase Analytics, custom observers). Observers are passed to GoRouter automatically. (#34)
- **Network Driver Plugin Hook**: `DioNetworkDriver.configureDriver()` exposes the underlying Dio instance for SDK integrations (sentry_dio, certificate pinning, custom adapters). (#35)
- **Custom Log Drivers**: `LogManager.extend()` enables custom LoggerDriver registration (Sentry, file, Slack). Config-driven resolution with built-in override support. (#36)

## [1.0.0-alpha.6] - 2026-04-05

### ✨ Features
- **Http Faking**: `Http.fake()` enables Laravel-style HTTP faking for testing. Swap the real network driver with a `FakeNetworkDriver` that records requests and returns stubbed responses. Supports URL pattern stubs, callback stubs, and assertion methods (`assertSent`, `assertNotSent`, `assertNothingSent`, `assertSentCount`). (#18)
- **Facade Faking**: `Auth.fake()`, `Cache.fake()`, `Vault.fake()`, `Log.fake()` — Laravel-style facade faking for testing. Swap real service implementations with in-memory fakes that record operations and expose assertion helpers. (#19)
- **Fetch Helpers**: `fetchList()` / `fetchOne()` on `MagicStateMixin` — auto state management for HTTP fetches with defensive type guards against malformed responses (#20)
- **MagicTest**: `MagicTest.init()` / `MagicTest.boot()` — standardized test bootstrap helper, `package:magic/testing.dart` barrel export (#21)

### 🐛 Bug Fixes
- **Log.channel()**: Now returns `LoggerDriver` via `_manager.driver(name)` instead of `LogManager`, enabling `Log.channel('slack').error(...)` as documented (#27)
- **Http.response() null data**: Sentinel pattern allows `Http.response(null, 204)` for No Content stubs while `Http.response()` still returns mutable empty map (#26)
- **URL pattern escaping**: `FakeNetworkDriver` stub patterns now escape regex metacharacters (`.`, `?`, `+`) via `RegExp.escape()` — only `*` is treated as wildcard (#26)
- **fetchList/fetchOne defensive guards**: Type-check `response.data` as `Map` before indexing, filter non-`Map` elements in lists via `whereType<Map>()`, guard `fetchOne` data cast (#28)

## [1.0.0-alpha.5] - 2026-03-29

### 🐛 Bug Fixes
- **Route Back Navigation**: `MagicRoute.back()` now works after `go()`-based navigation (cross-shell). Maintains lightweight history stack with automatic fallback. Optional `fallback` parameter for explicit control. (#11)

## [1.0.0-alpha.4] - 2026-03-29

### 🔧 Improvements
- **Localization Hot Restart**: Translation JSON changes now reflect on hot restart during development. Uses fetch with cache-busting on web and best-effort disk reads on desktop, bypassing Flutter's asset bundle cache. Zero impact on release builds.

## [1.0.0-alpha.3] - 2026-03-24

### 🐛 Bug Fixes
- **Logo on pub.dev**: Use absolute URL for logo image so it renders correctly on pub.dev

### 🔧 Improvements
- **TDD Development Flow**: Added strict TDD rules and verification cycle to CLAUDE.md

## [1.0.0-alpha.2] - 2026-03-24

### ⚠️ Breaking Changes
- **Pub.dev Migration**: Replaced git submodule path dependencies with pub.dev hosted packages (`fluttersdk_wind: ^1.0.0-alpha.4`, `magic_cli: ^0.0.1-alpha.3`). Removed `plugins/` directory entirely.
- **SDK Bump**: Dart `>=3.11.0 <4.0.0`, Flutter `>=3.41.0` (previously Dart >=3.4.0, Flutter >=3.22.0)

### ✨ New Features
- **Launch Facade**: URL, email, phone, and SMS launching via `url_launcher` with `Launch.url()`, `Launch.email()`, `Launch.phone()`, `Launch.sms()`
- **Form Processing**: `process()`, `isProcessing`, and `processingListenable` on `MagicFormData` for form-scoped loading state
- **Reactive Auth State**: `stateNotifier` on Guard contract and BaseGuard for reactive auth state UI
- **Query Parameters**: `Request.query()`, `Request.queryAll`, `MagicRouter.queryParameter()` for URL query parameter access
- **Localization Interceptor**: Automatic `Accept-Language` and `X-Timezone` headers on HTTP requests
- **Theme Persistence**: Auto-persist dark/light theme preference via Vault in `MagicApplication`
- **Validation Helpers**: `clearErrors()` and `clearFieldError()` on `ValidatesRequests` mixin
- **Route Names**: Route name registration on `RouteDefinition`

### 🐛 Bug Fixes
- **Auth Config**: Default config now properly wrapped under `'auth'` key
- **Session Restore**: Guards against missing `userFactory` — gracefully skips instead of throwing
- **Barrel Export**: `FileStore` exported from barrel file
- **Package Name**: Renamed internal references from `fluttersdk_magic` to `magic`

### 🔧 Improvements
- **Dependency Upgrades**: go_router ^17.1.0, sqlite3 ^3.2.0, share_plus ^12.0.1, file_picker ^10.3.10, flutter_lints ^6.0.0, and more
- **CLI Docs**: Rewrote Magic CLI documentation with all 16 commands and `dart run magic:magic` syntax
- **Wind UI Docs**: Moved to [wind.fluttersdk.com](https://wind.fluttersdk.com/getting-started/installation), removed local copy
- **Example App**: Rebuilt with fresh `flutter create` and `magic install`
- **CI Pipeline**: Upgraded GitHub Actions, added validate gate to publish workflow
- **Claude Code**: Added path-scoped `.claude/rules/` for 8 domains, auto-format and auto-analyze hooks

## [1.0.0-alpha.1] - 2026-02-05

### ✨ Core Features
- Laravel-inspired MVC architecture
- Eloquent-style ORM with relationships
- GoRouter-based routing with middleware support
- Service Provider pattern
- Facade pattern for global access
- Policy-based authorization

### 📦 Package Structure
- Complete model system with HasTimestamps, InteractsWithPersistence
- HTTP client with interceptors
- Form validation system
- Event/Listener system

### 🔧 Developer Experience
- Magic CLI integration
- Hot reload support
- AI agent documentation
