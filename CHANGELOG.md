# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

- **`MagicPaginator<E>` and `MagicPaginatedListView<E>`: a collection that arrives one page at a time and costs the viewport rather than the result.** `fetchList` reads the `data` key, replaces whatever was there, and ignores the pagination envelope entirely, so the only shape it supports is "fetch everything and render everything". That is fine for a settings screen and wrong for a log, a check history or a feed: rendering a long collection as a column of every row costs one build, one layout and one semantics node per row on the FIRST frame, whether or not the reader ever scrolls that far. The paginator holds the rows fetched so far, knows whether the server has more, and appends; the list widget builds only what the viewport can show and asks for the next page as the tail comes into view. Measured in a widget test: 500 rows in a 300px viewport cost fewer than 30 `itemBuilder` calls. (`lib/src/http/magic_paginator.dart`, `lib/src/ui/magic_paginated_list_view.dart`)

- **Both Laravel envelopes are read, and the mode is taken from the response rather than configured.** A `meta.next_cursor` key means `cursorPaginate()` and the next page is requested with `?cursor=`; a `meta.current_page` key means `paginate()` and the next page is `?page=n+1`; neither means a bare collection that is already complete. **Reach for `cursorPaginate()` on anything that grows at the head**, which is most live data: offset addresses a page by counting from the start, so a row inserted at the top between two requests shifts everything down and page two repeats the last row of page one. A cursor names a position in the ordering, so it cannot drift, and the database answers it without counting past the rows it skips. The KEY identifies the mode and its VALUE decides `hasMore`, because `next_cursor` is present and null on the last cursor page.

- **The failure modes are guarded here rather than left to every caller.** `loadMore()` is a no-op while a request is in flight, because an infinite-scroll list fires it from a scroll callback that runs on every frame near the end; without the guard the same page is fetched and appended several times and every row in it shows two or three times. A failed `loadMore()` keeps the rows already on screen and leaves `hasMore` alone: losing page one because page two timed out is worse than the timeout, and the retry needs a target. A **transport** failure is one of them: `DioNetworkDriver` reports a timeout or a dead link as statusCode 0, which is neither `failed` (>= 400) nor `successful`, so the check is `!response.successful` and an offline first page reports an error rather than rendering as an empty collection. Disposing mid-request is safe (every notify is guarded, the way `MagicController.refreshUI` is), and a `refresh()` issued while the tail is auto-fetching waits for that page and then starts over instead of silently doing nothing. `items` is a live `UnmodifiableListView` rather than a `List.unmodifiable` copy, since the widget reads it once per build and a copy per frame is the cost this class exists to avoid.

- **A first page shorter than the viewport still fetches its successor.** Scroll notifications only fire when a list actually scrolls, so a page that does not fill the viewport left the reader with a truncated list and no way to extend it, which any `perPage` smaller than a tall viewport reaches. `MagicPaginatedListView` checks `maxScrollExtent` after the frame and asks for the next page when there is nothing to scroll.

## [0.0.8] - 2026-08-25

### Fixed

- **A `logout()` that could not clear one thing cleared nothing after it.** The steps ran in sequence, and `Vault.delete` throws `MagicVaultException` on a platform error (a locked keychain, a lost entitlement), so a failure on the very first delete left the cached user on disk, left the user in memory, and never bumped `stateNotifier`: the app went on rendering a signed-in session while the caller was told the logout had failed. Every step is now attempted whatever the earlier ones did, the in-memory clear and the notify happen unconditionally because they are the parts that cannot fail, and the first failure is rethrown at the end so the caller still learns a credential may have survived. `clearTokens()` had the same shape one level down and left the refresh token behind, which is a live session on the next launch. (`lib/src/auth/guards/base_guard.dart`)

- **`MagicEncrypter`'s documentation promised a MAC it does not have.** The class docstring said every encrypted value "is signed using a message authentication code (MAC) so that their underlying value can not be modified or tampered with once encrypted", and `decrypt` referred to a "MAC signature check (handled internally)". There is no MAC anywhere: the payload is `base64(iv):base64(ciphertext)` under AES-256-CBC, and Laravel's `Encrypter`, whose wording this was, is where the HMAC-SHA256 actually lives. That makes CBC malleability reachable (flipping a bit in the IV predictably flips the matching bits of the first plaintext block, and decryption still succeeds) and makes a caller who reports the failure back to whoever supplied the payload into a padding oracle. No behaviour changed here; the docs now describe what the cipher does and does not give you, and a test flips an IV bit to prove the tamper goes undetected, so the claim is checkable rather than asserted. Adding the MAC is a separate decision because it breaks the payload format, and accepting the old format alongside it would be a downgrade attack rather than a fix. (`lib/src/encryption/magic_encrypter.dart`, `lib/src/facades/crypt.dart`)

- **Reading a relation marked the model dirty.** `getRelation` / `getRelations` materialise a nested Map into a `Model` and cache it back into the attribute map, but dirty tracking compares that map against the original snapshot, which still held the raw Map. So `post.author` reported the model as modified and `getDirty()` returned a `Model` object where every other value is a storage primitive. Materialised relations now live in their own cache, so the attribute map stays raw and the dirty comparison is always raw against raw. That holds on a model hydrated with `sync: true` and on one built with `fill()` alike; an earlier attempt only covered the first, and left a filled model returning a `Model` object from `getDirty()` among storage primitives. Serialisation is unchanged: a relation that has been read still goes through its model's own `toMap`, and one that has not is still the raw nested Map. (`lib/src/database/eloquent/model.dart`)

