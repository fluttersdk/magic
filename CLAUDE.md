# Magic Framework

Laravel-inspired Flutter framework with Facades, Eloquent ORM, Service Providers, and IoC Container.

**Version:** 1.0.0-alpha.4 · **Dart:** >=3.11.0 · **Flutter:** >=3.41.0

## Commands

| Command | Description |
|---------|-------------|
| `flutter test` | Run all tests |
| `flutter test test/<module>` | Run specific module tests |
| `dart analyze` | Static analysis (zero warnings required) |
| `dart format .` | Format all code |
| `dart fix --apply` | Auto-fix issues |
| `cd example && flutter run` | Run example app |
| `dart doc .` | Generate API docs |
| `dart run magic:magic <command>` | Run Magic CLI (no global activate needed) |

## Architecture

**Pattern**: Service Provider + IoC Container + Facade (Laravel-inspired)

```
lib/
├── magic.dart    # Barrel export (public API)
├── config/                  # Default configs (app, auth, cache, database, view)
└── src/
    ├── foundation/          # MagicApp (IoC), Magic (bootstrap), ConfigRepository, Env
    ├── facades/             # 16 facades: Auth, Cache, Config, Crypt, DB, Event, Gate, Http, Lang, Launch, Log, Pick, Route, Schema, Storage, Vault
    ├── auth/                # AuthManager, guards (Bearer, BasicAuth, ApiKey), events
    ├── cache/               # CacheManager, drivers (memory, file)
    ├── database/            # Eloquent ORM, QueryBuilder, migrations, seeders, factories
    ├── encryption/          # EncryptionServiceProvider (NOT auto-registered)
    ├── events/              # EventDispatcher (pub/sub)
    ├── http/                # MagicController, middleware pipeline, Kernel
    ├── concerns/            # ValidatesRequests mixin (import from here, not http/)
    ├── localization/        # Translator (JSON loaders, :key placeholders)
    ├── logging/             # LogManager, drivers (console, stack)
    ├── network/             # Dio wrapper, MagicResponse
    ├── routing/             # MagicRouter (GoRouter wrapper)
    ├── security/            # Vault (flutter_secure_storage)
    ├── storage/             # StorageManager, local disk ops
    ├── support/             # ServiceProvider base, Carbon date helper
    ├── validation/          # Rules-based validator
    └── ui/                  # MagicView, MagicForm, MagicFeedback, MagicResponsiveView
doc/                         # Framework documentation (basics, database, security, etc.)
```

**Lifecycle:** `Magic.init()` → `Env.load()` → configFactories execute → providers `register()` → providers `boot()` → router pre-build → app ready

**Resolution:** Facades use static singletons or container `Magic.make<T>(key)`

## Post-Change Checklist

After ANY source code change, sync **before committing**:

1. **`CHANGELOG.md`** — Add entry under `[Unreleased]` section (create section if missing)
2. **`doc/`** — Update relevant documentation files (match existing format exactly)
3. **`README.md`** — Update if new features, facades, or API changes affect the overview
4. **`skills/magic-framework/`** — Update SKILL.md and references if API, facades, or patterns changed
5. **`example/`** — Update or create example usage for changed/new features

## Development Flow (TDD)

This project follows strict **Test-Driven Development**. Every feature, fix, or refactor must go through the red-green-refactor cycle:

1. **Red** — Write a failing test that describes the expected behavior
2. **Green** — Write the minimum code to make the test pass
3. **Refactor** — Clean up while keeping tests green

**Rules:**
- No production code without a failing test first
- Run `flutter test` after every change — all 453+ tests must stay green
- Run `dart analyze` after every change — zero warnings, zero errors
- Run `dart format .` before committing — zero formatting issues
- `dart pub publish --dry-run` must pass before any release

**Verification cycle:** Edit → `flutter test` → `dart analyze` → repeat until green

## Testing

- `setUp()`: Always `MagicApp.reset()` + `Magic.flush()` — clears IoC and facade caches
- Mock via contract inheritance, not code generation — no mockito
- Tests mirror `lib/src/` structure in `test/`
- UI testing: `Magic.put<T>(controller)` in setUp to inject test controllers
- Integration tests in `test/integration/`

## Key Gotchas

| Mistake | Fix |
|---------|-----|
| Facade call before `Magic.init()` | Always `await Magic.init()` in `main()` first |
| Missing `Auth.manager.setUserFactory()` | Must call in boot phase — auth won't work without it |
| Forgetting test reset | `MagicApp.reset()` + `Magic.flush()` in every `setUp()` |
| `EncryptionServiceProvider` / `LaunchServiceProvider` | NOT auto-registered — add explicitly to config providers |
| `configFactories` vs `configs` param | Use `configFactories` for configs needing `Env.get()` |
| `Event.register()` takes factories | `List<Listener Function()>`, not listener instances |
| `routerConfig` before init | Only accessible after `Magic.init()` completes |
| `ValidatesRequests` import | Lives in `concerns/`, not `http/` |
| Web vs mobile DB | Web = in-memory SQLite, mobile = file-based |
| `MagicResponse.errors` format | Parses Laravel's `{"errors": {"field": ["msg"]}}` |

## Skills & Extensions

- **`skills/magic-framework/`** — Magic Framework skill for LLM agents. Teaches facades, Eloquent ORM, service providers, controllers, routing, and common anti-patterns.
- **Upstream sync:** When you modify any file under `skills/magic-framework/`, the same change MUST also be applied to the [`fluttersdk/ai`](https://github.com/fluttersdk/ai) repository (`skills/magic-framework/` path). Remind the user to sync after committing.

## CI

- `ci.yml`: push/PR → `flutter pub get` → `flutter analyze --no-fatal-infos` → `dart format --set-exit-if-changed` → `flutter test --coverage`
- `publish.yml`: git tag → validate (analyze + format + test) → auto-publish to pub.dev
