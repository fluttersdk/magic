# CLAUDE.md

<!-- Copy as CLAUDE.md to project root. Customize CUSTOMIZE sections. -->
<!-- Requires fluttersdk CC plugin (magic-framework + wind-ui skills). -->

## Mission

<!-- CUSTOMIZE: One sentence -->
[App Name] — [what it does]. Built on **magic** + **wind**.

## Commands

| Command | Description |
|---------|-------------|
| `flutter test` | Run all tests |
| `dart format lib/ test/` | Format code |
| `dart analyze` | Static analysis (zero warnings) |
| `flutter run -d chrome` | Run on web |
| `dart run magic:magic <command>` | Magic CLI |

## Architecture

```
lib/
├── main.dart              # Magic.init() + configFactories + runApp(MagicApplication())
├── app/
│   ├── models/            # extend Model + HasTimestamps + InteractsWithPersistence
│   ├── providers/         # ServiceProvider (register = sync bindings, boot = async)
│   ├── middleware/         # MagicMiddleware subclasses
│   └── kernel.dart        # Kernel.registerAll() named middleware
├── config/                # app, auth, network, cache, database, routing, view
├── resources/
│   ├── views/             # Full-screen pages
│   └── widgets/           # Reusable components
├── routes/app.dart        # MagicRoute.page() / .group() / .layout()
└── assets/lang/en.json    # trans('key') i18n strings (add to pubspec.yaml assets if enabled)
```

## Key Decisions

<!-- CUSTOMIZE: Keep what applies, add your own -->
- **State**: `ChangeNotifier` + `MagicStateMixin` (no Riverpod/Bloc/GetX)
- **HTTP**: `Http` facade (never raw Dio)
- **Routing**: `MagicRoute.page()` / `.group()` (never raw GoRouter)
- **UI**: Wind UI W-prefix + `className` (never native layout/text widgets)
- **Feedback/nav**: `MagicRoute.to()`, `Magic.snackbar()`, `Magic.toast()` (never BuildContext)
- **i18n**: `trans('section.key')` from `assets/lang/en.json` (never hardcoded strings)

## Wind UI Rules

IMPORTANT: W-prefix components for ALL layout and styling. Banned natives:

| Banned | Replacement |
|--------|------------|
| Row/Column/Wrap | `WDiv` + `flex flex-row`/`flex-col`/`flex-wrap` |
| Container/SizedBox/Padding/Expanded | `WDiv` + className (`p-4`, `w-64`, `flex-1`) |
| Text/Icon | `WText`/`WIcon` + className |
| ElevatedButton/TextButton/GestureDetector | `WButton`/`WAnchor` |
| TextFormField | `WFormInput` (MagicForm) or `WInput` |
| String interpolation in className | `states` param + prefixed classes |

Exceptions (keep native): `Scaffold`, `AppBar`, `Form`, `Center`, `SingleChildScrollView`, `CircularProgressIndicator`, `Navigator`.

**className**: Use triple-quoted `'''` for multi-line; single-line strings fine for simple cases. One concern per line. Every `bg-`/`text-`/`border-` needs `dark:` pair. Responsive via `sm:`/`md:`/`lg:`/`xl:` prefix. States via `states` param (`hover:`, `focus:`, `disabled:`, `active:`, `loading:`, `error:`, custom). Modifiers stack: `dark:hover:bg-gray-700`.

```dart
WDiv(
  className: '''
    bg-white dark:bg-gray-800 rounded-xl p-4 lg:p-6
    border border-gray-200 dark:border-gray-700
    flex flex-col md:flex-row gap-4
    selected:border-primary selected:bg-primary/5
  ''',
  states: isSelected ? {'selected'} : {},
)
```

## Skills

| Skill | Coverage |
|-------|----------|
| `magic-framework` | Facades, ORM, providers, controllers, routing, testing |
| `wind-ui` | W-components, className tokens, states, responsive, theme |

Via `fluttersdk` CC plugin. Full API refs + templates + anti-patterns. Defer to skills for details.

## Agent Context

IMPORTANT: Subagents inherit nothing. Inject into every Agent prompt:

```
Project rules:
1. Load skills before coding: invoke skill "fluttersdk:magic-framework" for any framework/data/routing task, invoke skill "fluttersdk:wind-ui" for any UI/styling task. Read skill references for API details
2. Wind UI only: WDiv/WText/WIcon/WSpacer/WAnchor/WButton + className. NEVER Row, Column, Container, Text, Icon
3. className: triple-quoted ''', dark: pair on every color (bg-white dark:bg-gray-800), responsive sm:/md:/lg:/xl:
4. Conditional styles: states param + prefixed classes (selected:bg-blue-500, states: {'selected'}). NEVER interpolation
5. State prefixes: hover:/focus:/disabled:/active:/loading:/error:/custom. Stack: dark:hover:bg-gray-700
6. Magic facades: Http, MagicRoute, Auth, Config, Cache, Log, Vault. NEVER raw Dio, GoRouter, print()
7. Singleton: static X get instance => Magic.findOrPut(X.new);
8. i18n: trans('key'). Feedback: Magic.snackbar()/toast(). Nav: MagicRoute.to(). NEVER BuildContext
```

## Testing

- `setUp()`: `MagicApp.reset()` + `Magic.flush()`
- Mock via contract inheritance (no mockito)
- `Magic.put<T>(controller)` for controller injection
- Wind UI layouts: `tester.view.physicalSize = const Size(1440, 900); addTearDown(tester.view.resetPhysicalSize)`

## Gotchas

- `.env` = Flutter asset (`pubspec.yaml`), not dart-define
- `Auth.manager.setUserFactory()` in provider `boot()`, not `register()`
- `configFactories` (not `configs`) when values need `Env.get()`
- `BroadcastServiceProvider`/`EncryptionServiceProvider`/`LaunchServiceProvider` NOT auto-registered
- `routerConfig` only after `Magic.init()` completes
- Web SQLite = in-memory; mobile/desktop = file-based
