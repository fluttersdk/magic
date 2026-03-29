# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [1.0.0-alpha.5] - 2026-03-29

### 🐛 Bug Fixes
- **Route Back Navigation**: `MagicRoute.back()` now works after `go()`-based navigation (cross-shell). Maintains lightweight history stack with automatic fallback. Optional `fallback` parameter for explicit control. (#11)

## [1.0.0-alpha.4] - 2026-03-29

### 🔧 Improvements
- **Localization Hot Restart**: Translation JSON changes now reflect on hot restart during development. Uses fetch with cache-busting on web and best-effort disk reads on desktop, bypassing Flutter's asset bundle cache. Zero impact on release builds.

## [1.0.0-alpha.3] - 2026-03-24

### 🐛 Bug Fixes
- **Logo on pub.dev**: Use absolute URL for logo image so it renders correctly on pub.dev

### 🔧 Improvements
- **TDD Development Flow**: Added strict TDD rules and verification cycle to CLAUDE.md

## [1.0.0-alpha.2] - 2026-03-24

### ⚠️ Breaking Changes
- **Pub.dev Migration**: Replaced git submodule path dependencies with pub.dev hosted packages (`fluttersdk_wind: ^1.0.0-alpha.4`, `magic_cli: ^0.0.1-alpha.3`). Removed `plugins/` directory entirely.
- **SDK Bump**: Dart `>=3.11.0 <4.0.0`, Flutter `>=3.41.0` (previously Dart >=3.4.0, Flutter >=3.22.0)

### ✨ New Features
- **Launch Facade**: URL, email, phone, and SMS launching via `url_launcher` with `Launch.url()`, `Launch.email()`, `Launch.phone()`, `Launch.sms()`
- **Form Processing**: `process()`, `isProcessing`, and `processingListenable` on `MagicFormData` for form-scoped loading state
- **Reactive Auth State**: `stateNotifier` on Guard contract and BaseGuard for reactive auth state UI
- **Query Parameters**: `Request.query()`, `Request.queryAll`, `MagicRouter.queryParameter()` for URL query parameter access
- **Localization Interceptor**: Automatic `Accept-Language` and `X-Timezone` headers on HTTP requests
- **Theme Persistence**: Auto-persist dark/light theme preference via Vault in `MagicApplication`
- **Validation Helpers**: `clearErrors()` and `clearFieldError()` on `ValidatesRequests` mixin
- **Route Names**: Route name registration on `RouteDefinition`

### 🐛 Bug Fixes
- **Auth Config**: Default config now properly wrapped under `'auth'` key
- **Session Restore**: Guards against missing `userFactory` — gracefully skips instead of throwing
- **Barrel Export**: `FileStore` exported from barrel file
- **Package Name**: Renamed internal references from `fluttersdk_magic` to `magic`

### 🔧 Improvements
- **Dependency Upgrades**: go_router ^17.1.0, sqlite3 ^3.2.0, share_plus ^12.0.1, file_picker ^10.3.10, flutter_lints ^6.0.0, and more
- **CLI Docs**: Rewrote Magic CLI documentation with all 16 commands and `dart run magic:magic` syntax
- **Wind UI Docs**: Moved to [wind.fluttersdk.com](https://wind.fluttersdk.com/getting-started/installation), removed local copy
- **Example App**: Rebuilt with fresh `flutter create` and `magic install`
- **CI Pipeline**: Upgraded GitHub Actions, added validate gate to publish workflow
- **Claude Code**: Added path-scoped `.claude/rules/` for 8 domains, auto-format and auto-analyze hooks

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
