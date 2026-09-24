# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

- **`Carbon.setTestNow([testNow])` and `Carbon.hasTestNow()`, Laravel's frozen-clock testing helper.** `Carbon.now([timezone])` returns the frozen instant while one is set (timezone conversion still applies on top of it), and `Carbon.setTestNow()` with no argument (or `null`) clears the freeze. A test that seeds an app's clock now has a Laravel-parity seam instead of threading a fake `DateTime` through every call site. (`lib/src/support/carbon.dart`, `doc/digging-deeper/carbon.md`, `skills/magic-framework/`)

## [0.0.21] - 2026-09-24

### Added

- **`MagicApplication.builder`, a layer above the router that survives every navigation.** It is passed straight to `MaterialApp.router(builder:)`, so it wraps the `Router` inside the app's `Theme`, localizations, `Directionality` and `MediaQuery`, and above the root `Navigator`. A layout cannot do this job, since it belongs to its routes and a `to()` to an unstacked route outside the group disposes it; there was no seam short of abandoning `MagicApplication`. The case that forced it is a floating video player whose platform view must never be remounted while the viewer moves between pages: its State now survives every `to()`, push and `back()`. From the layer's own context `Navigator.of` and `Overlay.of` find nothing, so it navigates through `MagicRoute`, opens dialogs with `Magic.dialog()`, and needs an `Overlay` of its own around any `Tooltip`, `WPopover` or `WSelect`. A soft restart is not a navigation: `Magic.reload()`, which `Lang.setLocale()` calls unless passed `reload: false`, remounts the layer with everything else. The loading and failure screens shown before initialization are left unwrapped, and a null `builder` changes nothing. (`lib/src/foundation/magic_app_widget.dart`, `doc/basics/routing.md`, `skills/magic-framework/`)

## [0.0.20] - 2026-09-23

### Changed

- **The `fluttersdk_wind` floor moves `^1.6.3` to `^1.6.4`.** The old range already admitted 1.6.4, so a fresh `pub get` resolves nothing differently; what changes is that the floor names the release this package is verified against. 1.6.4 clips a rounded, bordered `overflow-hidden` box inside its border, so a child that fills the box no longer paints over the border's corners, and the box's shadow shows again. (`pubspec.yaml`, `CLAUDE.md`)

- **`magic:install --with-devtools` writes `fluttersdk_dusk: ^0.0.16`, up from `^0.0.15`.** dusk 0.0.16 stops `dusk:fill`, `dusk:type` and `dusk:clear` from writing into a field on a route the visible one covers. The installer's constraint map, `install.yaml`'s post-install message (held together by a parity test), `doc/packages/magic-devtools.md` and the skill's devtools page move together; `magic_devtools` stays `^0.0.6`, whose own `^0.0.15` admits 0.0.16. (`lib/src/cli/commands/magic_install_command.dart`, `install.yaml`, `doc/packages/magic-devtools.md`, `skills/magic-framework/references/plugin-devtools.md`)