- **A cast ran on every read.** `getAttribute` re-ran `Carbon.parse` per call and stored nothing, so a widget reading `incident.startedAt` while building a row paid for it per row per frame. Measured over 18,000 reads across 50 models: 5,895ns per read before, 2,385ns after. Results are memoised in a separate map rather than in the attribute map, deliberately, so the defect above is not recreated: a `Carbon` sitting where a String belongs would report a read as a modification and change what a save sends. **`json` is deliberately excluded** because a decoded Map is mutable: sharing one instance would make `user.settings['theme'] = 'light'` stick for every later read while the raw attribute still held the old JSON, so the model would stay clean and a save would send the pre-mutation value. The mutation is lost either way, since nothing writes it back, but without the memo it is lost visibly on the next read rather than silently at save time. A `CastsAttributes` instance is excluded too; it may derive its answer from something other than the attribute. Invalidated by `setAttribute` for one key and `setRawAttributes` for all. (`lib/src/database/eloquent/model.dart`)

- **Rebinding a key that had already been resolved did nothing.** `make()` reads the instance cache before the bindings and `bind()` never cleared it, so overriding a key a starter package had resolved kept serving the first instance with nothing to say the override was ignored. **Ordering rule this introduces:** a driver or fake installed with `setInstance` (which is how `Log.setDriver`, `Auth.setDriver`, `Cache.setDriver`, `Http.setDriver`, `Vault.setDriver` and `Echo.setManager` all work) is now evicted by a later `bind`/`singleton` on the same key. Install fakes AFTER `Magic.init()` and after provider registration, not before. (`lib/src/foundation/application.dart`)

- **A service provider registered after `boot()` never booted.** `boot()` early-returns once the app is booted, so a late registration ran `register()` and silently skipped `boot()`, leaving the provider half initialised. That is the state a plugin installing itself lazily lands in. Registering the same provider INSTANCE twice also ran both hooks twice, which for a provider that starts a poller means two of them. The guard is identity rather than class, deliberately: a provider class parameterised per plugin and registered once per plugin is a legitimate shape here. (`lib/src/foundation/application.dart`)

- **The cache wrote to disk on the read path.** `get()` is synchronous, so the `_persist()` it fired on an eviction could not be awaited: a failure had nowhere to go and surfaced as an unhandled async error rather than a cache miss, and reading N stale keys rewrote the whole file N times. Expiry and entry shape are re-checked on every read, so a row left on disk is inert and the next write drops it. Both the IO and web stores are fixed. An unparseable cache file now prints why it is being discarded instead of resetting silently. (`lib/src/cache/drivers/file_store_io.dart`, `lib/src/cache/drivers/file_store_web.dart`)

- **Flushing the container left every event listener attached.** `EventDispatcher` is its own static singleton, so `MagicApp.flush()` and `MagicApp.reset()` dropped the providers but not the listeners they had registered, even though `reset()` documents itself as destroying the entire application instance. A re-bootstrap ended up with two of every listener, so one event sent two emails, and a test file that forgot to clear the dispatcher by hand leaked into the next. (`lib/src/foundation/application.dart`)

### Changed

- **`MagicApp.register()` and `Magic.register()` return `Future<void>`.** They used to return `void`. Callers that ignore the future are unaffected and it completes immediately before the boot phase; after boot it completes when the newly registered provider has finished booting, so `await Magic.register(p)` no longer races the wiring it just asked for. The body stays synchronous on purpose: an `async` body would capture a throw from the provider's own `register()` into the future, and since `Magic.init()` does not await, a bootstrap failure would stop being loud and arrive later as an unhandled zone error instead. (`lib/src/foundation/application.dart`, `lib/src/foundation/magic.dart`)

- **`EventDispatcher.dispatch` documents its divergence honestly.** A listener that throws is caught and logged and the rest still run, which is deliberate (on a client, one bad listener must not take down the frame) and differs from Laravel, whose dispatcher lets it propagate. The docstring claimed rethrowing "can be configured"; nothing configures it, and it now says so. (`lib/src/events/event_dispatcher.dart`)

---

## [0.0.7] - 2026-08-25

### Fixed

- **A validation error arriving after its controller was disposed threw.** The five `notifyListeners()` calls in `ValidatesRequests` sat outside `refreshUI()`'s `if (!_disposed)` guard, and `notifyListeners()` on a disposed `ChangeNotifier` raises a `FlutterError`. A late API failure resolving onto a torn-down form controller, which is ordinary on a slow network, hit it. Routing those five through `refreshUI()` puts them behind the guard they never had. (`lib/src/concerns/validates_requests.dart`)

