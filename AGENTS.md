# Magic Framework — Agent Instructions

## Commands

| Command | Description |
|---------|-------------|
| `flutter test` | Run all tests |
| `flutter test test/<module>` | Run specific module tests |
| `dart analyze` | Static analysis (zero warnings required) |
| `dart format .` | Format all code |
| `dart fix --apply` | Auto-fix issues |
| `cd example && flutter run` | Run example app |
| `dart pub publish --dry-run` | Validate before release |

## Development Flow (TDD)

Every feature, fix, or refactor follows red-green-refactor:

1. **Red** -- Write a failing test
2. **Green** -- Write minimum code to pass
3. **Refactor** -- Clean up, keep tests green

**Verification cycle:** Edit -> `flutter test` -> `dart analyze` -> repeat until green

## Testing Conventions

- `setUp()`: Always `MagicApp.reset()` + `Magic.flush()` -- clears IoC and facade caches
- Mock via contract inheritance, not code generation -- no mockito
- Tests mirror `lib/src/` structure in `test/`
- Controller tests: `Magic.put<T>(controller)` to inject
- Integration tests in `test/integration/`

## CI Pipeline

`ci.yml`: push/PR -> `flutter pub get` -> `flutter analyze --no-fatal-infos` -> `dart format --set-exit-if-changed` -> `flutter test --coverage`

`publish.yml`: git tag -> validate (analyze + format + test) -> auto-publish to pub.dev

## Git Conventions

- Commit style: `type(scope): description` (conventional commits)
- Types: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`
- Branch naming: `feat/`, `fix/`, `chore/`, `docs/`
- Protected `master` -- all changes via PR

## Post-Change Checklist

After ANY source code change, sync before committing:

1. `CHANGELOG.md` -- Add entry under `[Unreleased]`
2. `doc/` -- Update relevant documentation
3. `README.md` -- Update if new features or API changes
4. `skills/magic-framework/` -- Update if API, facades, or patterns changed
5. `example/` -- Update or create example usage
