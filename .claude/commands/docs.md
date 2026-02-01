---
description: Generate or update documentation
allowed-tools: Read, Write, Glob
---

Generate or update documentation for the Magic framework.

If $ARGUMENTS specifies a topic (e.g., "auth", "cache", "validation"):
1. Find the relevant source files in `lib/src/$ARGUMENTS/`
2. Read existing docs in `docs/` for style reference
3. Create or update documentation following the project style

If no arguments, list available documentation topics and their status.
