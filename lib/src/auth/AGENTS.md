# AUTHENTICATION SYSTEM

Guard-based auth layer with Dio interceptor for automatic token injection and 401 refresh.

## STRUCTURE

```
auth/
├── auth_manager.dart         # Guard resolver
├── auth_interceptor.dart     # Dio interceptor (token inject + 401 refresh)
├── auth_result.dart          # AuthResult — success/failure wrapper
├── auth_service_provider.dart
├── authenticatable.dart      # Authenticatable mixin
├── gate_manager.dart         # Gate authorization (allows, denies, define, flush, abilities)
├── contracts/
│   └── guard.dart            # Guard interface
├── events/                   # Auth + Gate lifecycle events
└── guards/
    ├── base_guard.dart       # Abstract guard with common logic
    ├── bearer_token_guard.dart
    ├── basic_auth_guard.dart
    └── api_key_guard.dart
```

## AUTH MANAGER

Resolves the active guard from config and exposes it via the `Auth` facade.

```dart
// Reads Config.get('auth.defaults.guard') → maps via 'auth.guards.api.driver'
Auth.manager.setUserFactory((data) => User.fromJson(data));  // REQUIRED in boot()
```

Config keys consumed: `defaults.guard`, `guards.api.driver`, `endpoints.user`,
`endpoints.refresh`, `token.header`, `token.prefix`.

## GUARDS

**BearerTokenGuard** — JWT/Sanctum. Stores token in `Vault`. `login(Map)` calls the auth
endpoint and stores the returned token. `check()` returns true if token exists in Vault.
`user` hydrates via `setUserFactory()` callback. Token attached by `AuthInterceptor`, not the guard.

**BasicAuthGuard** — encodes credentials as Base64 on login, stores in Vault.
Header: `Authorization: Basic <encoded>`.

**ApiKeyGuard** — static key stored in Vault. Header name from `token.header`.
No refresh flow. `check()` always returns true if key is set.

All guards implement `contracts/guard.dart` — `login`, `logout`, `check`, `user`.

## AUTH INTERCEPTOR

Sits on the Dio instance managed by `NetworkManager`.

**onRequest** — reads active guard's token from Vault, attaches to header:
```
{token.header}: {token.prefix} <token>   // e.g. "Authorization: Bearer abc123"
```

**onError (401)** — automatic refresh + retry:
1. Check if `endpoints.refresh` is configured — skip if not.
2. POST to `endpoints.refresh` with current token.
3. On success: store new token in Vault, retry original request once.
4. On refresh failure: call `Auth.logout()`, emit `UserLoggedOutEvent`.

Single-attempt retry only — no loop. Failed refresh clears session.

## TOKEN FLOW

```
login()     → guard stores token in Vault
request     → interceptor attaches token from Vault
401         → interceptor POSTs to refresh endpoint → stores new token → retries once
logout()    → guard clears Vault → UserLoggedOutEvent dispatched
```

## GOTCHAS

1. `Auth.manager.setUserFactory()` MUST be called in `ServiceProvider.boot()` — not `register()`.
   Without it, `Auth.user` returns null even when authenticated.
2. `endpoints.refresh` absence disables auto-refresh — 401s propagate as errors.
3. `token.prefix` defaults to `'Bearer'` — set to `''` for raw key headers (ApiKeyGuard).
4. Interceptor retry uses a cloned request — mutating the original options has no effect.
5. `BasicAuthGuard` re-encodes on every login call — no incremental update.
