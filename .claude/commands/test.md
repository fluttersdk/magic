---
description: Run Flutter tests
allowed-tools: Bash, Read
---

Run Flutter tests for the Magic framework.

If $ARGUMENTS is provided, run tests for that specific path:
- `flutter test test/$ARGUMENTS`

If no arguments, run all tests:
- `flutter test`

After running, summarize results: total, passed, failed, skipped.
For any failures, briefly explain what failed.