- **A cold start with no working backend showed a blank window for as long as the client timeout, because `restore()` waited for a call whose answer the cache had already given.** `AuthServiceProvider.boot()` awaits `Auth.restore()`, which holds `Magic.init()`, which holds `runApp`, so everything `restore()` awaited was time the user spent looking at nothing. It awaited `_syncUserFromApi()` even after `loadCachedUser()` had produced a user and `setUser` had put it in place. Against a backend that accepts the connection and then says nothing (a captive portal, a dead mobile link, a hung server) that is the entire timeout: measured on an iPhone 17 simulator against an app configured for 120s as roughly two minutes of white screen, with the console stopping dead on `Auth: Cached user restored` and the theme's own boot logging not appearing until it let go. The class docblock has described the intent as "2. Sync from API in background" since it was written. The sync is now awaited only when the cache had nothing to show, because then there is nothing to render and no honest way to route; with a cached user the screen renders now and corrects itself when the sync lands, which is what `AuthRestored` already exists to announce. (`lib/src/auth/guards/base_guard.dart`, `test/auth/auth_test.dart`)
- **Losing the network signed the user out and destroyed the stored session.** `_syncUserFromApi()` treated any non-2xx as a rejected token and called `logout()`, and `DioNetworkDriver._handleError` reports a transport failure as `statusCode: 0`, because a timeout, a DNS miss or a dead link has no response to report. So a phone going through a tunnel during the restore call cleared the token and the cached user and dropped the app on the sign-in screen, while the log said `Auth: Token invalid` about a server that never spoke. Reproduced on a device: after one offline cold start the next launch logged `Auth: No token found in storage`. Only a `401` or a `403` ends a session now; every other failure keeps the cached one and logs what actually happened, including the status it saw. (`lib/src/auth/guards/base_guard.dart`, `test/auth/auth_test.dart`)

- **`Pick`'s two gallery fallbacks escaped their own error handling, and CI could not build until it was fixed.** `pickFromCamera` and `pickVideoFromCamera` returned the fallback future without awaiting it, so the future left the `try` block before completing: a failure inside the fallback never reached the `catch`, and the `onError` callback the caller supplied never fired. Flutter 3.47 added `unawaited_return_in_try_block`, which turned the latent bug into two analyzer warnings and a red `Lint & Test` job on every branch, including ones that never touch this file. Both are awaited now, which fixes the reporting and the build together. (`lib/src/facades/pick.dart`)
- **Every page this router built was anonymous, which silently disabled every screen-aware observer.** `GoRoute.name` names the ROUTE and never reaches `RouteSettings`, so a `NavigatorObserver` reading `route.settings.name` got `null` on every push and could not tell one screen from another. Analytics, breadcrumb trails and Sentry's Flutter Web release health all key on exactly that value, and the last one fails in the worst possible way: the transport keeps working, events keep arriving, and the session count sits at zero forever with nothing in any log to explain it, because `WebSessionHandler.startSession` only fires when the name CHANGES (or on the first navigation when it is exactly `/`). Measured on a deployed app before this fix: a browser with no ad blocker made zero requests to Sentry's ingest across three route changes while a forced `captureMessage` from the same page returned 200. All five pages the transition switch returns now carry `route.routeName ?? route.fullPath`. The fallback is the path rather than nothing, because `.name()` is optional and most routes never call it, so keying only on `routeName` would have left the common case exactly as broken as before; the path is always present, already unique per route, and on the root route it produces the `/` that the first-session rule wants. (`lib/src/routing/magic_router.dart`, `test/routing/page_route_name_test.dart`)

### Improvements

