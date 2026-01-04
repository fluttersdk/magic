---
description: "Verify changes, update docs/rules, and commit"
---

# Commit Changes Workflow

## Step 1: Linting and Testing

- execute: `flutter analyze`
- execute: `flutter test`
- Check for any lint errors or test failures. Fix them before proceeding.

## Step 2: Check Uncommitted Changes

- execute: `git status`
- execute: `git diff`
- identify: Lists modified files to understand the scope of changes.

## Step 3: Verify & Update Documentation

- **Action**: Review files in `docs/` directory.
- **Verification**: Ensure that documentation matches the current code state (from Step 2).
- **Update**: If logic or APIs changed, update the corresponding markdown files in `docs/`.

## Step 4: Update Agent Rules

- **Action**: Review `magic-framework-rules.md`.
- **Update**: If the changes involve new rules, patterns, or architecture decisions that an AI agent needs to know, update `magic-framework-rules.md` to reflect these changes.

## Step 5: Commit Changes

- execute: `git add .`
- execute: `git commit -m "feat: [Description of changes]"`
- **Note**: Replace "[Description of changes]" with a concise summary of the update.
