# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Breaking Changes
- **Breaking**: Replaced git submodule path dependencies with pub.dev hosted packages (`fluttersdk_wind: ^1.0.0-alpha.4`, `magic_cli: ^0.0.1-alpha.3`). Removed `plugins/` directory.

### Changed
- Bumped SDK constraints: Dart `>=3.11.0 <4.0.0`, Flutter `>=3.41.0`

### Added
- `Launch` facade — URL, email, phone, and SMS launching via `url_launcher`
- `process()`, `isProcessing`, and `processingListenable` on `MagicFormData` for form-scoped loading state
- `stateNotifier` on Guard contract and BaseGuard for reactive auth state UI
- Query parameter support: `Request.query()`, `Request.queryAll`, `MagicRouter.queryParameter()`
- `LocalizationInterceptor` — automatic `Accept-Language` and `X-Timezone` headers on HTTP requests
- Auto-persist dark/light theme preference via Vault in `MagicApplication`
- `clearErrors()` and `clearFieldError()` on `ValidatesRequests` mixin
- Route name registration on `RouteDefinition`

### Fixed
- Auth default config now properly wrapped under `'auth'` key
- Session restore guards against missing `userFactory` — gracefully skips instead of throwing
- `FileStore` exported from barrel file

### Changed
- Rewrote Magic CLI documentation (`doc/packages/magic-cli.md`) with all 16 commands and `dart run magic:magic` syntax
- Updated CLI command references across all documentation files to use `dart run magic:magic` prefix
- Removed references to non-existent CLI commands (route:list, config:list, config:get, boost:*)

### Documentation
- Added CLI generation examples to middleware, events, service-providers, and forms documentation

## [1.0.0-alpha.1] - 2026-02-05

### ✨ Core Features
- Laravel-inspired MVC architecture
- Eloquent-style ORM with relationships
- GoRouter-based routing with middleware support
- Service Provider pattern
- Facade pattern for global access
- Policy-based authorization

### 📦 Package Structure
- Complete model system with HasTimestamps, InteractsWithPersistence
- HTTP client with interceptors
- Form validation system
- Event/Listener system

### 🔧 Developer Experience
- Magic CLI integration
- Hot reload support
- AI agent documentation