- **The FileStore expiration test no longer races the clock, so master stops going red at random.** `it handles expiration` wrote a value with a 100ms TTL and immediately asserted it was readable. That window had to survive a file write plus the scheduler, and on a loaded CI runner it did not: the entry expired before the read and the assertion failed with `Expected: 'value' Actual: <null>` while the store was behaving correctly. It failed twice today, once on a PR and once on master after merge. The readable case now uses a 5-minute TTL, and the expiry case passes an already-elapsed TTL so `expire_at` lands in the past by construction, which removes the wall-clock delay entirely (a delay can only ever be too short, never too long). (`test/cache/drivers/file_store_test.dart`)
- **The registry dispatch fires on a published release now, not on every push that touches the skill.** Under the push trigger `fluttersdk/ai` climbed to v1.3.75, and most of those releases re-published identical skill content: a docs commit and a release commit each cost the registry a version. The registry version now tracks published magic releases instead of counting commits. `workflow_dispatch` stays as the manual escape hatch when a skill fix has to reach users before the next release. (`.github/workflows/dispatch-to-registry.yml`)
- **Every plugin install command in the `magic-framework` skill was unrunnable.** `plugin-notifications.md` said `dart run magic_notifications install`, `plugin-deeplink.md` said `dart run magic_deeplink install` / `generate`, and `plugin-starter.md` said `dart run magic_starter:install` and four siblings. None of those resolve: no plugin package declares an `executables:` entry or ships a `bin/` directory, and the real command names are `notifications:install`, `deeplink:install`, `deeplink:generate`, `starter:install`, `starter:configure`, `starter:doctor`, `starter:publish`, `starter:uninstall`, `social:install`. All of them now read `dart run magic:artisan <plugin>:<command>`, which reaches the plugin providers because `runArtisan` delegates to the consumer's dispatcher when one exists, and each file gained the `plugin:install <package>` step that registers the provider in the first place. (`skills/magic-framework/references/plugin-{notifications,deeplink,starter,social-auth}.md`)
- **New `references/plugin-devtools.md`.** `magic_devtools` was the one ecosystem plugin with no reference file: the skill named it in a table, pointed at a doc page in another repo, and described a call shape (`MagicDuskIntegration` / `MagicTelescopeIntegration` separately) that 0.0.2 replaced with the `MagicDevtools.installPre()` / `installPost()` umbrella. The new file covers both phases and why they straddle `Magic.init()`, the call-site `kDebugMode` rule that the release tree-shake depends on, the four import barrels, and the entire `MagicPreview` catalog (`PreviewEntry`, `MagicPreviewCatalog`, the `/preview` and `/preview/:component` routes, the provider-`boot()` registration window before the router locks, and the `kReleaseMode` + `PREVIEW_ENABLED` gate), which nothing in the skill mentioned. (`skills/magic-framework/references/plugin-devtools.md`, `SKILL.md`)
- **`plugin-starter.md` was four releases behind (alpha.14 against alpha.18).** It documented the loose `use*` setters as the only setup path and missed `MagicStarter.bootstrap()`, the identity contract that makes `userFactory` / `onLogout` / `locales` required and throws on a partial team-callback set. Also added: `SessionScopedController` + `SessionScopeSync` (the cross-tenant leak guard, with the clear-before-refetch rule), the `EnsureAuthenticated` / `RedirectIfAuthenticated` route guards, the plan upgrade wall (`PlanUpgradeRequirement.fromResponse`, `UpgradePrompt.show`, `MSUpgradeDialog`, `MSUpgradeNudge`), `settingsMaxWidthClassName`, and a note that the six `MagicStarter*` alias widgets are aliases of the canonical `MS*` names and disappear next release. (`skills/magic-framework/references/plugin-starter.md`)
- **`Magic.seed(List<Seeder>)` is documented.** `make:seeder` scaffolds a seeder and the skill never said how to run one; there is no `db:seed` command, seeders run from Dart after `Magic.init()`. (`skills/magic-framework/references/cli-commands.md`)
- The `magic:install` post-install message pinned `magic_devtools: ^0.0.1` and `fluttersdk_dusk: ^0.0.8`. Under Dart's caret rules for `0.0.x` both exclude the current releases (0.0.2 and 0.0.9), so a consumer copying the snippet resolved to superseded versions. It also still described the pre-umbrella four-block wiring. (`install.yaml`)
- `plugin-notifications.md` claimed version `v0.0.1-alpha.1`, a pre-release that never shipped, and documented none of the seven `notifications:*` commands or the two read-only MCP tools (`notifications_doctor`, `notifications_channels`). `plugin-social-auth.md` had no installation section at all. Both carry a version stamp now. (`skills/magic-framework/references/plugin-{notifications,social-auth}.md`)

- **`MagicController` exposes a static `onRefreshUI` hook, and every controller notification now goes through `refreshUI()`.** One nullable static at the single `notifyListeners()` call site lets debug tooling observe controller activity without magic depending on anything. The hook alone was not enough to make that true: `ValidatesRequests`, a mixin `on MagicController`, called `notifyListeners()` directly at five sites, so a controller setting validation errors repainted without the hook firing and a diagnostic built on it under-counted exactly the form-validation rebuilds it is most likely to be pointed at. Those five now call `refreshUI()`. The hook itself is contained rather than swallowed: it is set by tooling outside this package and runs BEFORE `notifyListeners()`, so an unguarded throw would stop the screen repainting for every later `setSuccess` and `setError` on that path. A broken observer costs its own numbers, never the app's frames. (`lib/src/http/magic_controller.dart`, `lib/src/concerns/validates_requests.dart`, `test/http/magic_controller_test.dart`, `skills/magic-framework/`)

### Removed

- **`magic:install --without-events` is gone: it was accepted and then ignored.** The flag was declared in the command signature, listed in `_withoutFlagNames`, and prompted for in `install.yaml`, so it reached the manifest as `withoutEvents` and stopped there. Nothing read it: the conditional-config map publishes six files (auth / database / network / cache / logging / broadcasting) and events has no config file, `_buildProviderEntries` never emits an `EventServiceProvider` line because magic registers the dispatcher in core, and no directory creation branches on it either. An install run with `--without-events` produced byte-identical output to one without it, while `doc/packages/magic-cli.md` promised it skipped `lib/app/events/` and `lib/app/listeners/`. Removing it is the honest fix: there is no events setup to skip. `--without-localization` is unaffected and still drops `LocalizationServiceProvider` from the generated providers list. (`lib/src/cli/commands/magic_install_command.dart`, `install.yaml`, `test/cli/commands/fixtures/install.yaml`, `doc/packages/magic-cli.md`, `doc/getting-started/installation.md`, `skills/magic-framework/references/cli-commands.md`)

## [0.0.6] - 2026-07-29

### Contributing checklist (before merging into `[Unreleased]`)

- [ ] CHANGELOG entry added under the appropriate bucket (BREAKING / Added / Changed / Removed / Fixed / Improvements)
- [ ] `doc/` updated when the change touches public-facing behavior
- [ ] `README.md` updated when the change touches the overview or quick-start
- [ ] `skills/magic-framework/` updated when the change touches APIs the skill documents
- [ ] `example/` updated when the change touches the canonical consumer scaffold
- [ ] `flutter test` green; `dart analyze` clean; `dart format` no diff; `dart pub publish --dry-run` no blocking errors

