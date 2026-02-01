# Project Overview

## Purpose
Magic is a Flutter framework that brings Laravel's elegant syntax and powerful features to Flutter development. It enables developers familiar with Laravel to build production-ready mobile apps with zero boilerplate using familiar patterns like Facades, Eloquent ORM, and Service Providers.

## Tech Stack
- **Framework:** Flutter 3.22.0+ / Dart 3.4.0+
- **Routing:** go_router v17.0.1
- **Database:** SQLite via sqlite3_flutter_libs
- **HTTP Client:** Dio v5.9.0
- **Storage:** flutter_secure_storage, shared_preferences, path_provider
- **UI:** Wind UI plugin (Tailwind CSS-like utility classes)
- **Localization:** intl, JSON-based translations
- **Date/Time:** jiffy, timezone
- **Encryption:** encrypt package

## Key Features
- **Routing:** Named routes, middleware, deep linking with go_router
- **Eloquent ORM:** Query builder, relationships, migrations, seeders
- **Authentication:** Token-based auth, guards (Bearer, API Key, Basic), session management
- **Authorization:** Gates, policies, MagicCan widget
- **Validation:** Laravel-style validation rules
- **Caching:** File, memory, and secure storage drivers
- **Events:** Pub/sub event system with listeners
- **Localization:** JSON-based i18n with `__()` helper
- **Service Container:** Dependency injection via Application class
- **Facades:** Static access to services (Auth, Cache, Config, DB, etc.)
- **Wind UI:** Tailwind-like styling with className strings

## CLI Tool
Separate package `fluttersdk_magic_cli` provides scaffolding commands:
- `magic init` - Initialize Magic in a Flutter project
- `magic make:model`, `make:controller`, `make:view`, etc.
