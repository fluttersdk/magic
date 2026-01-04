# Magic CLI

- [Introduction](#introduction)
- [Installation](#installation)
- [Project Setup](#project-setup)
    - [magic init](#magic-init)
    - [key:generate](#keygenerate)
- [Make Commands](#make-commands)
    - [make:model](#makemodel)
    - [make:controller](#makecontroller)
    - [make:view](#makeview)
    - [make:migration](#makemigration)
    - [make:seeder](#makeseeder)
    - [make:factory](#makefactory)
    - [make:policy](#makepolicy)
    - [make:lang](#makelang)
- [Inspection Commands](#inspection-commands)
    - [route:list](#routelist)
    - [config:list](#configlist)
    - [config:get](#configget)
- [Magic Boost (AI Integration)](#magic-boost)
    - [Setup](#setup)
    - [MCP Tools](#mcp-tools)
    - [IDE Configuration](#ide-configuration)

<a name="introduction"></a>
## Introduction

Magic CLI is the Artisan-like command-line tool for Magic. If you've used Laravel's Artisan, you'll feel right at home. Scaffold controllers, models, views, migrations, and more with a single command.

<a name="installation"></a>
## Installation

Install Magic CLI globally via Dart's package manager:

```bash
dart pub global activate fluttersdk_magic_cli
```

> [!NOTE]
> Ensure `~/.pub-cache/bin` is in your system PATH to use the `magic` command globally.

Verify installation:

```bash
magic --version
```

<a name="project-setup"></a>
## Project Setup

<a name="magic-init"></a>
### magic init

Initializes Magic in an existing Flutter project with the recommended directory structure and configuration.

```bash
cd my_flutter_app
magic init
```

This command:
1. Adds `fluttersdk_magic` dependency to `pubspec.yaml`
2. Creates directory structure (`app/`, `config/`, `routes/`, etc.)
3. Generates configuration files with sensible defaults
4. Sets up service providers
5. Generates an application encryption key

#### Excluding Features

You can exclude features you don't need:

```bash
# Skip specific features
magic init --without-database
magic init --without-cache
magic init --without-auth
magic init --without-events
magic init --without-localization

# Combine exclusions
magic init --without-database --without-events
```

<a name="keygenerate"></a>
### key:generate

Generates a random encryption key for your application:

```bash
magic key:generate
```

Updates your `.env` file with:

```
APP_KEY=base64:randomGeneratedKey...
```

<a name="make-commands"></a>
## Make Commands

<a name="makemodel"></a>
### make:model

Creates an Eloquent-style model with optional related files:

```bash
magic make:model User
magic make:model Post --migration --controller --factory
magic make:model Comment -mcf  # Shorthand
magic make:model Product --all  # Create everything
```

#### Options

| Option | Shortcut | Description |
|--------|----------|-------------|
| `--migration` | `-m` | Create a database migration |
| `--controller` | `-c` | Create a controller |
| `--factory` | `-f` | Create a model factory |
| `--seeder` | `-s` | Create a database seeder |
| `--policy` | `-p` | Create an authorization policy |
| `--all` | `-a` | Create all related files |

**Output:** `lib/app/models/<name>.dart`

<a name="makecontroller"></a>
### make:controller

Creates a controller class:

```bash
magic make:controller User
magic make:controller UserController  # Explicit naming
magic make:controller Admin/Dashboard  # Nested path
```

#### Options

| Option | Shortcut | Description |
|--------|----------|-------------|
| `--stateful` | `-s` | Include `MagicStateMixin` for state management |
| `--resource` | `-r` | Create resource controller with CRUD methods and views |

**Output:** `lib/app/controllers/<name>_controller.dart`

<a name="makeview"></a>
### make:view

Creates a view class:

```bash
magic make:view Login
magic make:view LoginView  # Explicit naming
magic make:view Auth/Register  # Nested path
```

#### Options

| Option | Description |
|--------|-------------|
| `--stateful` | Create stateful view with `MagicFormData` support |

**Output:** `lib/resources/views/<name>_view.dart`

<a name="makemigration"></a>
### make:migration

Creates a database migration file:

```bash
magic make:migration create_users_table
magic make:migration add_email_to_users_table
```

#### Options

| Option | Shortcut | Description |
|--------|----------|-------------|
| `--create` | `-c` | The table to be created |
| `--table` | `-t` | The table to migrate |

**Output:** `lib/database/migrations/<timestamp>_<name>.dart`

<a name="makeseeder"></a>
### make:seeder

Creates a database seeder:

```bash
magic make:seeder UserSeeder
```

**Output:** `lib/database/seeders/<name>.dart`

<a name="makefactory"></a>
### make:factory

Creates a model factory for generating fake data:

```bash
magic make:factory User
magic make:factory UserFactory  # Explicit naming
```

**Output:** `lib/database/factories/<name>_factory.dart`

<a name="makepolicy"></a>
### make:policy

Creates an authorization policy:

```bash
magic make:policy Post
magic make:policy Comment --model=Comment
```

#### Options

| Option | Shortcut | Description |
|--------|----------|-------------|
| `--model` | `-m` | The model that the policy applies to |

**Output:** `lib/app/policies/<name>_policy.dart`

<a name="makelang"></a>
### make:lang

Creates a language JSON file:

```bash
magic make:lang tr
magic make:lang es
magic make:lang de
```

**Output:** `assets/lang/<locale>.json`

<a name="inspection-commands"></a>
## Inspection Commands

<a name="routelist"></a>
### route:list

Lists all registered routes in your application:

```bash
magic route:list
```

**Output:**

```
+---------------------+------------+----------+
| URI                 | Middleware | File     |
+---------------------+------------+----------+
| /                   | auth       | app.dart |
| /auth/login         | -          | auth.dart|
| /dashboard          | auth       | app.dart |
| /settings/team      | auth       | app.dart |
+---------------------+------------+----------+
```

<a name="configlist"></a>
### config:list

Lists all configuration files and their keys:

```bash
magic config:list
magic config:list --verbose  # Show key previews
```

<a name="configget"></a>
### config:get

Gets a specific configuration value using dot notation:

```bash
magic config:get app.name
# Output: My App

magic config:get network.drivers.api.base_url
# Output: http://localhost:8000/api/v1

magic config:get app.url --show-source
# Output: http://localhost (from: .env)
```

**Priority:** Project config → `.env` → Framework defaults

<a name="magic-boost"></a>
## Magic Boost (AI Integration)

Magic Boost provides AI-powered development tools through MCP (Model Context Protocol), allowing AI assistants like Claude to understand your Magic project.

<a name="setup"></a>
### Setup

Install Boost in your project:

```bash
magic boost:install
```

This will:
- Create `.magic/guidelines/` with framework documentation
- Configure MCP server in your IDE (Cursor, VS Code)
- Generate project-aware context for AI assistants

### Commands

| Command | Description |
|---------|-------------|
| `boost:install` | Setup AI guidelines + MCP config |
| `boost:mcp` | Run the MCP server (stdio) |
| `boost:update` | Refresh guidelines to latest version |

<a name="mcp-tools"></a>
### MCP Tools

The MCP server exposes these tools to AI assistants:

| Tool | Description |
|------|-------------|
| `app_info` | Get pubspec.yaml info (name, version, dependencies) |
| `list_routes` | List all application routes |
| `get_config` | Read config values with dot notation |
| `validate_wind` | Validate Wind UI utility classes |
| `search_docs` | Search Magic documentation |

<a name="ide-configuration"></a>
### IDE Configuration

After running `boost:install`, your IDE's MCP config is automatically updated:

**`.cursor/mcp.json` or `.vscode/mcp.json`:**

```json
{
  "mcpServers": {
    "magic-boost": {
      "command": "dart",
      "args": ["run", "fluttersdk_magic_cli:magic", "boost:mcp"],
      "cwd": "/path/to/your/project"
    }
  }
}
```

### Generated Guidelines

After installation, `.magic/guidelines/` contains:

```
.magic/
└── guidelines/
    ├── core.md      # Core Magic framework
    ├── wind.md      # Wind UI system
    ├── eloquent.md  # Eloquent models
    └── routing.md   # Routing system
```

These files provide context for AI assistants about your project's architecture and coding conventions.

> [!TIP]
> Run `magic boost:update` periodically to get the latest framework guidelines.