## [0.0.5] - 2026-07-26

### Added

- **`Model.save()` now exposes the backend's per-field 422 errors instead of discarding them.** `save()` returned only a `bool`, so a form that wrote through the ORM could tell that a remote save failed but not why, and every 422 collapsed into a generic "something went wrong" toast. A failed remote save now captures the Laravel validation shape (`{"message": ..., "errors": {"field": ["message"]}}`) into two new members on `InteractsWithPersistence`: `validationErrors` (`Map<String, List<String>>`) and `validationError(field)` (the first message for one field). The map is cleared at the start of every remote save, so it stays empty after a save that succeeded or carried no field errors, and it also stays empty when the remote leg throws (a transport failure), which is how a caller distinguishes a field-validation failure from a network failure: an empty map plus a `false` return means "render a generic error". It is deeply unmodifiable (both the map and each message list), and it tracks the REMOTE leg rather than `save()`'s return value, so a hybrid model (`useRemote` and `useLocal`) whose remote save 422s while its local write succeeds returns `true` with the errors filled. The `bool` return contract is unchanged, so this is purely additive for existing callers. Touches `lib/src/database/eloquent/concerns/interacts_with_persistence.dart`; covered by the `InteractsWithPersistence validation errors` group in `test/database/eloquent/model_test.dart`; documented in `doc/eloquent/getting-started.md` (Inserting & Updating -> Validation Errors) and `skills/magic-framework/references/forms-validation.md` (Server Error Mapping).

- **`MagicRouter` now re-runs its redirect chain when auth state changes, not only on navigation.** The router evaluated its guards (the `'auth'` / `'guest'` redirects) only while resolving a route, so a login or logout that happened while the user was already sitting on a page (a token expiry, a background sign-out, a successful login on the auth screen) did not move them off a now-forbidden route until the next manual navigation. The router now listens to the auth guard's state notifier and refreshes `routerConfig` on a change, so an auth transition re-evaluates redirects immediately (an expired session bounces to login; a login leaves the guest-only auth screen). Consumers with no bound `auth` guard are unaffected (the notifier is absent and the listener is a no-op). Touches `lib/src/routing/magic_router.dart`; covered by `test/routing/router_auth_refresh_test.dart`.

### Fixed

- **`LocalizationServiceProvider` now boots `DateManager`, so `localization.timezone` and `auto_detect_timezone` finally do something on their own.** Nothing in the framework ever called `DateManager.instance.boot()`, which meant the IANA database was never initialized, both timezone config keys were inert, and the `X-Timezone` header that `LocalizationInterceptor` sends on every request reported the unbooted default rather than the device's zone. Every consumer had to boot it by hand before `runApp`, and a consumer that did not know to do so shipped a wrong header silently. The provider now boots it as the first thing in `boot()`, symmetrically with how it already handles `auto_detect_locale`. Booting is idempotent and cannot fail startup (an unresolvable zone degrades to UTC). Touches `lib/src/localization/localization_service_provider.dart`; covered by `test/localization/localization_service_provider_boot_test.dart`.

- **`DateManager` no longer crashes application startup when it falls back to UTC.** `_setTimezoneInternal` resolved every zone through `tz.getLocation`, including its own UTC fallback, but the database loaded from `timezone/data/latest.dart` has NO entry named `UTC` (it ships `Etc/UTC`). So `getLocation('UTC')` threw, and because that call sat inside the `catch` block that was supposed to handle an unresolvable zone, the exception escaped `boot()` and took `Magic.init()` down with it. The same gap made `_isValidTimezone('UTC')` return false, so the documented default of `localization.timezone` was reported as invalid. Both paths now resolve through the package's const `tz.UTC` location, whose name is the canonical `'UTC'`, so an app that cannot detect a zone (or that simply keeps the default) boots and reports `UTC` instead of throwing. This was latent until detection stopped guessing: while `detectTimezone()` always returned a plausible city, the fallback was unreachable. Touches `lib/src/support/date_manager.dart`; covered by the `DateManager UTC resolution` group in `test/support/date_manager_timezone_test.dart`.

- **`MagicApplication` now follows `Lang.current` for runtime locale changes, eliminating the need for consumer workarounds.** When `Lang.setLocale` was called at runtime to change the app's language, the locale reverted on the next widget rebuild because `MaterialApp.locale` was wired to the static config value, not the live `Lang.current` state. Consumers had to hand-write a `ListenableBuilder` that listened to `Translator.instance` and passed `locale: Lang.current` down the tree to make language switching work. `MagicApplication` now binds `locale` to `Lang.current` directly, so runtime language switching works transparently, and consumers with the hand-written workaround can delete it. Explicit `locale:` arguments passed to `MagicApplication` still take precedence, and config stays authoritative while no runtime locale has been loaded (`Lang.isLoaded` false), so an app whose translator is bound but not yet booted keeps its configured locale instead of snapping to the translator's `en` default. The subscription is a `ListenableBuilder` on `Translator.instance` scoped inside `MagicAppWidget`, below `WindTheme`, which is the same scope `Magic.reload()` refreshes: rebuilding from `MagicApplication` itself would hand `WindTheme` a fresh `WindThemeData` on every locale change and put the live brightness toggle at stake. Touches `lib/src/foundation/magic_app_widget.dart`; covered by `test/foundation/magic_app_widget_locale_test.dart`; documented in `doc/digging-deeper/localization.md`.

