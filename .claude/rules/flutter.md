---
path: "lib/**/*.dart"
---

# Flutter / Dart Stack

- Dart >=3.11.0, Flutter >=3.41.0 — use modern patterns (records, switch expressions, strict null safety)
- Import order: dart/flutter stdlib → third-party packages → `package:magic/magic.dart` → relative imports (contracts before implementations)
- Naming: `{Concept}` (facade), `{Concept}Manager` (service locator), `{Type}{Concept}Driver` (implementation), `{Concept}ServiceProvider` (bootstrap), `{Concept}Exception`, `{Purpose}Middleware`
- Facade pattern: static getters proxy to `Magic.make<Manager>('key')`. Never instantiate managers directly
- Contract-first: abstract class defines API shape. Implementations in subdirectory (guards/, drivers/, rules/)
- Two-phase bootstrap: `register()` binds services (immediate), `boot()` configures them (deferred, `Future<void>`)
- Platform splits: `_io.dart` / `_web.dart` suffix for platform-conditional code (SQLite, file I/O, secure storage)
- Manager pattern: singleton manager resolves named drivers from config. `driver([String? name])` method with null-coalescing default
- IoC binding: `app.singleton('key', () => Service())` for singletons, `app.bind('key', () => Service())` for factories
- `ValidatesRequests` mixin: import from `lib/src/concerns/`, NOT from `lib/src/http/`
- Event listeners are **factories**: `[() => Listener()]`, never instances
- `MagicMiddleware.handle(void Function() next)` — async, call `next()` to proceed, skip to redirect
- `analysis_options.yaml` uses `package:flutter_lints/flutter.yaml` — zero warnings required
