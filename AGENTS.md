# Magic Framework Agents

Custom subagents for the Magic Flutter framework.

## Available Agents

### test-runner
**Trigger**: Testing tasks, test failures, coverage
**Tools**: Bash, Read, Grep
**Model**: haiku (fast)

Runs Flutter tests and analyzes results. Use when you need to:
- Run specific or all tests
- Understand test failures
- Get fix suggestions for failing tests

### docs-writer
**Trigger**: Documentation tasks, API docs, guides
**Tools**: Read, Write, Glob
**Model**: sonnet

Creates documentation following project style. Use when you need to:
- Document new features
- Update existing docs
- Create usage examples

### eloquent-helper
**Trigger**: Database models, migrations, queries
**Tools**: Read, Grep, Write
**Model**: sonnet

Assists with Eloquent ORM. Use when you need to:
- Create new models or migrations
- Write complex queries
- Understand the ORM patterns

## Quick Reference

| Agent | Use Case | Speed |
|-------|----------|-------|
| test-runner | Run/analyze tests | Fast |
| docs-writer | Documentation | Medium |
| eloquent-helper | Database/ORM | Medium |