- **`DateManager.detectTimezone()` now reads the real IANA timezone identifier instead of guessing from UTC offset.** The method first tried `DateTime.now().timeZoneName`, which returns an abbreviation like `+03` or `EET` on most platforms, then fell back to finding the first timezone-database location whose current UTC offset matched the device. An offset does not uniquely identify a zone; Istanbul and Kyiv share the same winter offset but differ in DST rules, so a device's timezone could be misidentified. Detection now uses the `flutter_timezone` package to read the real IANA identifier from the platform, and when no valid zone resolves, returns `null` and leaves the configured default in place instead of guessing. Consumers who worked around the issue by adding `flutter_timezone` as a dependency and manually calling a detection service before `runApp` can now remove that code. Detection stays opt-in through `localization.auto_detect_timezone` (default `false`), and the private offset-scanning helper `_findTimezoneByOffset` is deleted rather than left unreachable. Touches `lib/src/support/date_manager.dart` and `pubspec.yaml` (adds `flutter_timezone`); covered by `test/support/date_manager_timezone_test.dart`; documented in `doc/digging-deeper/localization.md` (Timezone Detection) and `doc/digging-deeper/carbon.md` (Timezone Support).

- **`MagicFeedback` toasts now show in Scaffold-less (Wind-only) views instead of throwing or silently doing nothing.** `Magic.error` / `Magic.success` / `MagicFeedback.info` routed through `ScaffoldMessenger.of(context).showSnackBar`, which asserts `_scaffolds.isNotEmpty` when no Material `Scaffold` hosts the view. In a Wind-built screen (no `Scaffold`) that assertion escaped the caller's own `try/catch` and stalled the flow. Toast delivery now goes through the Navigator overlay, read from `navigatorKey.currentState.overlay` (NOT `Overlay.maybeOf`, which sits above that overlay), as a single non-interactive auto-dismissing bottom entry that replaces the previous one and degrades to a logged warning when no overlay is available (never throwing). The `Magic.error` / `success` / `toast` API surface is unchanged; only the delivery path is. Touches `lib/src/ui/magic_feedback.dart`; covered by `test/ui/magic_feedback_test.dart`.
- **`MagicFeedback` overlay toasts render clean text and degrade without throwing.** The overlay toast content was not wrapped in a `Material`, so its text inherited the root fallback `DefaultTextStyle` (the yellow debug double-underline); it now sits under a transparent `Material`, matching the dialog / loading builders. The unused `backgroundColor` / `color` parameters on `showSnackbar` (the overlay path never applied them) are removed, and the degrade-path warnings now log through `Log` only when the `log` service is bound (falling back to `debugPrint`), so feedback triggered before `Magic.init` binds logging degrades instead of throwing `Service [log] is not registered`. Touches `lib/src/ui/magic_feedback.dart`; covered by `test/ui/magic_feedback_test.dart`.
- **`TitleManager` treats a blank title suffix as absent.** A `null` suffix was already skipped, but an empty or whitespace suffix (e.g. an unset `APP_NAME` resolving to `""`) still produced `"Route | "` with a trailing separator and an empty tail. A blank suffix is now treated as absent (via `_withSuffix`), so the browser tab shows just the route title. Touches `lib/src/routing/title_manager.dart`; covered by `test/routing/title_manager_test.dart`.

## [0.0.4] - 2026-07-08

### Added

