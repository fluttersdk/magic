# Magic CLI

The Magic CLI is an `fluttersdk_artisan` plugin that ships as part of the magic package, providing `magic:install`, `key:generate`, and 14 `make:*` scaffold commands through magic's bundled `artisan` executable (`dart run magic:artisan`).

- [Introduction](#introduction)
- [Installation](#installation)
- [Project Setup](#project-setup)
    - [install](#install)
    - [key:generate](#keygenerate)
- [Make Commands](#make-commands)
    - [make:model](#makemodel)
    - [make:controller](#makecontroller)
    - [make:view](#makeview)
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
dart run magic:artisan magic:install --without-auth --without-events
```

| Flag | What it skips |
|------|---------------|
| `--without-auth` | Auth config, `VaultServiceProvider`, `AuthServiceProvider` |
| `--without-database` | Database directories, `config/database.dart`, `DatabaseServiceProvider`, web SQLite setup |
| `--without-network` | `config/network.dart`, `NetworkServiceProvider` |
| `--without-cache` | `config/cache.dart`, `CacheServiceProvider` |
| `--without-events` | `lib/app/events/` and `lib/app/listeners/` directories |
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

Commands that auto-append a suffix (Controller, View, Factory, Seeder, Policy, ServiceProvider, Request) handle duplicates gracefully — `make:controller UserController` will not produce `UserControllerController`.

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
| `--all` | `-a` | Create migration, seeder, factory, policy, and resource controller |

> [!NOTE]
> The `-mcfsp` shorthand combines all five flags: migration, controller, factory, seeder, and policy. The `--all` flag does the same but also makes the controller a resource controller with CRUD methods.

**Output:** `lib/app/models/<name>.dart`

<a name="makecontroller"></a>
### make:controller

Creates a controller class:

```bash
dart run magic:artisan make:controller User
dart run magic:artisan make:controller UserController
dart run magic:artisan make:controller Admin/Dashboard
dart run magic:artisan make:controller Post --resource
dart run magic:artisan make:controller Post --resource --model=Post
```

#### Options

| Option | Shortcut | Description |
|--------|----------|-------------|
| `--resource` | `-r` | Generate a resource controller with CRUD methods |
| `--model` | `-m` | The model the controller applies to |

**Output:** `lib/app/controllers/<name>_controller.dart`

<a name="makeview"></a>
### make:view

Creates a view class:

```bash
dart run magic:artisan make:view Login
dart run magic:artisan make:view LoginView
dart run magic:artisan make:view Auth/Register
dart run magic:artisan make:view Dashboard --stateful
```

#### Options

| Option | Description |
|--------|-------------|
| `--stateful` | Generate a stateful view with lifecycle hooks |

**Output:** `lib/resources/views/<name>_view.dart`

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
```

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

Creates a form request class with a typed `rules()` method for request validation:

```bash
dart run magic:artisan make:request StoreMonitor
dart run magic:artisan make:request StoreMonitorRequest
```

The `Request` suffix is appended automatically when omitted.

**Output:** `lib/app/validation/requests/<name>_request.dart`

<a name="makelang"></a>
### make:lang

Creates a language JSON file:

```bash
dart run magic:artisan make:lang tr
dart run magic:artisan make:lang es
dart run magic:artisan make:lang de
```

**Output:** `assets/lang/<locale>.json`

<a name="makecomponent"></a>
### make:component

Scaffolds an atomic 4-file component folder under `lib/ui/components/<name>/`:

```bash
dart run magic:artisan make:component Avatar
dart run magic:artisan make:component Avatar --variants=intent,size
dart run magic:artisan make:component Panel --slots
```

**Output** (for `Avatar`):

- `lib/ui/components/avatar/avatar.dart` (`class Avatar`, unprefixed PascalCase)
- `lib/ui/components/avatar/avatar.recipe.dart` (a `WindRecipe`, or a `WindSlotRecipe` under `--slots`, seeded with the requested `--variants` axes)
- `lib/ui/components/avatar/avatar.preview.dart` (a single public `AvatarPreview` matrix)
- `lib/ui/components/avatar/index.dart` (re-exports the component + recipe, NOT the preview)

After scaffolding, `make:component` chains `previews:refresh` so the new preview lands in `_previews.g.dart` automatically.

#### Options

- `--variants=a,b`: seed the named variant axes into the recipe (values left empty to fill in).
- `--slots`: scaffold a multi-part `WindSlotRecipe` instead of a single-element `WindRecipe`.
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
