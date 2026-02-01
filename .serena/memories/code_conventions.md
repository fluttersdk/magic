# Code Conventions

## Naming Conventions
- **Classes:** PascalCase (e.g., `AuthManager`, `MagicRouter`)
- **Files:** snake_case (e.g., `auth_manager.dart`, `magic_router.dart`)
- **Methods/Functions:** camelCase (e.g., `loginWithCredentials`, `registerProvider`)
- **Constants:** camelCase or SCREAMING_SNAKE_CASE for truly constant values
- **Private members:** Prefix with underscore (e.g., `_instance`, `_providers`)

## File Organization
- One primary class per file, named after the class
- Related contracts/interfaces in `contracts/` subdirectories
- Event classes in `events/` subdirectories
- Driver implementations in `drivers/` subdirectories

## Patterns Used

### Facade Pattern
Static access to services via facade classes in `lib/src/facades/`:
```dart
Auth.login(credentials, user);
Cache.put('key', value);
Config.get('app.name');
```

### Service Provider Pattern
Services registered via providers in `lib/src/providers/` and feature-specific providers:
- Extend `ServiceProvider` base class
- Implement `register()` for bindings
- Implement `boot()` for initialization

### Manager Pattern
Complex services use manager classes (e.g., `AuthManager`, `CacheManager`, `DatabaseManager`)
- Handle multiple drivers/guards
- Provide unified API

### Repository Pattern
Configuration accessed via `ConfigRepository`

## Code Style
- Use flutter_lints package rules
- Exclude plugins from analysis
- Prefer explicit types over `var` for public APIs
- Use factory constructors for singletons
- Document public APIs with /// comments