- **`design:sync` + `design:lint` commands make DESIGN.md the single source of truth for the app theme.** Two new commands join `MagicArtisanProvider`. `design:sync` parses a `DESIGN.md` (YAML front matter: color roles with a single-file `dark:` overlay, typography, `rounded`, `spacing`, and `components` carrying `{colors.x}` / `{rounded.x}` / `{spacing.x}` references; the markdown body is ignored), resolves the references against a dotted-path symbol table with a cycle guard, and emits a wind theme source file (`--output`, default `lib/config/wind_theme.g.dart`). The generated file exposes `Map<String, String> designAliases` carrying the 17 property-prefixed semantic keys (`bg-surface`, `text-fg`, `border-color-border`, ...) with arbitrary-hex light + `dark:` pairs (`'bg-surface': 'bg-[#f9f9ff] dark:bg-[#0f1419]'`), drop-in for `WindThemeData(aliases: ...)` and matching the `MagicStarterTokens.defaultAliases` contract, plus a brand `primary` `MaterialColor` with a generated 50-900 ramp (seeded from the DESIGN.md `primary` light hex) for `WindThemeData.toThemeData()` Material interop. It writes atomically via `.tmp` + rename and is idempotent (byte-identical output on re-run for an unchanged DESIGN.md). `design:lint` validates a DESIGN.md against six rules ported from the open design.md reference linter and adapted to the wind-flavored superset: broken-ref (error), missing-primary (warning), unknown-key (warning; the `dark:` overlay lives inside `colors` and is structurally never a top-level key, so it is never flagged), section-order (warning), missing-sections (info), orphaned-tokens (warning, with Material Design 3 baseline families exempt), and contrast-ratio (warning; a greenfield WCAG relative-luminance helper does sRGB channel linearization + the 4.5:1 ratio check on each component `backgroundColor` / `textColor` pair). The Tailwind/DTCG export-conformance and rem-based spacing/rounded rules from the reference linter are intentionally dropped (wind uses 4px logical spacing and arbitrary-hex aliases). The command exits nonzero only on an error-severity finding. Touches `lib/src/cli/commands/design_sync_command.dart`, `lib/src/cli/commands/design_lint_command.dart`, `lib/src/cli/helpers/design_md_parser.dart`, `lib/src/cli/magic_artisan_provider.dart`; adds `test/cli/commands/{design_sync,design_lint}_command_test.dart` + `test/cli/helpers/design_md_parser_test.dart`; documented in `doc/packages/magic-cli.md` (including the DESIGN.md format page).
- **`previews:refresh` + `make:component` codegen commands for the design-first preview catalog.** Two new commands join `MagicArtisanProvider`. `previews:refresh` scans a configurable target directory (`--path`, default `lib`) for `*.preview.dart` files, extracts the single public `*Preview` class from each via regex (the private `_*State` companion of a stateful preview is ignored), validates the class name is a clean PascalCase identifier before interpolation, fails fast on a slug collision, sorts deterministically, and renders `<scan-dir>/_previews.g.dart` through an atomic `.tmp` + rename. The generated file returns a freshly-built `List<PreviewEntry>` from the `previewEntries()` FUNCTION (never a top-level const list) so the dev-only catalog tree-shakes from release builds (dart-lang/sdk#33920); it imports `PreviewEntry` from `package:magic_devtools/preview.dart` and each preview widget by its path relative to the generated file (preview files are not exported from any barrel). Re-running the command produces a byte-identical file. `make:component <Name> [--variants=intent,size] [--slots]` extends `ArtisanGeneratorCommand` and scaffolds the canonical 4-file atomic component folder under `lib/ui/components/<name>/` (`<name>.dart`, `<name>.recipe.dart`, `<name>.preview.dart`, `index.dart`): the class is unprefixed PascalCase, the recipe is seeded with the requested variant axes (or a `WindSlotRecipe` shape under `--slots`), the index re-exports the component + recipe but not the preview, then the command chains `previews:refresh` so the new preview lands in `_previews.g.dart`. Touches `lib/src/cli/commands/previews_refresh_command.dart`, `lib/src/cli/commands/make_component_command.dart`, `lib/src/cli/helpers/previews_index_writer.dart`, `lib/src/cli/helpers/magic_stub_loader.dart` (adds `loadFrom`), `lib/src/cli/magic_artisan_provider.dart`, and six stubs under `assets/stubs/`; adds `test/cli/commands/{previews_refresh,make_component}_command_test.dart`.
- **`magic:install --with-devtools` wires the debug trio in one step.** Installing the optional debug tooling (`magic_devtools` + `fluttersdk_dusk` + `fluttersdk_telescope`) previously meant a manual multi-step bootstrap: add three deps, run `plugin:install` twice, then `dusk:install` + `telescope:install`. The new `--with-devtools` flag does all of it after the core install: it adds the three packages to `dependencies` (regular, not `dev_dependencies`, because `lib/main.dart` imports them and the `kDebugMode` gate tree-shakes the subsystem from release builds, so `dev_dependencies` would trip `depend_on_referenced_packages`) and wires `lib/main.dart` under `kDebugMode` exactly as `dusk:install` / `telescope:install` do: `DuskPlugin.install()` and `TelescopePlugin.install()` (plus `ExceptionWatcher` + `DumpWatcher`) before `Magic.init()`, then `MagicDuskIntegration.install()` and `MagicTelescopeIntegration.install()` after it. The wiring is a pure-functional, idempotent transform (`buildDevtoolsWiring`) over the generated main.dart, and the dep-add rides the same `installer.addDependency` mechanism the install already uses, so re-running `magic:install --with-devtools` never duplicates a wiring block or a dependency entry. The injected package imports are placed within the existing package-import group (before the relative `config/...` imports, with `package:flutter/foundation.dart` ordered before `package:flutter/material.dart`), so the generated main.dart stays `directives_ordering`-clean and a freshly installed app emits no analyzer warnings. Absent the flag, nothing changes for the existing install path. Touches `lib/src/cli/commands/magic_install_command.dart`; adds the `MagicInstallCommand.buildDevtoolsWiring` test group plus a real-FS full-install group to `test/cli/commands/magic_install_command_test.dart`.
- **`MagicMiddleware.redirectTarget(String location)` for pre-build redirect guards.** Redirect-style guards (auth / guest) can now return a redirect target synchronously, evaluated inside the router's `redirect` callback BEFORE any page builds. Previously the only way to redirect was an imperative `MagicRoute.to()` inside `handle()`, which runs post-mount and remounts the destination view, recreating its form state on every mount (the login-double-mount bug). `_handleRedirect` now evaluates every matched route's global + route middleware `redirectTarget` and returns the first non-null target. The default returns `null`, and `handle()` now defaults to `next()`, so a redirect-only guard overrides just `redirectTarget`. Fully backward compatible: existing `handle()`-based guards keep working. Touches `lib/src/http/middleware/magic_middleware.dart`, `lib/src/routing/magic_router.dart`; adds `test/routing/redirect_guard_mount_test.dart` (asserts the destination mounts exactly once, including through a layout ShellRoute).

### Fixed

- **`Pick.saveFile` is source-compatible with file_picker 12.** file_picker 12 made `FilePicker.saveFile`'s `fileName` and `bytes` parameters required and non-null, which broke the analyzer build (`argument_type_not_assignable`) under a fresh `flutter pub get` that resolved the newer file_picker. `Pick.saveFile` keeps its nullable facade surface but now guards both arguments before forwarding, so the call type-checks against file_picker 11 and 12 and a null argument fails with a clear `ArgumentError` instead of an unhelpful type error. Touches `lib/src/facades/pick.dart`.
- **`file_picker` constraint tightened to exclude the 12.0.0 prerelease line.** The constraint is now `>=11.0.2 <12.0.0-0` to lock the 11.x stable releases and exclude every `12.0.0-*` prerelease. A `<12.0.0` bound would NOT have been enough: pub_semver orders prereleases below the stable release (`12.0.0-beta < 12.0.0`), so `12.0.0-beta` still satisfied it; the `-0` suffix is the lowest possible prerelease and excludes the entire `12.0.0` line. This pairs with the `Pick.saveFile` source-compatibility guard above as defense in depth. Touches `pubspec.yaml`.
- **`Crypt` now accepts the `base64:` app key that `key:generate` produces.** `key:generate` writes `APP_KEY=base64:<base64 of 32 random bytes>`, but `EncryptionServiceProvider` required `app.key` to be a raw 32-character string and threw `App Key must be 32 characters for AES-256` on the generated key, so `Crypt.encrypt`/`decrypt` were unusable out of the box. Added `MagicEncrypter.fromAppKey(appKey)` which base64-decodes a `base64:`-prefixed key to its 32 bytes (and still accepts a raw 32-character key); `EncryptionServiceProvider` now binds through it. Touches `lib/src/encryption/magic_encrypter.dart`, `lib/src/encryption/encryption_service_provider.dart`; adds three `fromAppKey` cases to `test/encryption/magic_encrypter_test.dart`.
- **`MagicStatefulView` now calls the controller's `onInit()` lifecycle hook.** `MagicStatefulViewState.initState` listened to the controller and called the VIEW's own `onInit()` hook, but never invoked the CONTROLLER's `onInit()`, despite the documented contract. A controller that bootstraps in `onInit` (initial data load, table creation, subscriptions) silently never ran it when backed by a `MagicStatefulView`, so the screen rendered against uninitialized state (e.g. a query against a table the controller's `onInit` was supposed to create). It now calls `_controller.onInit()` guarded by `MagicController.initialized`, so a `SimpleMagicController` that already initialized in its constructor is not double-initialized and a singleton controller reused across re-mounts initializes exactly once per lifetime. Touches `lib/src/ui/magic_view.dart`; adds `test/ui/magic_view_controller_oninit_test.dart`.
- **Auth no longer warns on every boot of a fresh app.** `AuthServiceProvider.boot()` logged a `userFactory not registered` warning (blaming provider order) whenever no userFactory was set, even for apps with no stored session to restore. It now only warns when a stored session actually exists (`Auth.hasToken()`) but cannot be rebuilt; a fresh app or a logged-out user stays quiet (debug-level). The stored-session check is guarded so a misconfigured Auth (for example, no Vault registered) cannot crash boot from this warning-verbosity path. Touches `lib/src/auth/auth_service_provider.dart`; adds three cases to `test/auth/auth_test.dart`.

