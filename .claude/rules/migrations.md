---
globs: ["**/migrations/**", "**/database/migrations/**"]
---

# Migration Conventions

- File naming: `m_YYYY_MM_DD_HHMMSS_{verb}_{table}_table.dart`
- Extend migration base class with `up()` and `down()` methods
- Use `Schema` facade for table operations
- Migrations run alphabetically by timestamp — order matters
- Running same migration twice is a no-op
