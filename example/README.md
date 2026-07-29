# Magic Example

In-repo smoke reference for the `magic` framework. Deliberately minimal: 17 dart files, no dependency of its own beyond `magic`, pinned to a local path `magic: {path: ..}`, runs in magic's CI on every push, and regenerated per release. This is what pub.dev shows on the `magic` package example tab.

This example is NOT a starting point for a real product. For a batteries-included boilerplate with all eight fluttersdk dependencies (magic_starter, magic_notifications, magic_deeplink, magic_social_auth, magic_devtools, dusk, telescope, wind) already wired, a design-first Wind theme, and a production-ready directory shape, see `magic_example/` at the workspace root. A real app in this ecosystem typically forks `magic_example/`, not this minimal reference.

The two examples cannot be merged: pub refuses to unify a path dependency (`magic: {path: ..}` here) with hosted dependencies (like `magic_notifications: ^0.0.2`) in the same resolution graph. This is a hard technical constraint, not a choice, so both stay with separate roles.

## Stack

- Flutter >=3.41.0, Dart >=3.11.0
- `magic` (path dependency to the parent framework)
- No dependency of its own beyond `magic`. Note that `magic` itself pulls a
  small number of plugins transitively (for example `flutter_timezone` for
  IANA timezone detection), so the built app is not plugin-free; what is
  minimal here is what this example declares.

## Getting started

The code here demonstrates basic magic patterns: IoC container setup in `lib/app/kernel.dart` (mostly commented out for clarity), routing via `lib/app/routes/`, and service provider registration. This is NOT a complete app; it is a minimal smoke test to verify the framework compiles and boots.

If you are starting a new app, work from `magic_example/` instead. If you want to understand how magic works at the simplest level, read the source here.
