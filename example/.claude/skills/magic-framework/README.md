# Magic Framework Skill — Setup Guide

How to add the `magic-framework` skill to any Flutter project that uses the Magic Framework, so Claude Code (Opus 4.5) can work with it effectively.

## Quick Setup (2 steps)

### 1. Copy the skill into your project

```bash
# From your Flutter project root:
mkdir -p .claude/skills

# Copy the entire magic-framework directory
cp -r /path/to/magic-framework .claude/skills/magic-framework
```

Your project should look like:

```
my-flutter-app/
├── .claude/
│   ├── skills/
│   │   └── magic-framework/
│   │       ├── SKILL.md
│   │       └── references/
│   │           ├── facades.md
│   │           ├── eloquent.md
│   │           └── mvc.md
│   └── settings.json       # (optional, see below)
├── lib/
├── pubspec.yaml
└── ...
```

### 2. Commit to version control

```bash
git add .claude/skills/magic-framework/
git commit -m "Add Magic Framework skill for Claude Code"
```

That's it. Claude Code automatically discovers skills in `.claude/skills/` when you open the project.

## How It Works

Claude Code uses a **progressive disclosure** system:

1. **Always in context**: Skill name + description (~100 words) — Claude sees this every request and knows Magic Framework support is available
2. **Loaded on demand**: Full `SKILL.md` content — loaded when Claude detects Magic-related work (models, facades, providers, etc.)
3. **Loaded when needed**: `references/*.md` files — Claude reads these only when it needs detailed API signatures

This means the skill consumes minimal context until actually needed.

## Optional: CLAUDE.md for Project-Specific Rules

For project-specific conventions on top of the skill, add a `CLAUDE.md` at your project root:

```markdown
# My App

## Stack
- Flutter with Magic Framework (`package:fluttersdk_magic`)
- API: https://api.myapp.com

## Conventions
- Models go in `lib/app/models/`
- Controllers go in `lib/app/controllers/`
- All controllers must use `MagicStateMixin`
- Run `dart analyze` before committing

## Database
- Local SQLite for offline support (`useLocal: true`)
- Remote API as primary (`useRemote: true`)
```

`CLAUDE.md` loads every session. Keep it under 500 lines. The skill handles all Magic Framework knowledge; your `CLAUDE.md` should only contain project-specific rules.

## Optional: Permission Settings

Create `.claude/settings.json` to pre-approve common commands:

```json
{
  "permissions": {
    "allow": [
      "Bash(dart analyze)",
      "Bash(dart format *)",
      "Bash(dart fix --apply)",
      "Bash(flutter test *)",
      "Bash(flutter pub get)"
    ]
  }
}
```

## Alternative: Personal (Cross-Project) Installation

If you work on multiple Magic Framework projects, install it once in your personal skills:

```bash
cp -r /path/to/magic-framework ~/.claude/skills/magic-framework
```

Personal skills are available across all your projects. Project-level skills take precedence over personal ones if both exist.

## Alternative: Install from .skill Package

If you received the `magic-framework.skill` package file:

```bash
# Extract to project
mkdir -p .claude/skills
unzip magic-framework.skill -d .claude/skills/

# Or extract to personal skills
unzip magic-framework.skill -d ~/.claude/skills/
```

## Verification

Open Claude Code in your project and ask:

```
What skills are available?
```

You should see `magic-framework` listed. Then test with:

```
Create a new Eloquent model called Product with name, price, and description fields.
```

Claude should follow Magic Framework conventions (extend `Model`, use `fillable`, proper file naming, etc.) without you having to explain the framework.

## Skill Scope Reference

| Location | Path | Applies to |
|----------|------|------------|
| Project | `.claude/skills/magic-framework/` | This project only |
| Personal | `~/.claude/skills/magic-framework/` | All your projects |

## Troubleshooting

**Skill not triggering?**
- Verify `.claude/skills/magic-framework/SKILL.md` exists
- Check that `description` in frontmatter contains relevant keywords
- Try invoking directly: `/magic-framework`

**Too many skills competing for context?**
- Run `/context` in Claude Code to check for warnings about excluded skills
- Set `SLASH_COMMAND_TOOL_CHAR_BUDGET` env var to increase the character budget if needed

**Want to prevent auto-invocation?**
Add `disable-model-invocation: true` to the SKILL.md frontmatter if you only want manual `/magic-framework` invocation.
