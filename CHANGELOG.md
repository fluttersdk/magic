# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

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