### Changed

- **`fluttersdk_wind` constraint bumped to `^1.2.0`.** Requires wind 1.2.0's `WindRecipe`/`WindSlotRecipe` (the `tv()`-equivalent recipe API, NEW in 1.2.0 and re-exported by `package:magic/magic.dart` — the design-first component layer and `make:component` scaffolds depend on it), plus the intrinsic-safe flex, the seeded `primary` token, the min-width-stretch scroll, and the `h-full`-inside-vertical-scroll dev assert. Also picks up wind 1.1.0's Material-free `WInput`/`WText` rewrite, 1.1.1's two fixes that magic's W-widget UI depends on (`WInput` native text selection restored (mouse drag-select, double-tap word, long-press), and `WText` now inherits an ancestor `DefaultTextStyle` color (the CSS text-color cascade) before falling back to the OS-brightness baseline; the latter fixes invisible labels on magic's W-rendered surfaces (`Magic*View`, `MagicFeedback`, dialog buttons whose color lives on the container) when the app theme disagrees with the OS theme), and 1.1.2's `WPopover` fix: a popover with an interactive trigger (a `WButton`/`WAnchor` with its own `onTap`) now opens reliably and no longer dismisses itself on the opening gesture, with the trigger kept accessible via a `Semantics` tap action. This is the primitive behind magic_starter's team selector and user/notification dropdowns. Touches `pubspec.yaml`.
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
