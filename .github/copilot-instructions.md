# Magic Framework

Laravel-inspired Flutter framework with Facades, Eloquent ORM, Service Providers, and IoC Container.

**Dart:** >=3.11.0 | **Flutter:** >=3.41.0

## Architecture

**Pattern**: Service Provider + IoC Container + Facade (Laravel-inspired)

```
lib/
├── magic.dart              # Barrel export (public API)
├── config/                 # Default configs
└── src/
    ├── foundation/         # MagicApp (IoC), Magic (bootstrap), ConfigRepository, Env
    ├── facades/            # 17 facades: Auth, Cache, Config, Crypt, DB, Echo, Event, Gate, Http, Lang, Launch, Log, Pick, Route, Schema, Storage, Vault
    ├── auth/               # AuthManager, guards, events
    ├── broadcasting/       # BroadcastManager, Echo facade, Reverb/Null drivers
    ├── cache/              # CacheManager, drivers (memory, file)
    ├── database/           # Eloquent ORM, QueryBuilder, migrations, seeders, factories
    ├── http/               # MagicController, middleware pipeline, Kernel
    ├── concerns/           # ValidatesRequests mixin (import from here, not http/)
    ├── localization/       # Translator (JSON loaders)
    ├── routing/            # MagicRouter (GoRouter wrapper)
    ├── validation/         # Rules-based validator
    └── ui/                 # MagicView, MagicForm, MagicFeedback
```

**Lifecycle:** `Magic.init()` -> `Env.load()` -> configFactories -> providers `register()` -> providers `boot()` -> router pre-build -> app ready

**Resolution:** Facades use static singletons or container `Magic.make<T>(key)`

## Key Conventions

- Strict types -- every param, return, property typed
- Multi-line + trailing commas everywhere, even with 2 items
- Thin controllers, fat services -- no business logic in controllers
- Contract-first: abstract class defines API shape
- Two-phase bootstrap: `register()` binds, `boot()` configures
- TDD required: failing test first, then implement, then refactor
- Zero linter warnings (`dart analyze`), zero test failures (`flutter test`)
- Import order: dart/flutter stdlib -> third-party -> `package:magic/magic.dart` -> relative

## Key Gotchas

| Mistake | Fix |
|---------|-----|
| Facade call before `Magic.init()` | Always `await Magic.init()` in `main()` first |
| Missing `Auth.manager.setUserFactory()` | Must call in boot phase |
| Forgetting test reset | `MagicApp.reset()` + `Magic.flush()` in every `setUp()` |
| `BroadcastServiceProvider` / `EncryptionServiceProvider` / `LaunchServiceProvider` | NOT auto-registered -- add explicitly |
| `ValidatesRequests` import | Lives in `concerns/`, not `http/` |
| `Event.register()` takes factories | `List<Listener Function()>`, not listener instances |

## Post-Change Checklist

After ANY source code change: update CHANGELOG.md, doc/, README.md (if applicable), skills/magic-framework/, example/.
