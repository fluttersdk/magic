---
description: Prepare a new release — bumps version, updates changelog, syncs docs, creates GitHub Release which triggers validate + publish to pub.dev.
---

## Context

- Current version in pubspec.yaml: !`grep 'version:' pubspec.yaml`
- Current branch: !`git branch --show-current`
- Git tags: !`git tag -l | sort -V | tail -10`
- GitHub releases: !`gh release list --limit 5`
- Unreleased changes: !`sed -n '/## \[Unreleased\]/,/^## \[/p' CHANGELOG.md | head -40`
- Recent commits since last tag: !`git log $(git describe --tags --abbrev=0 2>/dev/null || echo HEAD~20)..HEAD --oneline`
- Test status: !`flutter test 2>&1 | tail -3`
- Analyzer status: !`dart analyze 2>&1 | tail -3`

## Arguments

$ARGUMENTS — The target version to release (e.g. `1.0.0-alpha.2`, `1.0.0-beta.1`, `1.0.0`). If empty, auto-increment the last alpha/beta/patch segment.

## Your task

You are preparing a new release for the **Magic Framework** Flutter package. Follow this checklist precisely:

### Phase 1: Validation

1. **Branch check** — Must be on `master` branch. If not, switch: `git checkout master && git pull origin master`.
2. **Clean tree** — `git status` must show no uncommitted changes. If dirty, STOP and warn.
3. **Tests** — All tests must pass (see context above). If failing, STOP and report.
4. **Analyzer** — Zero issues required (see context above). If issues, STOP and report.
5. **Version** — Determine the new version from $ARGUMENTS or auto-increment.

### Phase 2: Version Bump

Update the version string in these files:

| File | What to update |
|------|----------------|
| `pubspec.yaml` | `version:` field |
| `CHANGELOG.md` | Move `[Unreleased]` content → `[{version}] - {YYYY-MM-DD}`, **keep empty `## [Unreleased]` section above** |
| `skills/magic-framework/SKILL.md` | Frontmatter `version:` field + `<!-- Magic v{version} ... -->` comment |
| `example/pubspec.yaml` | `version:` constraint on the `magic` path dependency (e.g. `version: {new_version}`) |
| `example/pubspec.lock` | Run `cd example && flutter pub get` to sync lock file |

**IMPORTANT — files that do NOT need version updates:**
- `CLAUDE.md` — has no version field
- `README.md` — has no pinned version numbers
- `doc/getting-started/installation.md` — has no pinned version numbers

### Phase 3: Changelog Enhancement

Review the `[Unreleased]` section and the git log since the last tag:

1. **Cross-reference** — Ensure every significant commit is reflected in CHANGELOG.md
2. **Missing entries** — Add any commits that introduced features, fixes, or improvements but were not logged
3. **Categorize** — Use these emoji categories:
   - `### ✨ New Features` — new facades, service providers, Eloquent features, UI components
   - `### 🐛 Bug Fixes` — bug fixes
   - `### 🔧 Improvements` — DX, CI/CD, docs, refactors, performance
   - `### ⚠️ Breaking Changes` — only if API, config structure, or provider contracts changed
4. **Entry format** — `- **Short Title**: One-line description`
5. **Date** — Use today's date in `YYYY-MM-DD` format
6. **[Unreleased] section** — ALWAYS keep an empty `## [Unreleased]` section at the top of the changelog after moving entries to the dated section. Never remove it.

### Phase 4: Skill & Doc Sync

**Step 1 — Always update version metadata** in `skills/magic-framework/SKILL.md`:

1. Frontmatter `version:` field (must match `pubspec.yaml` version exactly):
   ```yaml
   version: {new_version}
   ```
2. HTML comment (line after frontmatter closing `---`):
   ```
   <!-- Magic v{new_version} | magic_starter v{starter_version} | Skill updated: {YYYY-MM-DD} -->
   ```

Keep `magic_starter` version unchanged unless that package was also updated. Update `Skill updated` to today's date.

**Step 2 — Detect changed source domains.** Run:

```bash
git diff $(git describe --tags --abbrev=0 2>/dev/null || echo HEAD~20)..HEAD --name-only -- lib/src/
```

Map changed `lib/src/` directories to skill files using this table:

| Source directory | Skill reference file | `.claude/rules/` |
|-----------------|---------------------|-------------------|
| `foundation/`, `facades/`, `providers/` | `references/bootstrap-lifecycle.md`, `references/facades-api.md` | — |
| `auth/`, `policies/` | `references/auth-system.md` | `rules/auth.md` |
| `broadcasting/` | `references/secondary-systems.md` (Broadcasting section) | `rules/broadcasting.md` |
| `cache/`, `events/`, `localization/`, `logging/`, `encryption/`, `security/`, `storage/`, `launch/` | `references/secondary-systems.md` | — |
| `database/` | `references/eloquent-orm.md` | `rules/database.md` |
| `http/`, `concerns/` | `references/controllers-views.md`, `references/http-network.md` | `rules/http.md` |
| `network/` | `references/http-network.md` | — |
| `routing/` | `references/routing-navigation.md` | `rules/routing.md` |
| `ui/` | `references/controllers-views.md`, `references/forms-validation.md` | `rules/ui.md` |
| `validation/` | `references/forms-validation.md` | `rules/validation.md` |
| `testing/` | `references/testing-patterns.md` | `rules/tests.md` |
| `helpers/`, `support/` | `references/templates.md` (if helper APIs changed) | — |

