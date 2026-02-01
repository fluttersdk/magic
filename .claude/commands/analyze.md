---
description: Analyze code quality
allowed-tools: Bash
---

Run code quality checks for the Magic framework:

1. Run `dart analyze` and report any issues
2. Run `dart format --set-exit-if-changed .` to check formatting

Summarize:
- Number of analysis issues (errors, warnings, infos)
- Whether formatting is correct
- Specific files that need attention
