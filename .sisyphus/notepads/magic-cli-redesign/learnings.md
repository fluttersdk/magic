# Magic CLI Redesign — Learnings

## Project Structure
- magic_cli package: `plugins/magic/plugins/magic_cli/`
- magic (main package): `plugins/magic/`
- magic_deeplink: `plugins/magic_deeplink/`
- magic_notifications: `plugins/magic_notifications/`

## Key Constraints (GUARDRAILS)
- magic_cli MUST NOT import `package:flutter/*` or `package:magic/*` — pure Dart only
- No .stub files anywhere — use raw Dart string constants in lib/src/stubs/*.dart
- No boost/MCP code
- Helper API (ConsoleStyle, FileHelper, ConfigEditor) method signatures MUST NOT change
- Tests use Directory.systemTemp.createTempSync('magic_test_XXX') + tearDown cleanup

## Architecture Decisions
- Command base: wraps package:args ArgParser
- GeneratorCommand: Laravel-faithful pattern (getStub, getDefaultNamespace, getPath, buildClass)
- Kernel: wraps package:args CommandRunner with Laravel Artisan-style grouped help
- StringHelper: toPascalCase, toSnakeCase, toCamelCase, toPlural (basic English)
- Stubs: const String xxxStub = r'''...'''; in Dart files

## Stub Placeholder Syntax
- `{{ className }}`, `{{ snakeName }}`, `{{ tableName }}`, etc.

## Naming Conventions
- Files: snake_case.dart
- Classes: PascalCase
- Controllers: {Resource}Controller
- Migrations: m_YYYY_MM_DD_HHMMSS_{verb}_{table}_table.dart

## Entry Points
- Main magic CLI: `plugins/magic/bin/magic.dart` (package name `magic`, NOT `fluttersdk_magic`)
- magic_deeplink: `plugins/magic_deeplink/bin/deeplink.dart` (consolidated from install + generate)
- magic_notifications: `plugins/magic_notifications/bin/notifications.dart` (consolidated from 4 separate files)

## Task 3 — Stub Templates as Dart Constants (2026-02-28)

### Approach
- All 14 stubs created as `const String xStub = r'''...''';` in domain-grouped files
- Barrel `stubs.dart` exports all sub-files using `library;` + `export` directives
- Placeholder syntax: `{{ className }}`, `{{ snakeName }}`, `{{ tableName }}`, etc.

### File Structure
```
lib/src/stubs/
├── stubs.dart              — barrel export
├── controller_stubs.dart   — controllerStub, controllerResourceStub
├── model_stubs.dart        — modelStub
├── view_stubs.dart         — viewStub, viewStatefulStub
├── migration_stubs.dart    — migrationCreateStub, migrationStub
├── seeder_stubs.dart       — seederStub
├── factory_stubs.dart      — factoryStub
├── policy_stubs.dart       — policyStub
├── middleware_stubs.dart   — middlewareStub
├── enum_stubs.dart         — enumStub
├── event_stubs.dart        — eventStub
├── listener_stubs.dart     — listenerStub
├── provider_stubs.dart     — providerStub
├── request_stubs.dart      — requestStub
└── lang_stubs.dart         — langStub
```

### Gotchas
- `dangling_library_doc_comments` lint fires when `/// doc` comment is at top of file without a `library;` directive — fix: add `library;` after the doc block
- The existing `assets/stubs/` had 12 files but task required 16 stubs (enum, event, listener, provider, request, lang were missing) — all added fresh
- `controller.stateful.stub` was in assets but task spec doesn't include it — used `controllerResourceStub` pattern with `MagicStateMixin` instead
- `view.responsive.stub` was in assets but not in task spec — omitted intentionally

### Placeholder Conventions Established
- `{{ className }}` — PascalCase (MonitorController)
- `{{ snakeName }}` — snake_case (monitor)
- `{{ tableName }}` — plural snake (monitors)
- `{{ resourceName }}` — API endpoint (monitors)
- `{{ modelName }}` — model class (Monitor)
- `{{ camelName }}` — camelCase variable (monitor)
- `{{ fullName }}` — migration full timestamp name
- `{{ eventClass }}` / `{{ eventSnakeName }}` — for listener stubs
- `{{ description }}` / `{{ actionDescription }}` — human-readable descriptions
- Command implements Dart `args` wrapper and delegates IO helpers correctly.
- GeneratorCommand handles nested paths correctly (e.g. `Admin/UserController`) and writes generated files using Stubs. Checks for `FileHelper.fileExists` appropriately before applying overrides.
- StringHelper works well with explicit pluralization edge cases logic and parses string patterns properly.
- Kernel dispatches arguments via `ArgParser` matching `magic <cmd> [args]` pattern accurately.
- `flutter test` executes tests correctly in `magic_cli`.

## Task 8 — make:enum, make:event, make:listener Generators (2026-02-28)

### Pattern
- All three extend `GeneratorCommand` (not `Command` directly — that's the older pattern).
- Import only: `generator_command.dart`, `string_helper.dart`, and the relevant `*_stubs.dart`.
- No `StubLoader` or asset files — stubs are inline Dart string constants.

### Listener import-line trick
- The `listenerStub` has `import '../events/{{ eventSnakeName }}.dart';` as a full line.
- When `--event` is not provided, eventClass defaults to `MagicEvent` (framework type).
- Replace the entire import line with `''` in `getReplacements()` to avoid a broken import.
- Key in the replacements map is the full import line string literal — not just the placeholder.

### Test anatomy (mirrors make_middleware_command_test.dart)
- Subclass command, override `getProjectRoot()` to return `tempDir.path`.
- `setUp`: `createTempSync`, instantiate cmd, create parser, call `cmd.configure(parser)`.
- `tearDown`: `deleteSync(recursive: true)`.
- All file existence / content checks use `File('${tempDir.path}/...').existsSync()`.

### configure() + --event option
- `MakeListenerCommand.configure()` must call `super.configure(parser)` first to inherit `--force`.
- Then `parser.addOption('event', abbr: 'e', ...)`.
- In `getReplacements()`, retrieve via `option('event') ?? 'MagicEvent'`.

### dart analyze scope
- Pre-existing errors exist in `make_model_command.dart` and `make_view_command.dart` (StubLoader).
- New files are clean — verify with explicit file list, not package-wide analyze.

## Task 9 — make:policy and make:request (2026-02-28)

### Design Pattern: GeneratorCommand Suffix Override

When a generator must produce a **suffixed** file name and class name (e.g. `Monitor` → `MonitorPolicy`), three overrides are needed on top of `GeneratorCommand`:

1. **`getPath(name)`** — the default uses `parsed.fileName` (snake_case of raw input). Override to build from the resolved suffixed class name instead.
2. **`replaceClass(stub, name)`** — called before `getReplacements`, so it MUST embed the suffix now or `{{ className }}` will already be consumed with the wrong value.
3. **`getReplacements(name)`** — provide the remaining template holes (`{{ snakeName }}`, `{{ policyName }}`, `{{ modelClass }}`). Do NOT re-include `{{ className }}` since it's already replaced by `replaceClass`.

Central helper `_resolveClassName(name)` resolves this in one place.

### `testRoot` Constructor Pattern

Inject `String? testRoot` and override `getProjectRoot()` to return it:
```dart
MakePolicyCommand({String? testRoot}) : _testRoot = testRoot;

@override
String getProjectRoot() => _testRoot ?? super.getProjectRoot();
```
Tests create a temp dir and pass it:
```dart
cmd = MakePolicyCommand(testRoot: tempDir.path);
```

### Stub Placeholder Alignment
- `policy_stubs.dart` uses `{{ modelClass }}` (updated from `{{ modelName }}` during this task).
- `request_stubs.dart` uses `{{ className }}`, `{{ snakeName }}`, `{{ actionDescription }}`.

### Pre-existing Analyzer Errors
`make_model_command`, `make_view_command`, `make_controller_command`, etc. have pre-existing `StubLoader`/`StubNotFoundException` errors. These are NOT our responsibility — confirmed by `git stash` + `dart analyze` baseline check.

## Task 6 — Generators: make:migration, make:seeder, make:factory (2026-02-28)

### Approach
- All 3 commands extend `GeneratorCommand` (not the old `Command` base).
- Stub constants imported directly from `lib/src/stubs/` — no `StubLoader` needed.
- TDD: test files written first, then implementations driven by red→green.

### Key Pattern: Suffix Normalisation via `_normalizeName` + `buildClass` Override
`GeneratorCommand.buildClass()` calls `replaceClass()` which fills `{{ className }}` with
the *raw* parsed class name before `getReplacements()` runs. For suffix-bearing commands
(Seeder, Factory) the fix is:

```dart
String _normalizeName(String name) { /* append suffix if missing */ }

