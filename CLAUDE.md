# Magic Framework

Laravel-inspired Flutter framework with Facades, Eloquent ORM, Service Providers, and IoC Container.

## Quick Reference

| Command | Description |
|---------|-------------|
| `dart analyze` | Check for issues |
| `dart format .` | Format code |
| `dart fix --apply` | Auto-fix issues |
| `flutter test` | Run all tests |
| `flutter test test/<path>` | Run specific test |
| `flutter pub get` | Install dependencies |
| `cd example && flutter run` | Run example app |
| `dart doc .` | Generate API docs |

<ARCHITECTURE>
## Architecture

**Pattern**: Service Provider + IoC Container + Facade (Laravel-inspired)

```
lib/
├── config/              # Default configs (app, auth, cache, database, view)
├── fluttersdk_magic.dart  # Barrel export
└── src/
    ├── facades/         # Static API: Auth, Cache, Config, DB, Event, HTTP, Log, Lang, Storage, Route, Schema, Gate, Crypt, Vault, Pick
    ├── foundation/      # IoC container (MagicApp), Magic bootstrap, ConfigRepository, Env
    ├── auth/            # AuthManager, guards (Bearer, BasicAuth, ApiKey), events
    ├── cache/           # CacheManager, drivers (memory, file)
    ├── database/        # Eloquent ORM, QueryBuilder, migrations, seeders, factories
    ├── encryption/      # EncryptionServiceProvider
    ├── events/          # EventDispatcher system
    ├── http/            # MagicController, middleware pipeline, Kernel
    ├── localization/    # Translator with loaders
    ├── logging/         # Log drivers (console, stack)
    ├── network/         # Dio HTTP wrapper
    ├── policies/        # Authorization policies
    ├── routing/         # go_router integration via MagicRouter
    ├── security/        # Vault (flutter_secure_storage)
    ├── storage/         # Local disk file storage
    ├── support/         # ServiceProvider base, Carbon date helper
    ├── validation/      # Rules-based validator
    └── ui/              # MagicView, MagicForm, MagicFeedback, MagicResponsiveView
```

**Lifecycle**: `Magic.init()` → providers `register()` → providers `boot()` → app ready

**Resolution**: Facades use either static singletons (`Auth._manager`) or container (`Magic.make<T>(key)`)
</ARCHITECTURE>

<CONVENTIONS>
## Conventions

- **Classes**: PascalCase — **Files**: snake_case — **Methods**: camelCase — **Private**: `_prefix`
- One class per file, named after the class
- Contracts in `contracts/` subdirs, drivers in `drivers/`, events in `events/`
- Always use `package:` imports, never relative
- Service Providers: `{Feature}ServiceProvider` with `register()` + `boot()`
- Controllers: `{Resource}Controller` extending `MagicController`
- Models: singular names, override `table` and `fillable`
- Events: `{Noun}{Verb}Event` (e.g., `UserLoggedInEvent`)
- Guards: `{Type}Guard` (e.g., `BearerTokenGuard`)
- Migrations: `m_YYYY_MM_DD_HHMMSS_{verb}_{table}_table.dart`
- Config access via dot notation: `Config.get('database.connections.sqlite.database')`
- Run `dart analyze` before committing
</CONVENTIONS>

<TESTING>
## Testing

Test files mirror source structure in `test/`. Uses `flutter_test`.

**Setup patterns**:
- `setUp()`: Reset singletons with `MagicApp.reset()` and `Magic.flush()`
- `setUpAll()`: Expensive one-time setup (translator loading)
- Mock via contract inheritance, not code generation

**Key test areas**: container binding, event dispatch, validation rules, model attributes/casting, auth guards, cache operations, full init integration.
</TESTING>

<TOOLS>
## Available Tools

- **Serena MCP**: `find_symbol`, `get_symbols_overview`, `find_referencing_symbols` for semantic navigation
- **context7**: Up-to-date Flutter/Dart docs
- **GitHub MCP**: Issues and PRs
- Prefer `dart analyze` hook after edits
</TOOLS>

<GOTCHAS>
## Gotchas

1. **`Magic.init()` must complete** before any facade calls — it's async, await in `main()`
2. **Auth user factory required**: Call `Auth.manager.setUserFactory()` in boot phase
3. **Test reset**: Always `MagicApp.reset()` + `Magic.flush()` in `setUp()`
4. **Config factories vs static maps**: Use `configFactories` param for configs needing `env()`
5. **Event listeners are factories**: `register()` takes `List<Listener Function()>`, not instances
6. **Router timing**: Access `routerConfig` only after `Magic.init()` completes
7. **Wind UI**: className strings like Tailwind CSS, not Dart objects
8. **Web vs mobile DB**: Web uses in-memory SQLite, mobile uses file-based
9. **EncryptionServiceProvider**: Not auto-registered, must add explicitly to config
10. **Validation messages**: Uses translation keys (`validation.required`) with `:attribute` placeholders
</GOTCHAS>
