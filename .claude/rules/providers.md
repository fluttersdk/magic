---
globs: ["lib/src/**/*service_provider.dart", "example/lib/app/providers/**"]
---

# Service Provider Conventions

- Extend `ServiceProvider`, implement `register()` and `boot()`
- `register()`: Bind services to container only — no resolution or side effects
- `boot()`: Async initialization after all providers registered — resolve services here
- Name: `{Feature}ServiceProvider`
- Register in `app.providers` config list
- Use `Magic.app.singleton()` for shared instances, `Magic.app.bind()` for factories