- **On the web, every push now reports the pushed page's address, not only a stacked `to()`.** The flag below is go_router's, and it covers every imperative push: `MagicRoute.push()`, `replace()` over a pushed page, and a go_router `context.push` in app code all move the address bar now, where they used to leave the page beneath's. A reload of such an address arrives with only the path, so a page pushed with go_router's `extra` receives none, and the page that was underneath is not there for `back()` without a `fallback`. (`lib/src/routing/magic_router.dart`, `doc/basics/routing.md`) (#185)

### Fixed

- **A `stacked()` route owns the browser's address on the web.** `to()` pushes a stacked route, and go_router reports a push under the address of the page beneath it unless `GoRouter.optionURLReflectsImperativeAPIs` is on, so opening a detail screen left the address bar on the list and the page could not be copied, shared or reloaded. The router now sets the flag when it is built. go_router discourages it because a pushed URL is not always deep-linkable; every Magic route is a full path the router matches on its own, so the reported address always matches a route. Web only. `MagicRouter.reset()` puts the flag back to go_router's default, since it is a static that outlives the router. (`lib/src/routing/magic_router.dart`, `doc/basics/routing.md`, `skills/magic-framework/`) (#185)

## [0.0.19] - 2026-09-23

### Fixed

- **A boot sync answering 401 during a sign-in no longer deletes the token the sign-in just wrote.** 0.0.18's `startSession` and `storeToken` wrote both tokens to the Vault before the in-memory token moved. A 401 about the restored token landing between those writes saw an unchanged token and an unchanged session, so the sync logged out: `clearTokens()` deleted the new token, the sign-in then set its user, and the app looked signed in with nothing in the Vault, a guest again on the next cold start. The same window existed on the refresh path. A session opening or ending is now visible to an in-flight sync from its first line: `startSession` and `logout()` move a private session epoch before any await and the sync ignores its answer once it has moved, and `storeToken` moves the in-memory token before its writes, so a refusal arriving mid-refresh is re-checked under the new token rather than read as a verdict on it. When the access-token write throws (a locked keychain, a missing entitlement), the in-memory token goes back to what it was before the failure propagates, so a token that was never stored does not ride on later requests; a failed refresh-token write keeps the new access token, which is already on disk. The epoch also closes #191: a sync 200 landing inside `logout()`'s Vault deletes is no longer applied to the ending session, and one whose own cache write a sign-out overtook neither dispatches `AuthRestored` nor leaves the user cached on disk. (`lib/src/auth/guards/base_guard.dart`, `doc/security/authentication.md`, `skills/magic-framework/`)

## [0.0.18] - 2026-09-23

### Added

- **`BaseGuard.startSession(user, token:, refreshToken:)`** persists the tokens, then sets the in-memory token and the user in one synchronous step, then caches the user. The three built-in guards' `login()` use it, and a custom guard should too, in place of `storeToken` followed by `setUser`: between those two calls the guard held the new token under the previous account, and a boot sync answering in that window applied the previous account and dispatched `AuthRestored` for it. `storeToken` now also persists the refresh token before the in-memory token moves. (`lib/src/auth/guards/`, `doc/security/authentication.md`, `skills/magic-framework/`)

### Changed

- **Since 0.0.17, a guard that does not extend `BaseGuard` is logged out on a 401 only when the request carried the header `auth.token.header` names.** Before 0.0.17 every 401 ran the refresh-or-logout ladder whatever the request carried. A guard outside `BaseGuard` keeps no token the interceptor can compare against, so it is now judged on presence alone, and a cookie-based guard, or one that sends its credential under a different header, stays signed in while its calls return 401. Such a guard has to end its own session. This entry is late: 0.0.17 described the fix but did not list it as a behaviour change. (`lib/src/auth/auth_interceptor.dart`, `doc/security/authentication.md`, `skills/magic-framework/`)

### Fixed

- **A sign-in made while the boot-time user sync is in flight is no longer undone by it.** `restore()` sets the cached user and fires the `/user` sync unawaited with the token restored at boot. When the viewer signed in before that sync answered, a 401 about the OLD token made `_syncUserFromApi` call `logout()` itself, and `clearTokens()` deleted the token the sign-in had just stored: the new session was silently gone, even though 0.0.17's interceptor had correctly ignored the same 401. The mirror case was just as wrong: a late 200 ran `setUser` and `cacheUser` with the previous account while the guard held the new account's token, and a late 200 after a sign-out put the user back. The sync now ignores its answer when a sign-in or a sign-out happened while it was in the air (both bump `stateNotifier`), and a 401 or 403 under a token that has since been replaced is re-checked once under the current token, whose answer decides. A refresh is neither: it keeps the account, so a 200 under a rotated token is still applied, which is what signs in a cold start whose expired token the interceptor refreshed while retrying the sync itself; if the server refuses the refreshed token too, the re-check ends the session, as 0.0.17 did. (`lib/src/auth/guards/base_guard.dart`, `doc/security/authentication.md`, `skills/magic-framework/`)

- **An upload retried after a token refresh sends its body again.** `Http.upload` posts a Dio `FormData`, which is single use: the retry re-sent the same instance, Dio threw on the second `finalize()`, the retry swallowed it, and the caller got the 401 back for an upload the refreshed token would have carried. The retry now sends a clone. (`lib/src/auth/auth_interceptor.dart`)

- **A retry that yields nothing hands back the refused request as it was sent.** The retry rewrote the refused request's own header map, so the error returned when it failed advertised a token that request never carried. It now builds a copy. (`lib/src/auth/auth_interceptor.dart`)

### Improvements

- **The interceptor's 401 handling is now exercised on a real socket.** Every earlier interceptor test ran against `Http.fake()`, whose `addInterceptor` is a no-op, so the reasoning about Dio's header map and the error it hands back was never tested. A loopback suite puts a real `DioNetworkDriver` and `AuthInterceptor` in front of a local `HttpServer` and covers a 401 on the current token, one on a token replaced mid-flight (the session is kept, and the request is handed back refused rather than replayed, since a rotation and a different account signing in look the same from the interceptor), an anonymous request, and an upload retried after a refresh. (`test/auth/auth_interceptor_loopback_test.dart`)

## [0.0.17] - 2026-09-23

### Fixed

- **A 401 no longer ends the session when the refused request carried no credential.** `AuthInterceptor.onError` treated every 401 as a verdict on the stored token, so a request that went out with no auth header at all still ran the refresh-or-logout ladder. On an app with no refresh endpoint that ladder is a straight logout.

  That is not a hypothetical ordering. Measured in a browser: an app opens a guest session on launch without awaiting it, and a second call made during the same bootstrap is dispatched BEFORE the login returns, so it carries no header. Its 401 comes back AFTER `Auth.login` has already stored the token and set the user, and the interceptor then logged out the session that had just been opened. Every account-backed feature was dead for the rest of the process, the app looked signed out with a valid token on the server, and nothing said so: the interceptor's own `Log.warning` is the only trace and it is not an error.

  The interceptor now asks whether the request presented the header `auth.token.header` names before it concludes anything, matching the name without regard to case: header names are case-insensitive, and Dio keeps the casing of a key's first insertion, so a caller that passed `authorization` itself still owns that key after the interceptor writes into it. A 401 on a request the server was never shown a credential for says nothing about the credential the guard now holds, and neither does one on a request that carried an OLDER token: against a `BaseGuard` the presented value has to be the one the interceptor would attach now, so a refusal of the token restored at boot that lands after a sign-in stored a new one no longer ends the new session. A guard that keeps no token of its own is judged on presence alone. This is the sibling of the rule `BaseGuard._syncUserFromApi` already applies to a transport failure: only the server may end a session, and only about a credential it actually saw. A token the server really did reject still ends the session, exactly as before, and the retry after a successful refresh now drops a differently cased copy of the header before writing the new token, so it no longer carries the refused token beside the fresh one. (`lib/src/auth/auth_interceptor.dart`, `doc/security/authentication.md`, `skills/magic-framework/`)

## [0.0.16] - 2026-09-22

### Changed

- **`file_picker` widens from `^12.2.0` to `>=12.2.0 <14.0.0`, so a fresh `pub get` resolves 13.** v13 removes the parameters v12 deprecated in its federated rewrite (`allowMultiple`, `withData`, `withReadStream`, `readSequential`, `lockParentWindow`, `cancelUploadOnWindowBlur`, `androidSafOptions`), and `Pick` passes none of them. The one change a consumer can see is `PlatformFile.length()`, now `Future<int?>`: a file whose size cannot be read answers null on 13 where 12 answered 0. `MagicFile.size` was already nullable, so nothing stops compiling; the size warnings on `MagicFile.size` and `Pick`'s converter now name both answers, and an upload-limit guard should treat null and 0 alike as unknown. Keeping 12 in the range leaves an app that pins it directly resolvable. (`pubspec.yaml`, `lib/src/storage/magic_file.dart`, `lib/src/facades/pick.dart`) (#181)

- **The `fluttersdk_wind` floor moves `^1.6.2` to `^1.6.3`.** The old range already admitted 1.6.3, so a fresh `pub get` resolves nothing differently; what changes is that the floor names the release this package is verified against. 1.6.3 makes `bg-transparent` and the other `*-transparent` tokens resolve for the first time, so a className that carried one as dead weight now paints it, and a checked `WCheckbox` sheds its outline. (`pubspec.yaml`, `CLAUDE.md`)

- **`magic:install --with-devtools` writes this batch's releases:** `magic_devtools ^0.0.6` and `fluttersdk_telescope ^0.0.7`, with `fluttersdk_dusk ^0.0.15` unchanged. The installer map, the post-install message and the package doc move together, and the install test fails when the first two disagree. (`lib/src/cli/commands/magic_install_command.dart`, `install.yaml`, `doc/packages/magic-devtools.md`)

- **The skill's plugin reference pages name this batch's releases**, and the starter page covers what magic_starter 0.0.32 to 0.0.34 changed for an adopter: the compact rail, the content area's `contentClassName` and `contentScrollPrimary`, the collapsible sidebar with its two translation keys, the centred compact brand, and the guest entries `RedirectIfAuthenticated` now lets through. Stamps: magic_notifications v0.3.4, magic_deeplink v0.1.3, magic_social_auth v0.0.5, magic_payments v0.0.4, magic_devtools v0.0.6, magic_starter v0.0.35; the floor prose in the notifications, devtools, payments and starter pages moves with them. (`skills/magic-framework/`) (#179, #180, #182, #183)

## [0.0.15] - 2026-09-21

### Breaking

- **A migration may no longer manage its own transaction.** `DB.beginTransaction`, `commit` and `rollback` are a documented pattern elsewhere, so a migration written that way was legitimate before this. A `commit()` inside `up()` closes the migrator's savepoint, which meant every later migration ran unprotected and the closing `RELEASE` threw AFTER every migration had succeeded and committed its ledger row: the caller saw a failure from a run that fully worked, and the retry found nothing pending. `run` detects it and throws naming the migration that broke the contract, rather than failing late and confusingly. That case is the one exception to "all of them, or none": the offending migration's statements and every earlier ledger row are already committed by the time the guard sees anything. (See the `Migrator.run` entry under Fixed for the atomic run this protects.)

- **`DB.transaction` answers a callback that closes the transaction itself, instead of failing confusingly or quietly.** The two branches differ on purpose.

  On failure the rollback is skipped. There is a real error in flight and the only thing that matters is that it reaches the caller: `rollback()` would find nothing to unwind and throw `cannot rollback - no transaction is active` over the top, so the caller read a message about transactions in place of the cause.

  On success it now throws, naming what happened. Skipping the commit the same way would be the worse bug: there is no error to protect on that branch, so silence buys nothing and costs the signal. A callback that commits half way and keeps writing ran everything after that point outside any transaction, and returning normally tells the caller the block was atomic when it was not.

### Added

- **A `Url` validation rule.** Laravel has `url`; this package did not, so every consumer validating a typed-in endpoint wrote the same `startsWith('http://')` pair by hand and each drew its own conclusion about a scheme it had not thought of.

  ```dart
  'website': [Required(), Url()],                    // http or https
  'webhook': [Required(), Url(schemes: ['https'])],  // https only
  ```

  It checks a scheme from its allowlist and a non-empty host, and nothing else: it reaches no network and resolves no host, because a rule answering a form field synchronously cannot know any of that. **The allowlist is the security-shaped half**: `Uri.parse` accepts `javascript:alert(1)` and `file:///etc/passwd` without complaint, both have a scheme and both parse cleanly. Whitespace is rejected before parsing, because `Uri.tryParse('http://exa mple.com')` succeeds and percent-encodes the space into the host; Laravel's `url` rejects that too.

- **A `messages` override on `FormValidator.rules`,** Laravel's third `Validator::make` argument. A rule's message came from its own key and nothing else, so a screen wanting `Şifre gerekli.` rather than the catalogue's generic `:attribute alanı zorunludur.` had to abandon the rules and hand-roll a closure, which is what the rules exist to prevent.

  ```dart
  FormValidator.rules(
    [Required(), Url()],
    field: 'address',
    messages: {'required': 'provider.error.address_required'},
  )
  ```

  The value is a KEY rather than a finished sentence: an override taking a sentence would make every consumer using it monolingual. Rule parameters still reach it, so `:attribute` and `:schemes` work in an override.

  Keyed by the new `Rule.name`, which is derived from the rule's message key (`validation.required` gives `required`) rather than from `runtimeType`. That choice is load-bearing: `runtimeType.toString()` is not a dependable identifier in a release build, so a messages map keyed on it would match in development and silently stop matching in production. dart2js minifies class names (`js_helper.dart:107` has a `MINIFIED` branch for reporting them), and Flutter's own framework declines to use it outside asserts for the same reason (`foundation/object.dart`, `objectRuntimeType`).

- **`Rule` has a const constructor, and `Required`, `Email`, `Accepted` and `Url` declare one.** Additive; a rule with its own non-const constructor is unaffected. A stateless rule is written inline in a widget's `build`, where a const instance is one allocation that never happens again.

- **`transChoice()` / `Lang.choice()`, the pluralization Laravel calls `trans_choice`.** A sentence carrying a number had one wording at every count, because `Lang.get` is a map lookup plus a `replaceAll` per parameter and nothing parsed a pipe.

  What makes that worth a release rather than a nice-to-have is which apps it bites. Turkish, Japanese, Korean, Chinese, Indonesian, Vietnamese and nine more have no plural agreement after a number, so a catalogue written in one of them renders correctly at every count and reveals nothing. The defect appears the first time a SECOND locale is drawn, by which point every counted sentence in the app has been written without a plural form. Found exactly that way in a consumer app whose first locale is Turkish: its English build said "No schedule for 1 channels".

  ```json
  {
    "apples": "There is one apple|There are :count apples",
    "inbox": "{0} Nothing here|[1,19] :count messages|[20,*] Lots of messages"
  }
  ```

  ```dart
  transChoice('apples', 1);  // "There is one apple"
  transChoice('apples', 4);  // "There are 4 apples"
  transChoice('inbox', 0);   // "Nothing here"
  ```

  `:count` is substituted from the number without the caller passing it, and an explicit `count` in `replace` still wins. A key with no sentence answers the key, which is `get`'s own contract.

- **`MessageSelector`, exported.** A direct port of Laravel's `Illuminate\Translation\MessageSelector`, so a catalogue written for a Laravel backend renders the same sentences on the client. Both shapes are supported and compose in one line: positional segments, and inline `{0}` / `[1,19]` / `[20,*]` conditions.

  The 15 plural-rule groups covering 280 locale strings are ported from Laravel's `getPluralIndex` **mechanically**, by reading the PHP rather than transcribing it: one mistyped language code is a language that silently renders the wrong sentence, and nothing downstream would catch it. The rules themselves carry Laravel's own Zend Framework attribution.

  The index is the CURRENT locale's, never English's. A two-segment line in a language with one form never reaches its second segment, and one in Russian or Arabic falls back to segment 0 rather than throwing a `RangeError` into a consumer's UI.

### Changed

- **`flutter_secure_storage` widens from `^10.0.0` to `>=10.0.0 <12.0.0`, so a fresh `pub get` resolves 11.** v11 removes what v10 deprecated (on Android the `encryptedSharedPreferences` and `sharedPreferencesName` options, the PKCS1 key cipher and the CBC storage cipher), and `MagicVaultService` passes none of them. Its warning that data written with a deprecated cipher becomes unreadable is for an app that skipped v10: every magic release on pub.dev has required `^10`, so a vault written through magic is already on the v10 ciphers. v11 also raises the Android `minSdk` to 24, which every Flutter release since 3.35 already requires; magic's floor is 3.41. Keeping 10 in the range leaves an app that pins it directly resolvable. (`pubspec.yaml`)

- **`magic:install --with-devtools` writes the constraints its own post-install message documents.** The installer pinned `magic_devtools ^0.0.1`, `fluttersdk_dusk ^0.0.8` and `fluttersdk_telescope ^0.0.4` into the consumer's pubspec while the message printed beside it said `^0.0.2`, `^0.0.9` and `^0.0.4`. Both now name this batch's releases, `^0.0.5`, `^0.0.15` and `^0.0.6`, and the install test reads the message and fails when the two disagree, so a release cannot move one copy without the other. The old carets already admitted the new releases; what changes is that a fresh install names the ones it is verified against. (`lib/src/cli/commands/magic_install_command.dart`, `install.yaml`, `doc/packages/magic-devtools.md`)

### Fixed

- **`Migrator.run` was not atomic, and the state that produced is a host that never boots again.** It applied and recorded each migration in turn with no transaction anywhere, so a failure part way left that migration's earlier statements applied and its ledger row absent. The next launch re-ran it from its first statement, met the table it had already created, and failed identically. A host that migrates inside `Magic.init` before `runApp` has no UI to report that from, and the only repair is deleting the database.

  The whole run is one transaction now, not each migration: a ledger recording one migration and not the next describes a schema nobody designed, and the host cannot learn which half it has. SQLite rolls DDL back like anything else, so this is one `BEGIN`.

  **A `SAVEPOINT` rather than a `BEGIN`**, which is what lets it nest inside a transaction the host opened itself. Verified in all three shapes: with no transaction open, inside one, and unwinding through `ROLLBACK TO`.

  The tracking table is created before the savepoint, so a run that owns its transaction and fails still leaves somewhere to record the retry. A host that wrapped the call itself and rolls back takes the table with it, which is harmless because every entry point creates it again. The schema cache is cleared on the rollback path too, so nothing cached during an undone migration survives to describe schema that no longer exists.

- **Every migration could be applied and silently never recorded.** `_ensureMigrationsTable` creates the ledger with a raw `execute`, which `DatabaseManager` never hears about, and `getColumns` caches the EMPTY answer a missing table gives. `_recordMigration` goes through `QueryBuilder`, which filters every key against that cache, and an empty filter makes `insert` return 0 without inserting and without throwing. So anything that read the ledger's columns before it existed left every migration re-running on every launch for ever. One `clearSchemaCache` after the create. Latent rather than observed: no caller in the wild was found reaching it.

- **`Migration.up()` and `down()` are documented as synchronous**, because `void up() async` compiles and is a silent defect: `run` cannot await a `void`, so an async body is recorded complete the moment it reaches its first suspension. The doc block names the synchronous alternatives and says why `DatabaseManager().hasColumn` must not be called from a migration.

- **A translation catalogue loaded nothing, silently, whenever no `log` service was bound.** `JsonAssetLoader._loadJson` opened with `Log.info('Loading translation file [...]')` before it read anything, and `Log` resolves `log` through the container, which throws for an unbound key (`foundation/application.dart:269-274`). `load`'s own catch then turned that throw into an empty map, so every key rendered as itself with nothing anywhere to read.

  Reported from a consumer app whose test suite could not assert a single translated sentence. Measured there: `rootBundle` reads the asset fine (19,345 bytes), `Translator.load` reports `loaded: true` for the right locale, and the loader still answers zero keys.

  `Translator._loadFallbackFor` had already conceded the point one caller up, where the same `Log` call is wrapped in `if (Magic.bound('log'))` with a comment naming this exact case: "a widget test that builds `MaterialApp` through `LangDelegate` without a full `Magic.init()`". The loader had no such guard.

  The line is removed rather than guarded. A loader that reads a file should not need a service to do it, nothing consumed the line, and it fired twice per `Translator.load` (once for the locale, once for the fallback).

  **`load` now says when it gives up.** It answered an empty map for every failure with no trace, which is how this defect survived: a missing asset and a missing key look identical on screen. Both `return {}` paths log a warning naming the path and the error, guarded on `Magic.bound('log')` for the same reason the line above was removed. (`lib/src/localization/loaders/json_asset_loader.dart`, `test/localization/json_asset_loader_without_log_test.dart`, `doc/digging-deeper/localization.md`)

## [0.0.14] - 2026-09-19

### Breaking

- **An unresolvable route middleware stops the app at `Magic.init` instead of silently ungating the route.** Two changes, and the second is the one that does the work.

  `Kernel.resolveAll` ended in `.whereType<MagicMiddleware>()`, so a route declaring `middleware: ['auth']` against a Kernel that never received an `auth` alias rendered with NO gate on it and reported nothing anywhere. A missing gate lets everybody through, which is the one failure mode that must not be quiet. It throws a `StateError` naming the entry now.

  That alone was not enough, and measuring is what showed it. `resolveAll` runs at navigation, from `MagicRouter._handleRedirect`, which is GoRouter's `redirect` callback: GoRouter routes a throw from there to `onException`. Measured against a real `MaterialApp.router`, the page rendered nothing, the log said `Route not found: /`, and `takeException()` returned null. One silent failure traded for another, wearing a misleading message.

  So `MagicRouter._buildRouter` validates every registered route's middleware before it constructs the `GoRouter`, and throws one `StateError` listing every offending route with its path. That lands inside `Magic.init`, where nothing catches it. `Kernel.unresolvable` backs the check and constructs nothing, so validating a whole route table calls no factory and fires no side effect.

  Every registered route means the ones inside a layout too, which took a second pass to get right. A route declared in `MagicRoute.group(layout: ...)` is diverted into the layout's child list and never reaches the top-level table, so a check that walked only that table left every route under a shell or tab layout exactly as ungated as before: `_resolveRoute` still finds it at navigation, so the throw still landed in `onException` and still said nothing useful. A shell layout is where a gated screen usually lives, which made it the wrong half to miss. The check walks both lists now, deduplicated by identity because `MagicRoute.layout(routes: [...])` registers its pages in both.

  `onException` goes with it: it reported `Route not found` for every exception GoRouter handed it, including one thrown by the redirect callback. It names the underlying error when there is one.

  Found by a consumer app, `watchools`, whose every `magic_starter` route was ungated between installing the package and registering the three aliases its installer does not write. Nothing failed, nothing logged, and the screens rendered.

  Breaking for an app that currently relies on an unregistered alias being ignored, which is the behaviour this removes on purpose; that app now fails to boot until it registers or removes the alias. `Kernel.resolve` is untouched and still answers null for a single entry. Permitted pre-1.0 and recorded here rather than left to be discovered at runtime. (`lib/src/http/kernel.dart`, `lib/src/routing/magic_router.dart`, `test/http/kernel_resolve_test.dart`, `test/routing/middleware_resolvable_at_build_test.dart`, `doc/basics/middleware.md`, `skills/magic-framework/SKILL.md`)

### Added

- **A `FakeNetworkDriver` stub may answer asynchronously.** `FakeRequestHandler` widens from `MagicResponse Function(MagicRequest)` to `FutureOr<MagicResponse> Function(MagicRequest)`, and `_handle` awaits it. Source-compatible: every synchronous stub keeps compiling and behaving.

  **One behaviour change to know about in a consumer test suite.** `recorded.add` is now deferred by at least one microtask, where it used to happen synchronously inside the `get`/`post` call: the old `_handle` was sync and an `async` body runs straight through to its `return` before yielding, while `await` on a non-Future still schedules a microtask. A test that fires an unawaited `driver.get(...)` and asserts `assertSentCount(1)` in the same synchronous block passed before and fails now; `await` the call. Nothing in this repo's suites does it. The no-stub default path is unaffected, since it never awaits.

  What it admits is a test that needs a request to stay OUTSTANDING while the caller does something else, which is the only way to script a concurrency case. A consumer app could not test "a sign-out arrives while the panel handshake is still in the air" at all, and had to reach the same guard through a code path that happens to await nothing before its first write. A stub that must answer before it returns cannot open that window. (`lib/src/network/drivers/fake_network_driver.dart`, `test/network/fake_driver_async_stub_test.dart`, `doc/testing/http-tests.md`)

### Changed

- **The sibling floors name this batch's releases.** `fluttersdk_wind` goes `^1.6.1` to `^1.6.2` and `fluttersdk_artisan` `^0.0.9` to `^0.0.16`. Both old ranges admitted the new versions, so nothing resolves differently on a fresh `pub get`; what changes is that the floors say which releases magic is verified against. `CLAUDE.md`'s stack line was quoting `^1.5.3` and `^0.0.9`, the first of those already two minors stale before this bump, and it is corrected here. (`pubspec.yaml`, `CLAUDE.md`)

### Fixed

- A navigation issued before the `Router` widget has parsed a location no
  longer pushes onto an empty base. go_router pushes onto
  `routerDelegate.currentConfiguration`, which is `RouteMatchList.empty` until
  the widget mounts, and its `uri` is a bare `Uri()` with an empty path that
  every later match then reads. On go_router 17.3.0 the matcher throws a
  `RangeError` on it and a release build replaces the whole `Router` subtree
  with an `ErrorWidget`; on 18.0.1 there is no crash, but `currentLocation`,
  `pathParameter` and `queryParameter` all answer from an empty uri. Both
  `MagicRoute.to()` and `MagicRoute.push()` now `go` in that window.

  A `.stacked()` route navigated to before the router mounts therefore replaces
  rather than pushes. Nothing is lost: there is no page underneath to pop back
  to yet, and a link arriving from outside the app is where the reader arrives.

  `MagicRoute.push()` also gains the `StateError` its four sibling verbs
  already throw when the router has never been built. It died on a null-check
  with a message naming nothing, which is the same "the error points at the
  wrong thing" failure the rest of this entry is about, and the two states
  `push` can be in at cold start should not report differently.

- **A translation key missing from the current locale is served from the fallback, instead of rendering as its own dotted path.** `Translator.load` now reads the fallback catalogue alongside the locale's own and layers the locale over it, so the merge happens once at load rather than on every lookup.

  This is a defect against this package's own documentation rather than a missing feature: `doc/digging-deeper/localization.md:155` has always said `trans()` "falls back to `fallback_locale` if not found". It did not. `get` answered `_sentences[key] ?? key`, and the only fallback anywhere was `JsonAssetLoader`'s, which is whole-FILE (`lib/src/localization/loaders/json_asset_loader.dart:58-75`): it reads the fallback catalogue when the requested one fails to load at all, and never when the requested one loads and is simply incomplete.

  Measured in a consumer app whose `tr.json` carried 12 of the 357 keys its `en.json` had: all 345 others rendered on screen as `magic_starter.auth.login.title` and the like. The app closed it by hand-translating every key, which is the work this makes unnecessary.

  The recovery path guards on `Magic.bound('log')` before it warns. `Log.warning` resolves `log` through the container, which THROWS for an unbound key (`lib/src/foundation/application.dart:269-274`), so an unguarded warning defeated the whole point of the catch: a widget test building `MaterialApp` through `LangDelegate` without a full `Magic.init()`, or a locale switch before `LogServiceProvider` boots, took the exception straight out of `load()`.

  Both catalogue reads start before either is awaited, so a locale with a fallback pays one round trip rather than two. The spread order decides precedence and is unaffected by completion order.

  The merge lives in `Translator` rather than in the loader deliberately: this class owns `fallbackLocale`, so every `TranslationLoader` a host app writes gets the behaviour without knowing about it. Loading the fallback locale itself still reads one file. A fallback that will not load logs a warning and answers empty rather than throwing, because it is a courtesy and never a requirement: the locale's own strings must not go down with it. (`lib/src/localization/translator.dart`, `test/localization/translator_key_fallback_test.dart`, `doc/digging-deeper/localization.md`)

## [0.0.13] - 2026-09-17

### Improvements

- **`plugin-starter.md` covers the routes `magic_starter` 0.0.29 starts pushing.** Eleven of them are `.stacked()` now (the eight settings spokes, both team screens, both notification screens) and three groups deliberately are not (the settings hub, the invitation arrival, the six auth routes), which is a distinction an agent registering a route beside them has to be able to make. The entry also records that a stacked route names NO transition, so it takes `MagicRouter.defaultTransition` rather than pinning `none`, and that the `magic` floor is `^0.0.12` there because `RouteDefinition.stacked()` exists in no release below it AND 0.0.12 is where a routed page stopped being transparent, which is the defect stacking exposes. The stamp moves to `v0.0.29`, which that package's own `skill_reference_stamp_test.dart` compares its pubspec against, in CI as well as locally: its release PR was red on exactly this. (`skills/magic-framework/references/plugin-starter.md`, `skills/magic-framework/SKILL.md`)

## [0.0.12] - 2026-09-16

### Breaking

- **`RouteTransition` gains a value, `platform`.** Source-breaking for a consumer with an exhaustive `switch` over the enum: that switch stops compiling until the new case is handled. The value is inserted after `none` rather than appended, so every later value's `index` shifts by one; nothing in the ecosystem persists an enum index and nothing should, since a persisted `index` breaks on any insertion. The default is untouched, and every existing value means what it meant. Permitted pre-1.0 and recorded here rather than left to be discovered at the compiler. `test/routing/router_test.dart` now asserts the whole inventory in order instead of containment, which is why this entry exists at all: the old assertion passed with the new value missing from it. (`lib/src/routing/route_definition.dart`, `test/routing/router_test.dart`)

### Fixed

- **A routed page paints an opaque background, so the page under a transition stops showing through it.** The wrapper was `Material(type: MaterialType.canvas)`, which paints `Theme.canvasColor` (`material.dart:460`), and `fluttersdk_wind` sets that to `Colors.transparent` on purpose (`wind_theme_data.dart:514`) so a Material surface never paints over a Wind `bg-*` className. Every magic app themes through wind, so every page has been transparent for as long as `_buildPage` has existed, while the comment on that line claimed the opposite.

  Nothing could show it until routes started stacking. `to()` calls `go()`, which replaces the whole page list, so there was never a second page underneath to show through. A `.stacked()` route puts one there, and the outgoing page is then visible THROUGH the incoming one for the length of the push: on iOS it sits at the Cupertino parallax offset with the new page drawn over it, and disappears only when the animation ends and the Navigator offstages the route below an opaque one. Reported off a TestFlight build as the old screen stopping half-way across the display with the new one on top of it.

  Measured rather than inferred: `Theme.of(context).canvasColor` reads `alpha 0.0` in a running wind app while `scaffoldBackgroundColor` reads opaque, which is why the fix takes the latter. An explicit color also stops `MaterialType.canvas` consulting the theme at all. A host that makes `scaffoldBackgroundColor` transparent is saying its pages are transparent, which is a choice rather than an accident.

  **The floor on `fluttersdk_wind` moves to `^1.6.1` with this, and it is a floor for a VALUE rather than for an API.** Painting that field is what makes its value matter, and wind filled it from its own white and gray-900 rather than from the `bg-surface` alias an app paints its canvas with until 1.6.1. On 1.6.0 this release paints `#FFFFFF` over `#F9FAFB` in light and `#111827` over `#07090C` in dark, on every screen, and the dark one is not subtle. Nothing fails to compile below the floor, which is exactly why it is declared rather than left to resolve.

  **Two things for an adopter to check, because this is the first release in which the page background is painted at all.**

  Set wind's `background` color if your pages have a canvas colour. `scaffoldBackgroundColor` is what wind fills from it (`wind_theme_data.dart:511`) and it is Flutter's own name for the colour behind a page, but an app that never set the key gets wind's fallback: pure white in light mode, `gray900` in dark. An app whose canvas comes from a `bg-*` className alias instead has been painting that colour on a widget ABOVE the Navigator, so the two can differ and the page now wins. Measured on one consumer: the alias resolved to `#F9FAFB` while `scaffoldBackgroundColor` was `#FFFFFF`.

  A LAYOUT that paints its own background behind the child slot is covered over for the same reason, since the page sits inside the shell. Harmless when the layout paints the same colour, visible when it paints a gradient or an image. Paint it outside the child slot, or set `scaffoldBackgroundColor` transparent to opt the pages back out and accept the transition overlap.

### Added

- **`MagicApplication.pageTransitionsTheme`, so an app can say what `RouteTransition.platform` looks like.** That transition deliberately has no animation of its own: its page mixes in `MaterialRouteTransitionMixin`, which reads `Theme.of(context).pageTransitionsTheme`, so leaving this unset gives every platform the animation its own operating system uses. That default is the reason to reach for `platform` at all and most apps should keep it. What had no seam was overriding it: the `ThemeData` comes from wind's `WindThemeController.toThemeData()` and `MagicApplication` passes it straight to `MaterialApp`, so an app that wanted a different animation on one surface had nowhere to say so. A per-route `RouteTransition` cannot express it either, because it is chosen once at registration and the common case is exactly the opposite shape: keep the mobile builds' native animation, give the desktop or web build none.

  Applied with `copyWith`, so the theme stays wind's. The colors, the typography and the component defaults are untouched and a null value changes nothing at all.

  **A partial map is a partial override, not a reset.** A platform left out of `builders` keeps its own default: Flutter answers an unnamed platform with `CupertinoPageTransitionsBuilder` on iOS and `ZoomPageTransitionsBuilder` everywhere else (`material/page_transitions_theme.dart:881-889`), so omitting `TargetPlatform.iOS` leaves the Cupertino slide and its back gesture in place. This paragraph said the opposite before it was checked against the Flutter source, and named `FadeUpwardsPageTransitionsBuilder`, which is not in that switch at all. `RouteTransition.fade`, `slideRight` and the rest build their own animation explicitly and never consult the theme, so none of this reaches them.

- **A `User-Agent` that names the app and its platform, sent by default.** Dart's HTTP client sends `Dart/<sdk> (dart:io)`, which says nothing about the app and is identical across every Flutter client a backend has, so anything a server derives from the agent answers WRONGLY rather than partially. Found on a session list: the backend's user-agent parser matched no browser and no platform, defaulted the device to desktop, and a phone's own session rendered as a browser session on an unknown machine beside a laptop icon. `NetworkServiceProvider` now composes `<App Name> (Flutter; <platform>)` from `app.name` and `defaultTargetPlatform`, with the platform in the casing Apple and Google use so a server can match it without normalising. No version: nothing here knows the app's build number, and a config key an adopter has to fill in would leave the useful half empty in most apps. Skipped on WEB, where `User-Agent` is a forbidden header name for `XMLHttpRequest`, so the browser drops it and sends its own, which is the right agent there anyway. A host that already sets one in `network.drivers.api.headers` keeps it, matched case-insensitively, since HTTP header names are case-insensitive and a host writing `user-agent` would otherwise have sent two agents on one request.

  **The name is folded to header-safe ASCII before it goes on the wire, and that is load-bearing rather than tidy.** `dart:io` refuses any header value carrying a byte above 127 and throws a `FormatException` from `HttpHeaders.set`, which Dio surfaces as a `DioException`, so an app whose `app.name` holds an accent would have lost EVERY HTTP request because of its display name: measured, `Şirket Takip` and `Café Münster` both throw. Accented Latin letters fold to their base letter rather than being dropped, since dropping leaves `irket Takip` where the adopter would have picked a plain name; the table covers every letter in Latin-1 Supplement and Latin Extended-A, so Turkish, German, French, Spanish, Nordic, Polish, Czech and Dutch names survive legibly, and a test walks both ranges so the claim checks itself rather than being maintained by hand. A script with no Latin base is dropped and the agent falls back to the config default, which is `Magic App`, matching what `lib/config/app.dart` ships. The same pass closes the injection shape, since a carriage return or newline is below 0x20 and cannot survive it. A test drives the real `HttpClient` with each of these names, because a string comparison cannot prove the thing that was actually broken. (`lib/src/network/network_service_provider.dart`, `doc/basics/http-client.md`, `skills/magic-framework/references/http-network.md`, `skills/magic-framework/SKILL.md`, `test/network/default_user_agent_test.dart`)

- **`RouteTransition.platform` and `RouteDefinition.stacked()`, because a magic app has no back gesture and, on Android, no working back button.** Two gaps that turn out to be one. No route has ever carried the iOS left-edge swipe, since go_router's `CustomTransitionPage` builds a bare `PageRoute` and Flutter installs the swipe detector INSIDE `CupertinoPageTransition` rather than beside it; a custom `transitionsBuilder` never reaches it. And `to()` calls `go()`, which replaces the Navigator's whole page list, so a `to()`-only app has nothing to pop even where the detector exists.

  **The second half is worse than a missing gesture.** Flutter reports `canHandlePop` to the platform on every navigation, with one page it reports `false`, and the Android embedder responds by unregistering its `OnBackInvokedCallback`: the system back button then LEAVES THE APP rather than going back. Measured through the platform channel rather than reasoned about, and pinned by a test that reads it: eight `setFrameworkHandlesBack(false)` across two `to()` calls, `true` only after a push.

  `RouteTransition.platform` routes through `PageTransitionsTheme`, so one page type answers every platform: the Cupertino slide and its swipe on iOS and macOS, predictive back on Android (already the framework's own default builder), the zoom on Windows and Linux. `.stacked()` makes `to()` push instead of replace. Navigating to the path you are already on turns on the query rather than the path: naming none is a nav destination re-tapped and does nothing, since pushing would stack a screen on itself and replacing would throw away the stack the reader built getting there, while naming one is a real move and swaps the top page. That swap REBUILDS the screen rather than remounting it, which is what a query change already does everywhere in Magic: go_router keys a page on the matched path and the query is not part of it, measured on an ordinary unstacked `go()`. `pushReplacement` would have remounted instead, and only where something sits underneath, since it falls back to the declarative list when the stack would empty; one verb behaving two ways by stack depth is worse than every verb behaving one way. What it costs is that a screen has to read its query where a rebuild can see it, so `doc/basics/routing.md` now says to read it in `build()` and never in `initState()`, and not to register the page as a `const` widget, which does not rebuild at all. `back()` is untouched and still prefers the native pop, so the history fallback keeps covering every route that is not stacked.

  Both are opt-in per route, with `MagicRouter.defaultTransition` and `defaultStacked` for an app that wants one answer everywhere. `RouteTransition.none` still builds a `NoTransitionPage`: it is the right answer on web, where `go()` already produces a working browser Back, and changing it would put a slide animation on every screen change in every existing app. Its dartdoc claimed to be the platform transition and never was; that is corrected rather than implemented.

  **A side menu needs no arbitration with the swipe**, though both live on the left edge, and no code was written for it: `popGestureEnabled` is false on a route with nothing under it, so the detector never enters the gesture arena on a drawer's own screen, and on a pushed route the deeper recognizer wins the arena. A test pins the first half. `swipeBack(false)` refuses the gesture alone; `PopScope` remains the tool for "this route should not be left yet", and Flutter's gesture already honours it.

  **`toNamed()` answers the same way as `to()`.** It used to go straight to go_router's `goNamed()` and never ask whether the route stacks, so one route pushed by path and REPLACED by name: no back gesture, and Flutter reporting `canHandlePop: false` so Android's system back left the app. Nothing at the call site said the verb decided that, and neither `stacked()`'s dartdoc nor the routing doc qualified the verb. It now resolves the name to a location and hands it to `to()`, so the stacking decision, the same-screen rules and the history record are all the ones `to()` already applies. Two doc notes moved with it: both said the history stack is populated by `to()` and `toNamed()`, which was already only true of an UNSTACKED route (the push is its own record, and an entry there would make the next `back()` look like a press that did nothing) and is now the answer for named navigation too. (`lib/src/routing/magic_platform_page.dart`, `lib/src/routing/magic_router.dart`, `lib/src/routing/route_definition.dart`, `lib/magic.dart`, `doc/basics/routing.md`, `example/lib/routes/app.dart`, `skills/magic-framework/references/routing-navigation.md`, `skills/magic-framework/SKILL.md`, `test/routing/platform_back_test.dart`)

### Improvements

- **`plugin-starter.md` covers what 0.0.28 changes for an adopter.** Four of them are contract rather than cosmetics, and the reference said none. The floors move: `magic_notifications ^0.3.2` for the `contentClassName` the notification routes now pass, and `fluttersdk_wind ^1.6.0` declared DIRECTLY rather than taken through `magic`, because a transitive constraint leaves nothing to raise when the starter calls a new Wind API and the adopter's symptom is then `undefined_named_parameter` inside a package they do not own. `MSAvatar` joins the component table (39, not 38) with the one thing a caller gets wrong: a `flex` in its className starves the photo, which is the defect the component shipped with. The timezone select pages through its endpoint and resets its cursor through `WSelect.onOpen`. And `profile.unknown_device` is a key an upgrading app adds by hand, like the five `notifications.*` keys beside it, or a session with an unreadable agent renders the raw key. The stamp moves to `v0.0.28`, which `magic_starter`'s own `skill_reference_stamp_test.dart` compares its pubspec against whenever a sibling checkout exists. (`skills/magic-framework/references/plugin-starter.md`, `skills/magic-framework/SKILL.md`)

- **`plugin-notifications.md` covers the APNs entitlement the installer now writes.** `magic_notifications` 0.3.1 stops warning about the Release build's `aps-environment` and writes it: `notifications:install` produces `Runner.entitlements` with `development` and `RunnerRelease.entitlements` with `production`, points Release at the second and leaves Debug and Profile on the first, because Apple makes that value a property of the build configuration and one file cannot serve a development and a distribution profile at once. The reference said none of this, and the failure it prevents is invisible before TestFlight: an app exported against the development value registers a sandbox APNs token the production app can never deliver to. Also recorded: configurations are matched by BASE name so a flavoured project is covered rather than declined, a configuration that is none of the three is left untouched and named in a warning, and `notifications:uninstall` reverts neither file by design. The stamp moves to `v0.3.1` and the requirement line now names `fluttersdk_artisan ^0.0.15`, which is the release carrying the `setEntitlementsPaths` op the install depends on. (`skills/magic-framework/references/plugin-notifications.md`, `skills/magic-framework/SKILL.md`)

- **`plugin-notifications.md` carries `contentClassName`, the parameter 0.3.2 adds to both screens.** Both constructors are listed in that file and neither named it, which is the failure mode this reference exists to prevent: an agent mounting `NotificationsListView` inside a host that owns its page geometry had no way to learn that the two paddings apply to the same edge, and the symptom is a page sitting twice as far from the display as its neighbours rather than anything that errors. The entry says what to pass (`''` to hand the geometry to the container, or a className of your own), and why it could not have been a wrapper: the padding is on the content column inside the scroll view, so the page surface stays full bleed behind the scroll. The stamp moves to `v0.3.2`, which is what `magic_notifications`' own `skill_reference_stamp_test.dart` compares its pubspec against whenever a sibling checkout exists. (`skills/magic-framework/references/plugin-notifications.md`, `skills/magic-framework/SKILL.md`)

## [0.0.11] - 2026-09-12

### Improvements

- **`plugin-starter.md` follows `magic_starter` off the alpha rail.** That package's next release is `0.0.27` rather than `0.0.1-alpha.27`, so the reference stamp moves with it and the release markers inside the file now read `0.0.27` where they described that release. The `magic_notifications` requirement it states moves to `^0.3.0`, which is the floor the starter release carries, and the notification section gains the five `notifications.*` keys the mounted screens read and no package supplies (`bulk_title`, `bulk_description`, `delete`, `delete_failed`, `channel_sms`): an adopter upgrading with a hand-written catalogue sees each of them rendered as its own key. The configuration section also gains `notifications.external_id_prefix`, which 0.0.27 introduced: the provider now declares `<prefix><user id>` as the push external id off `Auth.stateNotifier` and the value has to equal the backend's own, since OneSignal accepts a mismatch and delivers to nobody. This file is the only agent-facing document for that package, since `.pubignore` keeps its `CLAUDE.md` out of the published archive, and `magic_starter`'s own `skill_reference_stamp_test.dart` fails against a stale stamp whenever a sibling checkout exists. (`skills/magic-framework/references/plugin-starter.md`, `skills/magic-framework/SKILL.md`)

## [0.0.10] - 2026-09-11

### BREAKING

- **If you pinned `fluttersdk_wind` below 1.5.3, Return no longer moves the focus to the next field.** The Wind floor moves to `^1.5.3` (see the `### Changed` entry for what that buys), and the span crosses Wind 1.4.0, which made a single-line `WInput` default its Return key to `TextInputAction.done` instead of `.next`. Write `textInputAction: TextInputAction.next` on every field in a multi-field form that relied on the old default. Nothing in magic's own API changes, which is why the constraint itself is filed under Changed; this line exists so the fix is where you would look for it. (`pubspec.yaml`)

- **`file_picker` moves from `>=11.0.2 <12.0.0-0` to `^12.2.0`, and the `Pick` facade moves with it.** v12 splits the plugin into federated platform packages and rewrites the surface magic wrapped: `pickFiles` returns a plain `List<PlatformFile>` instead of a nullable `FilePickerResult`, `saveFile` returns a `Uri?` instead of a `String?`, and `PlatformFile` loses its `size` and `bytes` fields in favour of `lengthSync()` and `readAsBytes()`. None of that is expressible in a version range spanning both majors, which is why the constraint moves to `^12` rather than widening. (`pubspec.yaml`, `lib/src/facades/pick.dart`)

- **`Pick.saveFile` returns `Future<Uri?>` and takes `fileName` and `bytes` as required arguments.** The old signature accepted both as nullable and threw an `ArgumentError` at runtime when either was missing, which was a guard against a mistake the type system can catch on its own; `required` moves that failure from the user's device to the compiler. The return type follows file_picker rather than flattening it: v12 documents the scheme as possibly `file`, `content`, `http(s)`, `data` or `blob`, so a `String` would hand back `content://com.android.providers.downloads/42` to code that was written to open a filesystem path. Call `uri.toFilePath()` after checking `uri.scheme == 'file'`, and treat the rest as opaque handles. (`lib/src/facades/pick.dart`)

- **`withData` is gone from `Pick.file` and `Pick.files`.** file_picker 12 deprecated the parameter and stopped forwarding it, so it had already become a no-op. Bytes now come off `MagicFile.readAsBytes()`, which reads through `PlatformFile.readAsBytes()` on first call and caches the result. Behaviour is unchanged for anything that reads bytes, and better for anything that does not: picking twenty files no longer pulls twenty files into memory to look at their names. Drop the argument from the call site; there is nothing to replace it with. (`lib/src/facades/pick.dart`)

- **`package:magic/magic.dart` re-exports five names from `file_picker` instead of the whole library:** `FilePicker`, `FilePickerStatus`, `FileType`, `IllegalCharacterInFileNameException` and `PlatformFile`. v12 re-exports its platform interface, which brings four option classes (`AndroidOptions`, `LinuxOptions`, `WebOptions`, `WindowsOptions`) whose names are already taken by `flutter_secure_storage` in the same barrel; that is an `ambiguous_export` error in magic itself, so every consumer app fails to compile rather than only the ones that pick files. A `show` list settles it and keeps `FilePickerPlatform` and the method-channel plumbing out of magic's public API at the same time. Import `package:file_picker/file_picker.dart` directly to configure per-platform picker options. (`lib/magic.dart`)

### Added

- **`MagicVaultService` takes `macOsUsesDataProtectionKeychain`, so a macOS build with no signing identity can store a secret at all.** macOS has two keychains and the service previously passed no `mOptions`, which left it on `flutter_secure_storage`'s default of the data protection one (`macos_options.dart:24`). That keychain requires the `keychain-access-groups` entitlement, the entitlement is restricted and therefore forces a signed build with an App ID, and on a build with no certificate installed **every write fails** with `PlatformException(-34018, errSecMissingEntitlement)`; measured on a consumer app's own build. Passing `false` moves the items to the legacy login keychain, which needs no entitlement. Note that `false` does not set `kSecUseDataProtectionKeychain` to false, it OMITS the key from the query entirely (`flutter_secure_storage_darwin` `FlutterSecureStorage.swift:227-231`, guarded by `params.usesDataProtectionKeychain`), which is the mechanism by which the item lands in the other keychain rather than a flag the keychain reads.

  **The default is `true`, which is what every existing build already does, and it stays that way because there is no migration between the two keychains in either direction.** An item written to one is invisible from the other, and every caller reads that miss as "never stored" rather than as an error: `Crypt.encryptWithDeviceKey` generates a fresh device key on a null read (`crypt.dart:141-147`), making everything encrypted under the old one permanently unreadable while the old key sits unreachable in the other keychain, and `BaseGuard` loses the stored token the same way and logs the user out. Flip the key once, before the app has stored anything; do not reach for it to clear a `-34018` on a build that has been storing secrets, and read `doc/security/vault.md` for how to move existing items across.

  `VaultServiceProvider` reads it from `security.vault.macos_data_protection_keychain`, inside the singleton factory rather than beside it, so a test or a hand-registered provider that sets the key afterwards is still read. macOS also now gets `first_unlock_this_device` accessibility, rather than the package default `unlocked` (`apple_options.dart:72`), for the same reason iOS already passes `first_unlock`: a read while the screen is locked, such as a refresh on launch before anyone has touched the machine, succeeds under the former and fails under the latter, and the `ThisDeviceOnly` half keeps the item off a backup restored onto a different Mac. `kSecAttrAccessible` is a data protection keychain attribute, so that class is inert once the key above is `false`. The iOS and Android options are unchanged. (`lib/src/security/magic_vault_service.dart`, `lib/src/security/vault_service_provider.dart`)

- **`FakeVaultService.throwOnGet`, `.throwOnPut`, `.throwOnRemove` and `.throwOnFlush`, so a consumer can test its own vault-failure branch.** Every prior override was a no-throw body over an in-memory map, so nothing exercised the path a real keychain failure takes through `MagicVaultService`, which wraps a `PlatformException` as `MagicVaultException` on all four operations. `throwOnRemove` is the one a sign-out needs: a consumer that deletes the stored credential first and clears its in-memory session afterwards has two branches through one keychain call, and the failing one decides whether the user is told the secret is still on the device or is shown a sign-out that did nothing. All four default to a `MagicVaultException` and accept a custom error, all four are cleared by `reset()`, and each only affects its own operation: a throw armed on `get` does not touch `put`, and one armed on `remove` does not touch `flush`. The throw is armed for every key, so a test needing one key to fail while its neighbours succeed still needs its own subclass; a key filter would have to record the attempt before the throw, and that would make `assertWritten` pass for a `put` that threw. (`lib/src/testing/fake_vault_service.dart`)

- **`MagicSelector<C, T>` rebuilds one subtree when one part of a controller changes.** `refreshUI()` notifies every listener and `MagicStatefulViewState` answers with `setState` on the whole view, which is the right default and stops being cheap on a screen where one field changes often and most of the screen does not care: a consumer measured one keystroke in a search field rebuilding 220 styled containers. `MagicBuilder` could not help, because it needs a `ValueListenable` and a controller is a `ChangeNotifier`. The selector caches the widget its builder returned and, while the selected value compares equal, returns that same instance, so `Element.updateChild` short circuits on `child.widget == newWidget` and never descends. Returning an identical instance rather than skipping a `setState` is what makes it work under a parent that rebuilds anyway. Two rules follow: `builder` must be a pure function of the selected value (select a record to watch several fields), and equality is plain `==`, so a selector returning a freshly built `List` never matches its own cache. Deep comparison is deliberately not used, because walking a ten thousand element list per keystroke costs more than the rebuild it prevents. (`lib/src/ui/magic_selector.dart`)

- **`MagicPaginator.isRefreshing` and `.isLoadingMore`, because a list has three loading states and one flag cannot carry them.** A first load shows a skeleton, a refresh keeps the rows the reader is already looking at, and a next page puts a footer under the last row. Read off `isLoading` alone the second and third are indistinguishable, so a screen either blanks itself on every filter change or grows a footer promising a page nothing asked for. Both are false on a first load (nothing on screen to preserve, nothing being appended) and all three are false once the request lands. The distinction only exists DURING a request, which is why `_isReset` is set beside `_isLoading` and before the notification rather than derived afterwards: by the time a caller can await the future there is nothing left to tell apart. One window is documented rather than changed: a `refresh()` deferred behind an in-flight `loadMore()` keeps reporting `isLoadingMore` until that page lands, which is what is happening on the wire and the only path where the flags follow the request rather than the caller's most recent ask. (`lib/src/http/magic_paginator.dart`)

- **`MagicPaginator.total`, read from `meta.total`.** The size of the collection rather than of the pages in hand: `items.length` answers "how much have I fetched", and a header reading "11 of 240" needs the other number, which a consumer previously had to fetch a second time or parse out of a response this class had already parsed. Null on a cursor collection, because Laravel's `cursorPaginate()` deliberately does not count and a total invented from the loaded page would be wrong rather than approximate. Read with `containsKey` before the mode branches, so a page that says nothing about the count leaves the last known value alone: an endpoint sending the total on page one only would otherwise have it erased by page two. Cleared on a reset, since a reset is usually a different question and the previous count describes a collection that no longer exists. (`lib/src/http/magic_paginator.dart`)

- **`MagicPaginator.loadedPages`.** Counts what is HELD, not requests made: a `refresh()` puts it back to one and a failed page counts nothing. A screen that writes its position into a URL wants this rather than the cursor, because a cursor names a position in ONE ordered result: shared, it drops the reader into the middle of a list with nothing above it, and points nowhere once that row is renamed or deleted. A page count re-fetches pages one to N, which is the same rows with the top intact. (`lib/src/http/magic_paginator.dart`)

- **`Pick.saveFile` takes a `mimeType`, and derives one from the file name when you do not pass it.** file_picker 12 added the parameter and defaults it to `application/octet-stream`, which is the value Android SAF and the browser both read to decide what the saved file is: a PDF written under it opens in a generic handler rather than a reader. `Pick` already carried an extension-to-MIME map for the pick direction, so the save direction now reads the same table and only falls back to `application/octet-stream` for an extension it does not know. (`lib/src/facades/pick.dart`)

### Changed

- **`fluttersdk_wind` moves from `^1.2.0` to `^1.5.3`, so every magic app gets Wind's keyboard and focus fixes rather than only the apps that happened to resolve fresh.** The ceiling does not move; the floor does. Anyone running `flutter pub get` without a pin was already on 1.5.x, because `^1.2.0` admitted it, so for them this changes nothing. It changes something for an app that pinned Wind lower: 1.5.3 is now the minimum, and the span it is being pulled across carries one behavioural break, 1.4.0 making a single-line `WInput` default its Return key to `TextInputAction.done` instead of `.next`. A multi-field form that relied on Return advancing the focus needs `textInputAction: TextInputAction.next` written out. What the floor buys is worth that: 1.5.3 makes a focused `WAnchor` answer `ActivateIntent`, so a control reachable by keyboard, gamepad or a television remote actually activates; it makes one control cost one Tab stop rather than two, which every `focus:ring-*` control in magic's own views was paying; and it fixes `disabled:` not reaching a `WDiv` inside a disabled `WAnchor`. Magic renders its views through W-widgets, so these are magic's bugs as much as Wind's. (`pubspec.yaml`)

- **`MagicFile.size` stays filled for every picked file, and it costs a `stat` on Windows and Linux to keep it that way.** v12 replaced `PlatformFile.size` with two readings: `lengthSync()`, the size the native picker reported, and `length()`, which measures the file when it reported none. The Windows dialog and the Linux XDG portal return a path and nothing else, so the synchronous reading is null for every desktop pick; reading it would have left `size` null exactly where a desktop app is most likely to be checking an upload limit, and the null would arrive as a silently skipped check rather than as an error. `Pick` reads `length()` instead. Web and Android always report a size, so the fallback only runs on desktop. (`lib/src/facades/pick.dart`)

### Fixed

- **Outgoing header names keep the casing you wrote, instead of reaching the wire lowercased.** `DioNetworkDriver` left `preserveHeaderCase` at Dio's default of `false`, so the IO adapter normalised every key on the way out: `User-Agent` went as `user-agent`, `X-Request-Id` as `x-request-id`. HTTP/1.1 says header names are case-insensitive and most servers honour that, but the consumers that read a header by exact key do not, and they fail quietly: ExoPlayer looks its request headers up case-sensitively and simply finds nothing, so a media request loses its user agent and gets served the wrong stream rather than an error anyone can see. Found on a consumer app whose video playback broke only in release, against one CDN. The driver now sets `preserveHeaderCase: true` and passes the caller's key through untouched. Two things are worth knowing before you rely on it. It only holds where the IO adapter runs, so mobile and desktop keep the casing and **web still lowercases**, because `dio_web_adapter` writes headers through `XMLHttpRequest.setRequestHeader` and never reads the flag. And the response side is unchanged: `MagicResponse.headers` keys still arrive lowercase, since `HttpHeaders` lowercases on receipt whatever the peer sent. (`lib/src/network/drivers/dio_network_driver.dart`)

- **`MagicPaginatedListView` wore its loading footer through a refresh.** The footer means "there is more, and it is on its way", and a refresh is the opposite statement: those rows are being replaced rather than added to. It was gated on `isLoading && items.isNotEmpty`, which a refresh over a non-empty list satisfies, so every pull-to-refresh and every filter change grew a footer promising a page that had not been requested. Now gated on `isLoadingMore`. Covered by `a refresh does not wear the loading-more footer`, which holds the window open with a fetcher `Completer` because `Http.fake` answers synchronously and `tester.pump()` drains microtasks before it builds. (`lib/src/ui/magic_paginated_list_view.dart`)

## [0.0.9] - 2026-08-26

### Added

- **`MagicPaginator.fetcher`, for a collection that does not arrive from a bare url.** The url constructor calls `Http.get` itself, which is right for an endpoint and wrong for anything behind a contract: a rail or driver a consumer can swap, a store, a query that needs assembling. Found on a real one, a billing history that reaches the client through a payments service whose store build THROWS rather than answering, so pointing a url paginator at the endpoint it wraps would have walked around the abstraction that keeps that build honest. `MagicPage<E>` is what a fetcher reports: the rows, plus either a `nextCursor` or a `hasMore` for a source that pages by something the paginator never sees. The fetcher is handed a `MagicPageRequest` carrying that cursor AND an `isFirst` flag, because a source keeping its own position has no cursor at all: without the flag a `refresh()` looks exactly like a `loadMore()` to it, and the reset that clears the rows would then render whatever page it was up to as the whole list. `mode` reports the new `PaginationMode.fetcher` rather than borrowing `cursor`, since how the pages are addressed is the fetcher's business. Only an `Exception` becomes `error`: an `Error` out of a fetcher is that code being wrong and propagates rather than arriving on screen as a TypeError message. Everything else is shared with the url mode, which is the point of putting it here rather than letting each consumer re-implement the accumulation, the in-flight and disposal guards, and keeping the rows when a page fails. A fetcher signals failure by throwing, where an endpoint signals it with a status code, so the catch is what the `!response.successful` branch is on the other path. (`lib/src/http/magic_paginator.dart`)

- **`MagicPaginator<E>` and `MagicPaginatedListView<E>`: a collection that arrives one page at a time and costs the viewport rather than the result.** `fetchList` reads the `data` key, replaces whatever was there, and ignores the pagination envelope entirely, so the only shape it supports is "fetch everything and render everything". That is fine for a settings screen and wrong for a log, a check history or a feed: rendering a long collection as a column of every row costs one build, one layout and one semantics node per row on the FIRST frame, whether or not the reader ever scrolls that far. The paginator holds the rows fetched so far, knows whether the server has more, and appends; the list widget builds only what the viewport can show and asks for the next page as the tail comes into view. Measured in a widget test: 500 rows in a 300px viewport cost fewer than 30 `itemBuilder` calls. (`lib/src/http/magic_paginator.dart`, `lib/src/ui/magic_paginated_list_view.dart`)

- **Both Laravel envelopes are read, and the mode is taken from the response rather than configured.** A `meta.next_cursor` key means `cursorPaginate()` and the next page is requested with `?cursor=`; a `meta.current_page` key means `paginate()` and the next page is `?page=n+1`; neither means a bare collection that is already complete. **Reach for `cursorPaginate()` on anything that grows at the head**, which is most live data: offset addresses a page by counting from the start, so a row inserted at the top between two requests shifts everything down and page two repeats the last row of page one. A cursor names a position in the ordering, so it cannot drift, and the database answers it without counting past the rows it skips. The KEY identifies the mode and its VALUE decides `hasMore`, because `next_cursor` is present and null on the last cursor page.

- **The failure modes are guarded here rather than left to every caller.** `loadMore()` is a no-op while a request is in flight, because an infinite-scroll list fires it from a scroll callback that runs on every frame near the end; without the guard the same page is fetched and appended several times and every row in it shows two or three times. A failed `loadMore()` keeps the rows already on screen and leaves `hasMore` alone: losing page one because page two timed out is worse than the timeout, and the retry needs a target. A **transport** failure is one of them: `DioNetworkDriver` reports a timeout or a dead link as statusCode 0, which is neither `failed` (>= 400) nor `successful`, so the check is `!response.successful` and an offline first page reports an error rather than rendering as an empty collection. Disposing mid-request is safe (every notify is guarded, the way `MagicController.refreshUI` is), and a `refresh()` issued while the tail is auto-fetching waits for that page and then starts over instead of silently doing nothing. `items` is a live `UnmodifiableListView` rather than a `List.unmodifiable` copy, since the widget reads it once per build and a copy per frame is the cost this class exists to avoid.

- **A first page shorter than the viewport still fetches its successor, and stops when fetching stops helping.** Scroll notifications only fire when a list actually scrolls, so a page that does not fill the viewport left the reader with a truncated list and no way to extend it, which any `perPage` smaller than a tall viewport reaches. `MagicPaginatedListView` checks `maxScrollExtent` after the frame and asks for the next page when there is nothing to scroll. That check re-arms on every build and a failed `loadMore` leaves `hasMore` true on purpose, so it needs its own brakes or the two compose into a fetch per frame against a failing endpoint (measured at 22 requests across 20 frames). Two gates close it: an `error` stops the fill, because a failure is not an invitation to retry harder and the retry belongs to whoever renders it; and a page that added no rows **to that collection** stops it, because a server handing back a cursor beside an empty `data` array never grows the list and nothing else would say stop. The second gate is keyed on `(generation, count)` rather than on the count alone, and `MagicPaginator.generation` is public for that reason: it increments on every landed reset, so a `refresh()` re-arms whatever the count had disarmed. Keyed on length alone, a refresh that rebuilds page one at the same length reads as "nothing was added" and strands the reader on the retry path, which is the same defect the fill exists to prevent.

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
