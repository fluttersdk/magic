# Project Architecture

## Directory Structure

```
lib/
├── config/                 # Default configuration files
│   ├── app.dart           # App name, providers
│   ├── auth.dart          # Authentication guards config
│   ├── cache.dart         # Cache drivers config
│   ├── database.dart      # Database connections config
│   ├── filesystems.dart   # Storage disks config
│   ├── localization.dart  # i18n config
│   ├── logging.dart       # Log channels config
│   ├── network.dart       # HTTP client config
│   └── view.dart          # UI/view config
├── fluttersdk_magic.dart  # Main barrel export file
└── src/                   # Core framework source
    ├── auth/              # Authentication system
    │   ├── guards/        # Auth guards (Bearer, API Key, Basic)
    │   ├── contracts/     # Guard interface
    │   └── events/        # Auth events
    ├── cache/             # Caching system
    │   └── drivers/       # Cache store implementations
    ├── database/          # Database/ORM system
    │   ├── eloquent/      # Model base class
    │   ├── migrations/    # Migration system
    │   ├── query/         # Query builder
    │   ├── schema/        # Schema builder
    │   └── seeding/       # Seeders and factories
    ├── encryption/        # Encryption service
    ├── events/            # Event dispatcher system
    ├── facades/           # Static facade classes
    ├── foundation/        # Core application classes
    ├── http/              # HTTP layer (controllers, middleware)
    ├── localization/      # Translation system
    ├── logging/           # Logging system
    ├── network/           # HTTP client (Dio wrapper)
    ├── policies/          # Authorization policies
    ├── providers/         # Service providers
    ├── routing/           # Router and route definitions
    ├── security/          # Vault (secure storage)
    ├── storage/           # File storage system
    ├── support/           # Helpers (Carbon, ServiceProvider base)
    ├── ui/                # UI components (MagicView, MagicForm)
    └── validation/        # Validation rules and validator
```

## Key Components

### Foundation
- **Magic** (`foundation/magic.dart`): Static entry point, initializes the app
- **Application** (`foundation/application.dart`): Service container, manages providers
- **ConfigRepository** (`foundation/config_repository.dart`): Configuration access

### Facades
Located in `src/facades/`, provide static access to services:
- `Auth` - Authentication
- `Cache` - Caching
- `Config` - Configuration
- `DB` - Database queries
- `Event` - Event dispatcher
- `Gate` - Authorization
- `Http` - HTTP client
- `Lang` - Translations
- `Log` - Logging
- `Route` - Routing
- `Storage` - File storage
- `Vault` - Secure storage

### Data Flow
1. `Magic.init()` bootstraps the application
2. Service providers register and boot services
3. Facades provide static access to container-resolved services
4. MagicApplication widget provides the app shell with routing

## External Dependencies
- **go_router**: Navigation and deep linking
- **dio**: HTTP client
- **sqlite3_flutter_libs**: SQLite database
- **flutter_secure_storage**: Encrypted storage
- **shared_preferences**: Simple key-value storage
- **encrypt**: Encryption/decryption
