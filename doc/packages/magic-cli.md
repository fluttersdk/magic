# Magic CLI

The Magic CLI is an `fluttersdk_artisan` plugin that ships as part of the magic package, providing `magic:install`, `key:generate`, and 20 `make:*` scaffold commands through magic's bundled `artisan` executable (`dart run magic:artisan`).

- [Introduction](#introduction)
- [Installation](#installation)
- [Project Setup](#project-setup)
    - [install](#install)
    - [key:generate](#keygenerate)
- [Make Commands](#make-commands)
    - [make:resource](#makeresource)
    - [make:model](#makemodel)
    - [make:controller](#makecontroller)
    - [make:view](#makeview)
    - [make:repository](#makerepository)
    - [make:action](#makeaction)
    - [make:form](#makeform)
    - [make:test](#maketest)
    - [make:migration](#makemigration)
    - [make:seeder](#makeseeder)
    - [make:factory](#makefactory)
    - [make:policy](#makepolicy)
    - [make:provider](#makeprovider)
    - [make:middleware](#makemiddleware)
    - [make:enum](#makeenum)
    - [make:event](#makeevent)
    - [make:listener](#makelistener)
    - [make:request](#makerequest)
    - [make:lang](#makelang)
    - [make:component](#makecomponent)
    - [previews:refresh](#previewsrefresh)
    - [design:sync](#designsync)
    - [design:lint](#designlint)
    - [DESIGN.md format](#designmd-format)

<a name="introduction"></a>
## Introduction

Magic CLI is the Artisan-like command-line tool for Magic. If you've used Laravel's Artisan, you'll feel right at home. Scaffold controllers, models, views, migrations, and more with a single command.

<a name="installation"></a>
## Installation

The Magic CLI ships as an `fluttersdk_artisan` plugin bundled with the `magic` package, which exposes its own `artisan` executable. There is no separate install step: run commands via that executable. (If your app sets up its own aggregated artisan dispatcher, the same commands are available there too.)

```bash
dart run magic:artisan <command> [arguments] [options]
```

Magic ships the `artisan` executable in its `pubspec.yaml`, so `dart run magic:artisan` works from any project that depends on magic, with no global activation or package-name substitution.

<a name="project-setup"></a>
## Project Setup

<a name="install"></a>
### install

Initializes Magic in an existing Flutter project with the recommended directory structure and configuration.

```bash
dart run magic:artisan magic:install
```

This command:
1. Creates the directory structure (`lib/app/`, `lib/config/`, `lib/routes/`, etc.)
2. Generates configuration files with sensible defaults (app, routing, view are always created; others are optional)
3. Creates starter service providers (`AppServiceProvider`, `RouteServiceProvider`)
4. Writes `lib/main.dart` with Magic bootstrap
5. Creates `.env` and `.env.example` files
6. Registers `.env` as a Flutter asset in `pubspec.yaml`
7. Downloads `sqlite3.wasm` for web platform support (when database is enabled)

#### Excluding Features

You can exclude features you don't need with `--without-*` flags:

```bash
dart run magic:artisan magic:install --without-database
dart run magic:artisan magic:install --without-auth --without-cache
```

| Flag | What it skips |
|------|---------------|
| `--without-auth` | Auth config, `VaultServiceProvider`, `AuthServiceProvider` |
| `--without-database` | Database directories, `config/database.dart`, `DatabaseServiceProvider`, web SQLite setup |
| `--without-network` | `config/network.dart`, `NetworkServiceProvider` |
| `--without-cache` | `config/cache.dart`, `CacheServiceProvider` |
| `--without-localization` | `assets/lang/` directory, `LocalizationServiceProvider` |
| `--without-logging` | `config/logging.dart` |
| `--without-broadcasting` | `config/broadcasting.dart`, `BroadcastServiceProvider` |

#### Installing the debug tooling in one step

The optional debug trio (`magic_devtools` + `fluttersdk_dusk` + `fluttersdk_telescope`) gives you the LLM-agent E2E driver (Dusk) and the runtime inspector (Telescope). Pass `--with-devtools` to wire all three in a single command instead of the manual multi-step bootstrap:

```bash
dart run magic:artisan magic:install --with-devtools
```

When set, after the core install completes the command:

1. Adds `magic_devtools`, `fluttersdk_dusk`, and `fluttersdk_telescope` to `dependencies` (not `dev_dependencies`: `lib/main.dart` imports them, and the `kDebugMode` gate tree-shakes the subsystem out of release builds).
2. Wires the runtime setup into `lib/main.dart` under `kDebugMode`: `DuskPlugin.install()` and `TelescopePlugin.install()` (plus its `ExceptionWatcher` + `DumpWatcher`) before `Magic.init()`, then `MagicDuskIntegration.install()` and `MagicTelescopeIntegration.install()` after it.

The wiring is idempotent: re-running `magic:install --with-devtools` never duplicates the blocks or the dependency entries. Run `flutter pub get` afterwards, then `dart run magic:artisan mcp:install` to surface the Dusk/Telescope MCP tools.

<a name="keygenerate"></a>
### key:generate

Generates a random 32-byte encryption key for your application:

```bash
dart run magic:artisan key:generate
```

Updates your `.env` file with:

```
APP_KEY=base64:randomGeneratedKey...
```

#### Options

| Option | Description |
|--------|-------------|
| `--show` | Display the key in the terminal instead of writing to `.env` |

<a name="make-commands"></a>
## Make Commands

All `make:*` commands support the `--force` flag to overwrite existing files. Nested paths are supported via slash syntax (e.g., `Admin/Dashboard`), which creates subdirectories automatically.

Commands that auto-append a suffix (Controller, View, Factory, Seeder, Policy, ServiceProvider, Request, Repository, FormObject) handle duplicates gracefully: `make:controller UserController` will not produce `UserControllerController`.

`make:controller`, `make:view`, `make:repository`, `make:action`, `make:form` and `make:request` accept `--test`, which chains [make:test](#maketest) so the matching test lands in the same run. `--force` on the command forwards to the chained test, and a refused test write fails the command with exit 1.

<a name="makeresource"></a>
### make:resource

Scaffolds a full CRUD vertical for one model, magic's analogue of Laravel's `make:model --all`:

```bash
dart run magic:artisan make:resource Monitor
dart run magic:artisan make:resource Monitor --no-views
dart run magic:artisan make:resource Monitor --no-model
dart run magic:artisan make:resource Monitor --force
```

For `Monitor` it writes, each through its own generator:

- the model and its factory (kept when they already exist)
- `MonitorRepository`
- the `CreateMonitor`, `UpdateMonitor` and `DeleteMonitor` actions under `lib/app/actions/monitors/`
- `StoreMonitorRequest` and `UpdateMonitorRequest`
- `MonitorFormObject` (the `--resource` form)
- `MonitorController` (`--resource --actions`)
- the `MonitorsListView` and `MonitorFormView` views
- tests for the actions, the form and the controller

The run is all-or-nothing: every target path is checked first, and any clash other than a kept model or factory fails the run with nothing written unless `--force` is passed. The index and create route lines are printed for your `RouteServiceProvider.boot()`; the command never edits it.

#### Options

| Option | Description |
|--------|-------------|
| `--no-views` | Stop after the data and write layers (no views, no printed routes) |
| `--no-model` | Leave the model and factory out |

<a name="makemodel"></a>
### make:model

Creates an Eloquent-style model with optional related files:

```bash
dart run magic:artisan make:model User
dart run magic:artisan make:model Post --migration --controller --factory
dart run magic:artisan make:model Comment -mcf
dart run magic:artisan make:model Product -mcfsp
dart run magic:artisan make:model Order --all
```

#### Options

| Option | Shortcut | Description |
|--------|----------|-------------|
| `--migration` | `-m` | Create a database migration |
| `--controller` | `-c` | Create a controller |
| `--factory` | `-f` | Create a model factory |
| `--seeder` | `-s` | Create a database seeder |
| `--policy` | `-p` | Create an authorization policy |
| `--all` | `-a` | Create migration, seeder, factory, policy, repository, and resource controller |

> [!NOTE]
> The `-mcfsp` shorthand combines all five flags: migration, controller, factory, seeder, and policy. The `--all` flag also writes the model's repository and makes the controller a `--resource --model=<Model>` controller reading through it. For the write layer and views as well, use [make:resource](#makeresource).

The model carries a static `fromMap(Map<String, dynamic>)` that hydrates it from raw API data. The command exits 1 when the model already exists and `--force` was not passed, without generating any companion.

**Output:** `lib/app/models/<name>.dart`

<a name="makecontroller"></a>
### make:controller

Creates a `MagicController` with a `Magic.findOrPut` singleton accessor that implements `SessionScoped`:

```bash
dart run magic:artisan make:controller User
dart run magic:artisan make:controller UserController
dart run magic:artisan make:controller Admin/Dashboard
dart run magic:artisan make:controller Post --resource
dart run magic:artisan make:controller Post --resource --model=Post --actions
dart run magic:artisan make:controller Uptime --broadcasts --timers --test
```

A `--resource` controller owns the read state as one `RepositoryQuery` over `<Model>Repository`: it exposes `items`, `ensureFresh()` (for a view's `RefetchesOnMount`) and `reload()`, and its `resetForSession()` clears the repository and refetches. Writes belong on a `MagicAction`, not on the controller.

#### Options

| Option | Shortcut | Description |
|--------|----------|-------------|
| `--resource` | `-r` | Own a `RepositoryQuery` over the model's repository |
| `--model` | `-m` | The model a `--resource` controller reads (defaults to the controller's own name) |
| `--actions` | | Mix in `RunsActions` |
| `--broadcasts` | | Mix in `ListensToBroadcasts`, with an empty `listeners` map |
| `--timers` | | Mix in `OwnsTimers` |
| `--validates` | | Mix in `ValidatesRequests` and `CollapsesIndexedErrorKeys` |
| `--test` | | Also write the matching controller test |

The mixins are always written in one fixed order, whatever order the flags were passed in.

**Output:** `lib/app/controllers/<name>_controller.dart`

<a name="makeview"></a>
### make:view

Creates a view class: a `StatelessWidget` by default, or a `MagicStatefulView<T>` bound to a controller:

```bash
dart run magic:artisan make:view Login
dart run magic:artisan make:view LoginView
dart run magic:artisan make:view Auth/Register
dart run magic:artisan make:view Dashboard --stateful
dart run magic:artisan make:view Monitor --controller=Monitor
dart run magic:artisan make:view Monitors/List --controller=Monitor --list --form=MonitorFormObject
```

#### Options

| Option | Description |
|--------|-------------|
| `--stateful` | Bind a `MagicStatefulView` to the controller derived from the view's name (`Dashboard` -> `DashboardController`), which has to exist |
| `--controller` | Bind the view to this controller (suffix optional); implies `--stateful` |
| `--list` | Add `RefetchesOnMount`; expects a `--resource` controller, which exposes `ensureFresh()` |
| `--form` | Add a State-owned form object field (suffix optional), disposed in `onClose`; implies `--stateful` |
| `--test` | Also write the matching view test |

**Output:** `lib/resources/views/<name>_view.dart`

<a name="makerepository"></a>
### make:repository

Creates a `Repository<T>` subclass with a static `instance`, the row cache every screen reading the model shares:

```bash
dart run magic:artisan make:repository Monitor
dart run magic:artisan make:repository MonitorRepository --test
```

**Output:** `lib/app/repositories/<name>_repository.dart`

<a name="makeaction"></a>
### make:action

Creates a `MagicAction`, the one place a write lives:

```bash
dart run magic:artisan make:action PauseMonitor
dart run magic:artisan make:action Monitors/PauseMonitor --test
dart run magic:artisan make:action Monitors/CreateMonitor --kind=create --model=Monitor
dart run magic:artisan make:action Monitors/UpdateMonitor --kind=update --model=Monitor
dart run magic:artisan make:action Monitors/DeleteMonitor --kind=delete --model=Monitor
```

Without `--kind` the action is an empty `handle()` skeleton. The write kinds:

- `create` fills and saves a new model from a validated field map.
- `update` takes `({String id, Map<String, dynamic> fields})`, saves the edit and writes it into `<Model>Repository`, answering null when the id no longer resolves.
- `delete` deletes the model and evicts it from `<Model>Repository`.

A refused save throws `ActionRequestFailed` (a `ValidationException` when the model carries field errors).

#### Options

| Option | Description |
|--------|-------------|
| `--kind` | `create`, `update` or `delete`; requires `--model` |
| `--model` | The model the action writes |
| `--test` | Also write the matching action test |

**Output:** `lib/app/actions/<name>.dart`

<a name="makeform"></a>
### make:form

Creates a `MagicFormObject` (the `FormObject` suffix is appended; form widgets keep the `Form` name):

```bash
dart run magic:artisan make:form Monitor
dart run magic:artisan make:form Monitor --request=StoreMonitorRequest
dart run magic:artisan make:form Monitor --resource=Monitor
```

`--resource=<Model>` writes the full create/edit contract: an `editing` field, `initial` seeded from `editing?.toArray()`, a `request` choosing the Store or Update request, and a `persist` running `Create<Model>` or `Update<Model>`. After a create it reloads the `--resource` `<Model>Controller`, so it expects the controller [make:resource](#makeresource) writes beside it.

#### Options

| Option | Description |
|--------|-------------|
| `--request` | The `FormRequest` class the form validates against |
| `--resource` | The model the form creates and edits |
| `--test` | Also write the matching form test |

**Output:** `lib/app/forms/<name>_form_object.dart`

<a name="maketest"></a>
### make:test

Creates a test skeleton mirroring where another generator writes its class, from `lib/` to `test/`:

```bash
dart run magic:artisan make:test Monitor --kind=controller
dart run magic:artisan make:test Monitors/PauseMonitor --kind=action
dart run magic:artisan make:test Monitor --kind=repository --force
```

The test imports the class as `package:<name>/...`, with `<name>` read from the project's `pubspec.yaml`.

#### Options

| Option | Description |
|--------|-------------|
| `--kind` | `controller`, `action`, `form`, `repository`, `request`, `view` or `unit` |

**Output:** for example `test/app/controllers/<name>_controller_test.dart`

<a name="makemigration"></a>
### make:migration

Creates a timestamped database migration file:

```bash
dart run magic:artisan make:migration create_users_table
dart run magic:artisan make:migration create_users_table --create=users
dart run magic:artisan make:migration add_email_to_users --table=users
```

#### Options

| Option | Shortcut | Description |
|--------|----------|-------------|
| `--create` | `-c` | The table to be created (selects the create stub) |
| `--table` | `-t` | The table to migrate |

**Output:** `lib/database/migrations/m_YYYYMMDDHHMMSS_<name>.dart`

<a name="makeseeder"></a>
### make:seeder

Creates a database seeder:

```bash
dart run magic:artisan make:seeder User
dart run magic:artisan make:seeder UserSeeder
```

**Output:** `lib/database/seeders/<name>_seeder.dart`

<a name="makefactory"></a>
### make:factory

Creates a model factory for generating fake data:

```bash
dart run magic:artisan make:factory User
dart run magic:artisan make:factory UserFactory
```

**Output:** `lib/database/factories/<name>_factory.dart`

<a name="makepolicy"></a>
### make:policy

Creates an authorization policy:

```bash
dart run magic:artisan make:policy Post
dart run magic:artisan make:policy PostPolicy
dart run magic:artisan make:policy Post --model=Post
dart run magic:artisan make:policy Admin/Dashboard
```

#### Options

| Option | Shortcut | Description |
|--------|----------|-------------|
| `--model` | `-m` | The model the policy applies to |

**Output:** `lib/app/policies/<name>_policy.dart`

<a name="makeprovider"></a>
### make:provider

Creates a service provider class with `register()` and `boot()` stubs:

```bash
dart run magic:artisan make:provider Payment
dart run magic:artisan make:provider PaymentServiceProvider
```

The `ServiceProvider` suffix is appended automatically when omitted.

**Output:** `lib/app/providers/<name>_service_provider.dart`

<a name="makemiddleware"></a>
### make:middleware

Creates a middleware class:

```bash
dart run magic:artisan make:middleware EnsureAuthenticated
dart run magic:artisan make:middleware Admin/RoleCheck
```

**Output:** `lib/app/middleware/<name>.dart`

<a name="makeenum"></a>
### make:enum

Creates a string-backed enum with `fromValue()` factory and `selectOptions` getter:

```bash
dart run magic:artisan make:enum MonitorType
dart run magic:artisan make:enum Status/OrderStatus
dart run magic:artisan make:enum IncidentSeverity --wire
```

`--wire` writes an enum mirroring a backend string value instead: an `unknown` fallback case, a `fromWire()` factory that never throws on an unrecognised value, and a `trans()`-backed `label` getter.

**Output:** `lib/app/enums/<name>.dart`

<a name="makeevent"></a>
### make:event

Creates a dispatchable event class that extends `MagicEvent`:

```bash
dart run magic:artisan make:event UserLoggedIn
dart run magic:artisan make:event Auth/TokenRefreshed
```

**Output:** `lib/app/events/<name>.dart`

<a name="makelistener"></a>
### make:listener

Creates an event listener class that extends `MagicListener<TEvent>`:

```bash
dart run magic:artisan make:listener AuthRestore
dart run magic:artisan make:listener AuthRestore --event=UserLoggedInEvent
dart run magic:artisan make:listener Auth/RestoreSession
```

#### Options

| Option | Shortcut | Description |
|--------|----------|-------------|
| `--event` | `-e` | The event class the listener handles (defaults to `MagicEvent`) |

**Output:** `lib/app/listeners/<name>.dart`

<a name="makerequest"></a>
### make:request

Creates a `FormRequest` subclass with a `const` constructor and a `rules()` override, which `MagicFormObject.request` and `ValidatesRequests.validateRequest` both accept:

```bash
dart run magic:artisan make:request StoreMonitor
dart run magic:artisan make:request StoreMonitorRequest --test
```

The `Request` suffix is appended automatically when omitted.

**Output:** `lib/app/validation/requests/<name>_request.dart`

<a name="makelang"></a>
### make:lang

Creates a language JSON file:

```bash
dart run magic:artisan make:lang tr
dart run magic:artisan make:lang es
dart run magic:artisan make:lang de --from=tr
```

`--from=<locale>` (default `en`) copies that file's key tree with each value verbatim, a complete catalogue for a translator; when it does not exist the new file is `{}`.

**Output:** `assets/lang/<locale>.json`

<a name="makecomponent"></a>
### make:component

Scaffolds an atomic component folder under `lib/ui/components/<name>/`, plus its widget test:

```bash
dart run magic:artisan make:component Avatar
dart run magic:artisan make:component Avatar --variants=intent,size
dart run magic:artisan make:component Panel --slots
dart run magic:artisan make:component Badge --no-preview
```

**Output** (for `Avatar`):

- `lib/ui/components/avatar/avatar.dart` (`class Avatar`, unprefixed PascalCase)
- `lib/ui/components/avatar/avatar.recipe.dart` (a `WindRecipe`, or a `WindSlotRecipe` under `--slots`, seeded with the requested `--variants` axes)
- `lib/ui/components/avatar/index.dart` (re-exports the component + recipe, NOT the preview)
- `test/ui/components/avatar/avatar_test.dart` (imports the barrel with a prefix, so a name like `Badge` stays unambiguous)
- `lib/ui/components/avatar/avatar.preview.dart` (a single public `AvatarPreview` matrix), only when the project already keeps a preview catalogue

The preview file, and the chained `previews:refresh` that lands it in `_previews.g.dart`, are written only when the project already has a `*.preview.dart` file or a `_previews.g.dart` index under `lib/`. `--preview` or `--no-preview` overrides that detection.

#### Options

- `--variants=a,b`: seed the named variant axes into the recipe (values left empty to fill in).
- `--slots`: scaffold a multi-part `WindSlotRecipe` instead of a single-element `WindRecipe`.
- `--preview` / `--no-preview`: force the preview file on or off.
- `--force`: overwrite an existing component.

<a name="previewsrefresh"></a>
### previews:refresh

Regenerates the dev-only preview catalog index from `*.preview.dart` files:

```bash
dart run magic:artisan previews:refresh
dart run magic:artisan previews:refresh --path=lib/ui/components
```

**Output:** `<scan-dir>/_previews.g.dart` (default scan dir `lib`).

Each `*.preview.dart` file must declare exactly ONE public `*Preview` class. The command validates the class name, fails fast on a slug collision, sorts deterministically, and writes atomically. The generated file returns a `List<PreviewEntry>` from the `previewEntries()` function (never a top-level const list) so the catalog tree-shakes from release builds. Feed it to the catalog via `MagicPreview.register(previewEntries())`.

#### Options

- `--path=DIR`: directory to scan for `*.preview.dart` files (default `lib`).

<a name="designsync"></a>
### design:sync

Generates the wind theme (semantic aliases + brand seed) from a `DESIGN.md`:

```bash
dart run magic:artisan design:sync
dart run magic:artisan design:sync --input=DESIGN.md --output=lib/config/wind_theme.g.dart
```

**Output:** a Dart source file exposing a `Map<String, String> designAliases` and a `Map<String, MaterialColor> designColors`. The aliases map carries the 17 property-prefixed semantic keys (`bg-surface`, `text-fg`, `border-color-border`, ...) with arbitrary-hex light + `dark:` pairs (`'bg-surface': 'bg-[#f9f9ff] dark:bg-[#0f1419]'`), drop-in for `WindThemeData(aliases: designAliases)`. The brand `primary` `MaterialColor` carries a generated 50-900 ramp (seeded from the DESIGN.md `primary` light hex) for `WindThemeData.toThemeData()` Material interop.

The command is idempotent (byte-identical output on re-run for an unchanged DESIGN.md) and writes atomically via `.tmp` + rename. Do not hand-edit the generated file; re-run `design:sync` instead.

#### Options

- `--input=PATH`: path to the DESIGN.md source, relative to the project root (default `DESIGN.md`).
- `--output=PATH`: path for the generated wind theme file (default `lib/config/wind_theme.g.dart`).

<a name="designlint"></a>
### design:lint

Validates a `DESIGN.md` against the design rules:

```bash
dart run magic:artisan design:lint
dart run magic:artisan design:lint --input=DESIGN.md
```

The command exits nonzero only on an error-severity finding (a broken reference). Warnings and info notes are reported but do not fail the lint. Rules:

- **broken-ref** (error): a component references a token (`{colors.x}`, `{rounded.x}`, `{spacing.x}`) that does not resolve.
- **missing-primary** (warning): colors are defined but `primary` is absent.
- **unknown-key** (warning): a top-level YAML key looks like a typo of a schema key. The single-file `dark:` overlay lives inside `colors`, so it is never flagged.
- **section-order** (warning): markdown `##` sections appear out of canonical order.
- **missing-sections** (info): the optional `spacing` / `rounded` groups are absent.
- **orphaned-tokens** (warning): a custom color token is defined but never referenced by any component (Material Design 3 baseline families are exempt).
- **contrast-ratio** (warning): a component `backgroundColor` / `textColor` pair falls below the WCAG AA minimum of 4.5:1.

#### Options

- `--input=PATH`: path to the DESIGN.md to validate, relative to the project root (default `DESIGN.md`).

<a name="designmd-format"></a>
### DESIGN.md format

`DESIGN.md` is the single source of truth for the app theme: a YAML front matter (machine-readable design tokens) followed by a markdown body (human-readable rationale; ignored by `design:sync`).

```markdown
---
name: Acme
colors:
  surface:
    light: "#f9f9ff"   # single-file dark: overlay per role
    dark: "#0f1419"
  fg:
    light: "#151c27"
    dark: "#e6e9f0"
  primary:
    light: "#7c3aed"   # the brand seed for the MaterialColor ramp
    dark: "#a78bfa"
  on-primary: "#ffffff"  # a bare hex is light-only (dark mirrors light)
typography:
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
rounded:
  md: 8px
spacing:
  md: 16px
components:
  button-primary:
    backgroundColor: "{colors.primary}"   # {group.token} reference
    textColor: "{colors.on-primary}"
    rounded: "{rounded.md}"
    padding: "{spacing.md}"
---

## Overview
...
## Colors
...
```

Each color role is either a bare hex scalar (light only; dark mirrors light) or a `{ light, dark }` overlay map. The 17 semantic roles map onto the wind alias keys as: `surface`/`surface-container`/`surface-container-high` -> `bg-surface*`; `fg` (or `on-surface`)/`fg-muted`/`fg-disabled` -> `text-fg*`; `primary`/`on-primary`/`primary-container` -> `bg-primary` / `text-on-primary` / `bg-primary-container`; `accent` -> `bg-accent`; `border`/`border-subtle` -> `border-color-border*`; `destructive`/`on-destructive`/`destructive-container` -> `bg-destructive` / `text-on-destructive` / `bg-destructive-container`; `success`/`warning` -> `bg-success` / `bg-warning`.

This is a wind-flavored superset of the open DESIGN.md format: the single-file `dark:` overlay is the deliberate divergence that lets one document drive both light and dark wind aliases.