**Step 3 — For each matched file**, read the current source code and the skill reference side by side. Update the reference to reflect:
- New/renamed/removed public APIs (methods, properties, constructors)
- Changed method signatures or return types
- New configuration keys or options
- New anti-patterns or gotchas discovered during this release
- Updated code examples if old ones are now incorrect

**Step 4 — Update SKILL.md body** if the release introduces:
- A new facade → add to Core Laws facade list (Section 1, line 16) and `when_to_use` frontmatter
- A new anti-pattern → add to Anti-patterns section (Section 6)
- A new checklist item → add to Pre-commit Checklist (Section 7)
- A new CLI command → add to CLI Quick Reference (Section 8)
- A new ecosystem plugin → add to Ecosystem Plugins table (Section 10.5)

**Step 5 — Update `doc/`** if documented behavior or APIs changed. Match existing doc format exactly.

**Step 6 — Update `.claude/rules/`** for matched domains (see table above). Rules files document conventions and gotchas, not full API refs.

**Skip Steps 2-6** if the release is purely version bump + changelog with no `lib/src/` changes. Step 1 (version metadata) is always required.

### Phase 5: Local Verification

Run all checks locally. ALL must pass before proceeding:

1. `dart format --set-exit-if-changed .` — must be clean
2. `dart analyze` — must be zero issues (do NOT use `--no-fatal-infos`, that flag does not exist)
3. `flutter test` — must all pass
4. `dart pub publish --dry-run` — must show zero warnings (ignore "uncommitted changes" warning, that's expected before commit)
5. Review all changed files with `git diff`

If **dry-run fails** with real issues → STOP. Fix the issue before proceeding.

### Phase 6: Commit & PR

**Master is protected** — direct push is rejected. Always use a PR:

1. Create a release branch: `git checkout -b chore/release-{version-slug}`
2. Stage all modified files
3. Create a single commit: `chore(release): {version}`
4. Push branch: `git push -u origin chore/release-{version-slug}`
5. Create PR: `gh pr create --title "chore(release): {version}" --body "..."`
6. **Wait for user to merge** — inform user the PR is ready and wait for confirmation

After merge:
1. Switch to master: `git checkout master && git pull origin master`
2. Proceed to Phase 7

### Phase 7: Create GitHub Release

Create a GitHub Release using `gh` CLI. This triggers the full pipeline at once:

1. **Creates the GitHub Release** with changelog notes
2. **Creates the git tag** (e.g. `1.0.0-alpha.9`) — tag convention: NO `v` prefix
3. **Triggers `publish.yml`** — tag push starts the `validate` job (analyze + format + test), then `publish` job (publish to pub.dev via OIDC)

Determine if the version is a prerelease:
- Contains `alpha` or `beta` or `rc` → add `--prerelease` flag
- Otherwise → stable release, no flag

Determine the previous version tag for the changelog comparison link.

```bash
gh release create {version} \
  --target master \
  --title "v{version}" \
  [--prerelease] \
  --notes "$(cat <<'NOTES'
{changelog content from Phase 3 — same categories and entries}

**Full Changelog**: https://github.com/fluttersdk/magic/compare/{previous_tag}...{version}
NOTES
)"
```

After creating the release, watch the publish workflow:

```bash
# Wait a few seconds for the workflow to trigger
gh run list --workflow=publish.yml --limit 1 --json databaseId,status,headSha --jq '.[0]'
gh run watch {run_id} --exit-status
```

If publish fails → report the error. The release and tag already exist — the user can fix and re-trigger manually.

### Output

Present a summary:

```
## Release {version} Complete

**GitHub Release:** https://github.com/fluttersdk/magic/releases/tag/{version}

**Changed files:**
- pubspec.yaml
- CHANGELOG.md
- (any others)

**Changelog:** {count} features, {count} fixes, {count} improvements

**Local:** ✅ Tests ({count} passed) · ✅ Analyzer (0 issues) · ✅ Format clean · ✅ Dry-run (0 warnings)
**pub.dev:** ✅ Validate passed → Published (run #{publish_run_id}) — https://pub.dev/packages/magic
```

## Known Gotchas

| Mistake | Prevention |
|---------|------------|
| Forgetting `example/pubspec.yaml` version bump | Update `version:` constraint on the magic path dep and run `flutter pub get` in example/. Otherwise dependabot creates a separate PR for it. |
| Removing `[Unreleased]` section from CHANGELOG | Always keep empty `## [Unreleased]` at top after moving entries to dated section. |
| Pushing directly to master | Master is protected. Always create a branch + PR. |
| Using `dart analyze --no-fatal-infos` | Flag doesn't exist. Use plain `dart analyze`. |
| Tag with `v` prefix | Convention is NO prefix: `1.0.0-alpha.9`, not `v1.0.0-alpha.9`. |
| Updating CLAUDE.md/README.md for version | These files have no version refs — skip them. |
| Forgetting SKILL.md version comment | Always update `<!-- Magic v{version} ... -->` in SKILL.md line 7, even for changelog-only releases. |
| Skill reference drift | Map changed `lib/src/` dirs to reference files (see Phase 4 table). A new facade without a skill update means the next agent session has stale knowledge. |
