---
path: "lib/src/auth/**/*.dart"
---

# Auth Domain

- `AuthManager` is singleton — accessed via `Auth` facade, never instantiate directly
- **Critical**: `Auth.manager.setUserFactory((data) => User.fromMap(data))` MUST be called in boot phase — session restore fails without it
- Built-in guards: `bearer`/`sanctum` (BearerTokenGuard, default), `basic` (BasicAuthGuard), `api_key` (ApiKeyGuard)
- Guard contract (`Guard` abstract class): `login()`, `logout()`, `check()`, `user()`, `guest` (getter, not method), `restore()`
- Custom guards: `Auth.manager.extend('firebase', (config) => FirebaseGuard())` — factory receives guard config map
- Guard resolution: `Auth.guard()` returns default, `Auth.guard('api')` returns named. Cached after first resolution
- Auth events: `Login`, `Logout`, `AuthRestored`, `AuthFailed` — register listeners via `EventDispatcher.instance.register()`
- `Authenticatable` interface: models implementing auth must extend this. Provides `getAuthIdentifier()`, token methods
- Config path: `auth.defaults.guard` for default guard name, `auth.guards.{name}` for guard-specific config
- Token storage: guards use `Vault` (flutter_secure_storage) for token persistence. Vault must be available
- `AuthServiceProvider` is auto-registered — binds AuthManager as singleton in register phase
