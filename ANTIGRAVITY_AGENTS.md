# fluttersdk_magic - Agent Instructions

> For detailed patterns, see `antigravity/rules/`. For workflows, use `/workflow-name` commands.

## Project Overview

`fluttersdk_magic` is a monolithic Flutter application built on the **Magic Framework** architecture, bringing Laravel-style development to Flutter.

## Tech Stack

| Technology | Version/Details |
|------------|-----------------|
| Framework | Flutter 3.22+, Magic Framework |
| Language | Dart 3.4+ |
| UI | Wind UI (Tailwind-style) |
| Architecture | Laravel-style (Models, Controllers, Views, Policies) |

## Critical Rules (NEVER VIOLATE)

1. **Magic Facades Only**: Never import `dio`, `go_router`, `shared_preferences` directly. Use `Http`, `MagicRoute`, `Vault`.
2. **Wind UI First**: Use `WDiv`, `WText` instead of `Container`, `Text`.
3. **No BuildContext**: Avoid passing `BuildContext` for logic.
4. **Directory Strictness**: Follow `lib/app/` and `lib/resources/` structure.

## Available Workflows

| Workflow | Command | Purpose |
|----------|---------|---------|
| Run Tests | `/run-tests` | Execute unit and widget tests |
| Setup Project | `/setup-project` | Install all dependencies |
| Commit Changes | `/commit-changes` | Verify, lint, test, update docs, and commit |
| Generate Docs | `/generate-docs` | Regenerate project documentation |

## Essential Commands

- `flutter pub get` - Install dependencies
- `flutter run` - Start app

## Agent Workflow

1. Review `antigravity/rules/` for context.
2. Use `/workflow-name` for repetitive tasks.
3. Generate task plan artifact.
4. Request review if needed.
5. Execute and validate.

---
For detailed patterns, see `antigravity/rules/`.
For workflows, see `antigravity/workflows/`.