@override String getPath(String name) => super.getPath(_normalizeName(name));

@override String buildClass(String name) => super.buildClass(_normalizeName(name));

@override Map<String, String> getReplacements(String name) {
  // name is already suffix-normalised here — only add extra keys
  return {'{{ snakeName }}': StringHelper.toSnakeCase(parsed.className)};
}
```

### Migration: Timestamped Filename
- Override `getPath()` to inject `m_YYYYMMDDHHmmss_` prefix.
- `getReplacements()` provides `{{ className }}`, `{{ fullName }}`, `{{ tableName }}`.
- `--create=tableName` selects `migrationCreateStub` (has Schema.create + Blueprint).
- `--table=tableName` uses plain `migrationStub`.

### Test Design for Timestamped Files
Migration abort test CANNOT use `Future.delayed(seconds: 1)` — that changes the timestamp
and creates a NEW file path, defeating the test. Instead: tamper the file content and
assert the tampered content is preserved after a same-second re-run.

### File Locations
```
lib/src/commands/make_migration_command.dart   # MakeMigrationCommand
lib/src/commands/make_seeder_command.dart      # MakeSeederCommand
lib/src/commands/make_factory_command.dart     # MakeFactoryCommand
test/commands/make_migration_command_test.dart  # 7 tests
test/commands/make_seeder_command_test.dart     # 6 tests
test/commands/make_factory_command_test.dart    # 6 tests
```

### dart analyze
Zero warnings / errors on all 6 files.

## Task 7 — make:middleware, make:provider, make:lang (2026-02-28)

### Approach
- All 3 commands extend `GeneratorCommand` (not the old `Command` base class).
- TDD applied: tests written first, all red, then implementations turned them green.
- 24 new tests across 3 files — 9 middleware, 8 provider, 7 lang.

### Key Patterns
- `getStub()` returns the Dart const from the stubs barrel.
- `getDefaultNamespace()` returns the default output directory.
- `getReplacements()` returns `Map<String, String>` for placeholder substitution.
- Override `getPath()` when the file extension or naming differs from default `.dart`.

### Provider: replaceClass gotcha
- `GeneratorCommand.buildClass()` calls `replaceClass()` BEFORE `getReplacements()`.
- `replaceClass()` sets `{{ className }}` to `parseName(name).className` (the RAW input).
- For `MakeProviderCommand`, overriding only `getReplacements` was NOT enough — `{{ className }}` was already replaced with the bare name (e.g., `App`) before replacements ran.
- Fix: override `replaceClass()` to return the ServiceProvider-suffixed class name.
- Also override `getPath()` to derive file name from the final (suffixed) class name.

### Provider: suffix idempotency
- `parsed.className.endsWith('ServiceProvider')` — check in both `replaceClass` and `getPath`.
- Extracted to private `_resolveClassName(String name)` to avoid duplication.

### Lang: JSON not Dart
- Override `getPath()` to return `$projectRoot/$namespace/$name.json` — `.json` extension.
- Base `getPath()` always uses `.dart`; override is the only way to change this.
- `getReplacements()` returns `{}` — the stub is already valid JSON (`{}`).

### Pre-existing failures
- `make_controller_command.dart`, `make_view_command.dart`, `make_factory_command.dart` still reference `StubLoader` / `StubNotFoundException` which are not exported from `magic_cli.dart`.
- These were failing BEFORE Task 7 — not caused by these changes.

## Task 5 — make:controller and make:view with GeneratorCommand (2026-02-28)

### Key Design Pattern: Dual Name Strategy

The stubs use `{{ className }}Controller` / `{{ className }}View` (stub appends suffix). This means:
- `buildClass(baseName)` — pass BASE name (e.g., `Monitor`), `replaceClass` sets `{{ className }}` = `Monitor`, stub produces `MonitorController`
- `getPath(fullName)` — pass FULL name (e.g., `MonitorController`), `parseName` produces filename `monitor_controller.dart`

**Critical**: You CANNOT use `super.handle()` because it calls both `getPath` and `buildClass` with the SAME name. Override `handle()` and call them with DIFFERENT names.

### Implementation Pattern

```dart
@override
Future<void> handle() async {
    final rawName = argument(0);
    final baseName = _stripSuffix(rawName, 'Controller'); // Monitor
    final fullName = _withSuffix(rawName, 'Controller');  // MonitorController
    final filePath = getPath(fullName);   // uses full name for path
    // ... force check ...
    final content = buildClass(baseName); // uses base name for stub
    FileHelper.writeFile(filePath, content);
}
```

### testRoot Pattern

Both commands accept `MakeControllerCommand({String? testRoot})` and override `getProjectRoot()`:
```dart
@override
String getProjectRoot() => _testRoot ?? super.getProjectRoot();
```
Tests use: `MakeControllerCommand(testRoot: tempDir.path)`

### getReplacements only needs snakeName

The base class `replaceClass` handles `{{ className }}`. `getReplacements` only needs:
```dart
return {
    '{{ snakeName }}': StringHelper.toSnakeCase(parsed.className),
};
```
Where `name` passed to `getReplacements` is the BASE name (Monitor, not MonitorController).

### configure() must call super.configure() first

`super.configure(parser)` adds `--force`. Always call it before adding command-specific flags.

### Stub placeholder cross-reference

- Controller stubs: `{{ className }}` = base name → stub adds `Controller`
- View stubs: `{{ className }}` = base name → stub adds `View`
- `{{ snakeName }}` = snake_case of base name (e.g., `monitor`, not `monitor_controller`)
- [2026-02-28] Rewrote key:generate command using new Command base. Added TDD tests.


## Task 11 — install command (2026-02-28)

### Architecture
- `InstallCommand extends Command` (NOT GeneratorCommand — this creates structure, not a single file)
- `getProjectRoot()` is the test injection point; override in `_TestInstallCommand` subclass to return `tempDir.path`
- No `_testRoot` field on the class — just an overridable method keeps things clean

### Implementation Approach
1. `_createDirectories` — creates all dirs via `FileHelper.ensureDirectoryExists`; respects `--without-database` and `--without-localization`
2. `_createConfigFiles` — writes `config/app.dart`, `config/auth.dart`, `config/database.dart`; each wrapped in `FileHelper.fileExists` guard (idempotent)
3. `_createStarterFiles` — writes `RouteServiceProvider`, `AppServiceProvider`, `routes/app.dart`; also guarded
4. `_bootstrapMainDart` — checks `content.contains('Magic.init')` FIRST; only injects if absent
   - `ConfigEditor.addImportToFile` handles the two import lines (fluttersdk_magic + config/app.dart)
   - `ConfigEditor.insertCodeBeforePattern(pattern: RegExp(r'runApp\('))` places `await Magic.init(...)` before `runApp`

### Test Setup
- `_createMinimalFlutterProject(dir)` helper: writes pubspec.yaml + lib/main.dart scaffold
- `setUp`: `createTempSync`, create minimal project, instantiate `_TestInstallCommand(tempDir.path)`, configure parser
- `tearDown`: `deleteSync(recursive: true)`

### Gotchas
- Removing an unused field (`_testRoot`) requires re-running tests after to confirm no regression
- `dart analyze` will flag `unused_import` for `dart:io` and `unused_field` — fix both before shipping
- `configFactories` (list) uses trailing comma in the generated main.dart injection code
- `arguments['without-database']` returns `bool` — cast as `bool` explicitly to silence analyzer
- Task 10 completed: Rewrote MakeModelCommand without StubLoader, supporting flags for all related classes (-mcfsp, --all). Added `runWith` to `Command` base class.

## Task 13 — Entry Point and Barrel Export (2026-02-28)

### Changes
- Created `plugins/magic/bin/magic.dart` as the primary framework entry point.
- Registered 16 commands (install, key:generate, and 14 make:* commands).
- Updated `plugins/magic/pubspec.yaml` to include `magic: magic` executable and `magic_cli` dependency.
- Updated `plugins/magic_cli/lib/magic_cli.dart` barrel to export all commands, helpers, and console classes.
- Verified with `dart analyze` (clean) and `dart run magic:magic` (shows all commands).
- Evidence saved to `.sisyphus/evidence/task-13-entry-point.txt`.

## Task 15 — magic_deeplink CLI Refactor (2026-02-28)

### Architecture
- Both commands extend `Command` from `package:magic_cli/magic_cli.dart`
- `configure(ArgParser parser)` replaces constructor-based `argParser.addFlag/addOption`
- `handle()` replaces `run()`
- IO helpers (`info()`, `warn()`, `success()`, `error()`) replace `print(ConsoleStyle.*)`
- `GenerateCommand` uses `JsonEditor.writeJson()` for JSON output
- `GenerateCommand` uses `PlatformHelper.hasPlatform()` + `PlatformHelper.infoPlistPath()` for iOS path detection

### Critical Gotcha: InstallCommand Name Conflict
`package:magic_cli/magic_cli.dart` exports its OWN `InstallCommand` from `src/commands/install_command.dart`.
When `bin/deeplink.dart` imports both `magic_cli` and the local `InstallCommand`, Dart throws:
  `ambiguous_import` + `invocation_of_non_function`

Fix:
```dart
import 'package:magic_cli/magic_cli.dart' hide InstallCommand;
import 'package:magic_deeplink/src/cli/commands/install_command.dart';
```

This pattern applies to ALL plugins that have an `InstallCommand` — magic_notifications included.

### unnecessary_import for args/args.dart
`magic_cli/magic_cli.dart` re-exports `package:args/args.dart` at the top:
  `export 'package:args/args.dart';`

So any plugin command that imports both `magic_cli` and `args/args.dart` will get `unnecessary_import` lint.
Fix: remove the `args/args.dart` import — use only `package:magic_cli/magic_cli.dart`.

### pubspec.yaml
- `magic_cli` path dependency must be added explicitly — it is NOT transitively available via `magic`
- `executables` section: change from separate executables to single `{ deeplink: deeplink }`
### Task 14: Integration Tests
- Full end-to-end integration tests have been implemented for all 16 commands in `magic_cli`.
- `FileHelper.findProjectRoot()` requires `pubspec.yaml` to exist in the current directory or parents. When running tests in a temporary directory, we must scaffold a dummy `pubspec.yaml` file to prevent `findProjectRoot` from throwing.
- Handled naming nuances: `MakeEventCommand` outputs `UserCreated` (not `UserCreatedEvent` suffix in file name like `UserCreatedEventEvent` would be weird).
- Commands properly exit gracefully instead of crashing out, logging their errors and printing helpful output.
- Covered the `install` and `key:generate` setup commands successfully without polluting the host environment's project root.
- Verified `--force` override functionality using file modification assertions.

## Task 16A Findings (magic_notifications Install/Configure)
- `magic_cli` dependency needs to be added explicitly via `path: ../magic/plugins/magic_cli`.
- When refactoring commands with logic originally in `bin/` files, it's cleaner to move all parsing and interactive logic directly into the `Command.handle()` method using `Command` helpers (`ask`, `confirm`, `option`, `hasOption`).
- `bin/install.dart` and `bin/configure.dart` can be reduced to just importing the command class and calling `await command.runWith(arguments)`.
- You must use `import '..._command.dart' as notifications;` and `notifications.InstallCommand()` to avoid naming conflicts with the underlying `Command` classes if they might conflict during refactoring, but it's safest and standard practice.

## Task 16B Findings (magic_notifications Status/Test + Consolidated Entry Point) (2026-02-28)

### projectRoot Migration Pattern
- All commands that need `projectRoot` (install, configure, status) now expose `getProjectRoot()` + a `projectRoot` getter.
- Pattern: `String get projectRoot => getProjectRoot();` + `String getProjectRoot() => FileHelper.findProjectRoot();`
- The getter approach lets all private methods use `projectRoot` without any refactoring of call sites.
- Tests override `getProjectRoot()` by subclassing the command.

### StatusCommand: PlatformHelper Integration
- `checkPlatformSetup()` now calls `PlatformHelper.detectPlatforms(projectRoot)` and only checks platforms that exist.
- Avoids reporting missing Android setup for web-only projects.
- Uses `PlatformHelper.androidManifestPath()` and `PlatformHelper.infoPlistPath()` for canonical paths.

### TestCommand: Functions → Class Methods
- The `_sendDatabaseNotification`, `_sendPushNotification`, `_sendMailNotification` top-level functions
  in `bin/test.dart` moved into the class as private methods.
- This keeps the class self-contained and removes the bin entry point's business logic.

### Kernel.handle() --help Bug
- `Kernel.handle()` originally used `args.contains('--help')` which matches `['status', '--help']`
  and shows global help instead of command-specific help.
- Fixed to `args[0] == '--help' || args[0] == '-h'` — only global help when flag is the FIRST arg.
- This fix is in `magic_cli/lib/src/console/kernel.dart`.

### bin/notifications.dart hide Pattern
- `package:magic_cli/magic_cli.dart` exports its own `InstallCommand`.
- `bin/notifications.dart` must use `hide InstallCommand` to avoid `ambiguous_import` error.
- Pattern: `import 'package:magic_cli/magic_cli.dart' hide InstallCommand;`

---
## F3 Manual QA Learnings (2026-02-28)

### --project-root flag does NOT exist
- The plan mentions `--project-root=$TMPDIR` but this flag doesn't exist in any command
- `FileHelper.findProjectRoot()` traverses up from CWD to find pubspec.yaml
- Workaround: run commands with `cd $TMPDIR` before calling the CLI
- Tests use `_testRoot` constructor injection (internal, not a CLI flag)

### Plugin CLIs need fresh compilation context
- Running plugin CLI from plugin package dir does NOT use the magic main package's kernel cache
- Plugin CLIs build fresh and see the actual source of magic_cli dependency
- File corruption in shared sources blocks ALL dependent package compilation

### Magic CLI binary discovery
- `dart run magic:magic` from magic root — works (uses magic package executables)
- `dart run bin/magic.dart` from magic_cli dir — works (direct bin execution)
- `dart run magic_deeplink:deeplink` from magic root — FAILS (different package)
- Must run deeplink from its own package dir: `dart run bin/deeplink.dart`

### Command file structure
- 16 commands actually registered, not 18 (plan said 18)
- Missing: route:list, config:list, config:get, boost:install, boost:mcp, boost:update
  (these exist as dart files but are not registered in bin/magic.dart)

VERIFICATION F4 COMPLETE - APPROVE
